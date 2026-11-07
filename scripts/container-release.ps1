# Builds and tests Linux x64 natively inside a bounded Docker container, and
# cross publishes Windows x64 in the same container. No Git mutations.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$output = Join-Path $root "artifacts/container/$timestamp"

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command returned nonzero exit status $LASTEXITCODE"
    }
}

try {
    foreach ($command in @('git', 'docker')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Required command missing: $command. No tool installation attempted."
        }
    }

    Push-Location $root
    try {
        Invoke-Checked 'git' @('diff', '--quiet')
        Invoke-Checked 'git' @('diff', '--cached', '--quiet')
        $untracked = @( & git ls-files --others --exclude-standard )
        if ($LASTEXITCODE -ne 0 -or $untracked.Count -gt 0) {
            throw 'Git checkout has untracked content or cannot be inspected. Nothing was deleted.'
        }
        $sha = (& git rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') {
            throw 'Cannot identify an exact source commit.'
        }

        Invoke-Checked 'docker' @('info', '--format', '{{.ServerVersion}}')
        $image = "clipboardpeek-release:$($sha.Substring(0, 12))"
        Invoke-Checked 'docker' @('build', '--file', 'containers/Dockerfile', '--tag', $image, '.')
        New-Item -ItemType Directory -Path $output -Force | Out-Null
        Invoke-Checked 'docker' @(
            'run', '--rm',
            '--cpus=2', '--memory=3g', '--pids-limit=256',
            '--network=bridge',
            '--mount', "type=bind,source=$output,destination=/out",
            '--env', "SOURCE_SHA=$sha", $image
        )
    }
    finally {
        Pop-Location
    }

    $manifest = Join-Path $output 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw 'Missing hash manifest from container.'
    }
    $hashLines = @(Get-Content -LiteralPath $manifest)
    foreach ($filename in @('ClipboardPeek-linux-x64.tar.gz', 'ClipboardPeek-win-x64.zip')) {
        $matching = @($hashLines | Where-Object { $_ -match ('^[0-9a-f]{64}  ' + [regex]::Escape($filename) + '$') })
        if ($matching.Count -ne 1) {
            throw "Missing or ambiguous digest for $filename"
        }
        $archive = Join-Path $output $filename
        if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
            throw "Missing archive: $filename"
        }
        $expected = $matching[0].Substring(0, 64)
        $observed = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $observed) {
            throw "SHA256 verification failed for $filename"
        }
    }

    $evidence = Join-Path $output 'release-evidence.txt'
    if (-not (Test-Path -LiteralPath $evidence) -or
        -not ((Get-Content $evidence -Raw).Contains("candidate=$sha"))) {
        throw 'Candidate evidence does not match the checked-out source commit.'
    }

    Write-Host "Container build/test/package gate passed for commit $sha"
    Write-Host "Candidate archives: $output"
    Write-Host 'Windows was cross compiled but NOT tested in a native Windows GUI.'
    Write-Host 'Real Windows/Linux interaction, accessibility, and third-party redistribution QA remain release blockers.'
}
catch {
    Write-Error "RELEASE BLOCKED: $($_.Exception.Message)"
    exit 1
}
