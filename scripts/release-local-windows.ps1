# Local Windows x64 release gate. Does not install tools or change Git history.
# Run from a clean checkout on Windows with .NET 10 SDK and internet access for first restore.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:NUGET_PACKAGES = Join-Path $root '.packages'
$project = Join-Path $root 'src/ClipboardPeek/ClipboardPeek.csproj'
$tests = Join-Path $root 'tests/ClipboardPeek.Core.Tests/ClipboardPeek.Core.Tests.csproj'
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$run = Join-Path $root "artifacts/local/windows-$runId"
$publish = Join-Path $run 'publish'
$dist = Join-Path $run 'dist'
$rid = 'win-x64'

function RunNative([string]$command, [string[]]$arguments) {
    & $command @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$command failed with exit code $LASTEXITCODE"
    }
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'The Windows native gate must execute on Windows.'
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git CLI is required to verify the exact release candidate.'
    }
    Push-Location $root
    try {
        RunNative 'git' @('diff', '--quiet')
        RunNative 'git' @('diff', '--cached', '--quiet')
        $untracked = @( & git ls-files --others --exclude-standard )
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect untracked files.' }
        if ($untracked.Count -gt 0) {
            throw 'There are untracked files. Preserve and review them before a release.'
        }
        $sha = (& git rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Cannot identify candidate commit.' }
    }
    finally { Pop-Location }

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'Required .NET 10 SDK was not found. No installation performed.'
    }
    $dotnetVersion = (& dotnet --version).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $dotnetVersion.StartsWith('10.')) {
        throw 'A .NET 10 SDK is required.'
    }
    $system = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($null -eq $system -or $system.FreePhysicalMemory -lt 1048576) {
        throw 'At least 1 GiB of available physical memory is required.'
    }
    $drive = (Get-Item -LiteralPath $root).PSDrive
    if ($null -eq $drive -or $drive.Free -lt 2GB) {
        throw 'At least 2 GiB of free space is required in the project volume.'
    }

    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    RunNative 'dotnet' @('restore', $project, '-p:RestoreDisableParallel=true')
    RunNative 'dotnet' @('restore', $tests, '-p:RestoreDisableParallel=true')
    RunNative 'dotnet' @('build', $project, '-c', 'Release', '--no-restore', '-m:1', '-warnaserror')
    RunNative 'dotnet' @('run', '--project', $tests, '-c', 'Release', '--no-restore')

    $auditFile = Join-Path $run 'dependency-audit.json'
    & dotnet list $project package --vulnerable --include-transitive --format json > $auditFile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency advisory audit did not complete.' }
    $auditRaw = [System.IO.File]::ReadAllText($auditFile)
    if (-not $auditRaw.TrimStart().StartsWith('{')) { throw 'Unrecognized vulnerability audit output.' }
    $audit = $auditRaw | ConvertFrom-Json
    if ($null -eq $audit) { throw 'Vulnerability audit was empty.' }
    if ($auditRaw -match '"vulnerabilities"\s*:\s*\[\s*\{') {
        throw 'Dependencies have published vulnerability advisories. Review before release.'
    }

    RunNative 'dotnet' @('publish', $project, '-c', 'Release', '-r', $rid,
        '--self-contained', 'true', '-p:PublishSingleFile=true',
        '-p:IncludeNativeLibrariesForSelfExtract=true',
        '-p:DebugType=none', '-p:DebugSymbols=false', '-m:1', '-o', $publish)
    $exe = Join-Path $publish 'ClipboardPeek.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Missing executable.' }

    $stream = [System.IO.File]::OpenRead($exe)
    try {
        if ($stream.ReadByte() -ne 0x4D -or $stream.ReadByte() -ne 0x5A) {
            throw 'Executable did not have a valid MZ header.'
        }
    }
    finally { $stream.Dispose() }

    Copy-Item (Join-Path $root 'LICENSE') $publish
    Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') $publish
    $archiveName = "ClipboardPeek-$rid.zip"
    $archive = Join-Path $dist $archiveName
    Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $archive -CompressionLevel Optimal
    if (-not (Test-Path $archive)) { throw 'Archive was not created.' }

    $digest = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$archive.sha256", "$digest  $archiveName" + [Environment]::NewLine,
        [System.Text.Encoding]::ASCII)
    $verify = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($digest -ne $verify) { throw 'Archive digest verification failed.' }
    [System.IO.File]::WriteAllText((Join-Path $run 'release-evidence.txt'),
        "Candidate: $sha`r`nSDK: $dotnetVersion`r`nPlatform: win-x64`r`nArchive: $archiveName`r`nSHA256: $digest`r`nBuild and core tests: passed`r`nNative GUI and human review: NOT RUN`r`n",
        [System.Text.Encoding]::UTF8)

    Write-Host "Local Windows build/test/package gate passed for $sha."
    Write-Host "Archive: $archive"
    Write-Host 'This is not release approval. GUI, accessibility and user workflow acceptance remain required.'
}
catch {
    Write-Error "RELEASE BLOCKED: $($_.Exception.Message)"
    exit 1
}
