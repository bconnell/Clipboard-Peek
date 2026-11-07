# Clipboard Peek local release-candidate builder.
# Compatible with Windows PowerShell 5.1. Runs from any working directory.
# Never modifies Git history, deletes user files, or publishes to GitHub.
[CmdletBinding()]
param([string]$RepoRoot = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-CommandPath {
    param([string]$Name)
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $command) { throw "Missing required application: $Name" }
    return [string]$command.Source
}

# Start-Process on Windows PowerShell 5.1 takes a command-line string. Encode
# arguments explicitly so spaces, quotes and trailing backslashes are safe.
function ConvertTo-Argument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (2 * $slashes + 1)))
            [void]$builder.Append('"')
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) {
            [void]$builder.Append(('\' * $slashes))
            $slashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) { [void]$builder.Append(('\' * (2 * $slashes))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-ProcessGate {
    [CmdletBinding()]
    param(
        [string]$Stage,
        [string]$Executable,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [string]$LogDirectory,
        [int]$TimeoutSeconds = 900
    )
    Assert-True ($ArgumentList.Count -gt 0) "Empty native arguments for $Stage"
    $base = ($Stage -replace '[^A-Za-z0-9_-]', '_')
    $stdout = Join-Path $LogDirectory ($base + '.stdout.log')
    $stderr = Join-Path $LogDirectory ($base + '.stderr.log')
    Assert-True (-not (Test-Path -LiteralPath $stdout)) "Refusing to overwrite $stdout"
    Assert-True (-not (Test-Path -LiteralPath $stderr)) "Refusing to overwrite $stderr"
    $encoded = foreach ($item in $ArgumentList) { ConvertTo-Argument -Value ([string]$item) }
    $commandLine = [string]::Join(' ', [string[]]@($encoded))
    Write-Host "[RUN] $Stage"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $Executable -ArgumentList $commandLine -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try {
        $finished = $false
        while (-not $finished) {
            $finished = $process.WaitForExit(5000)
            $totalLogBytes = 0L
            if (Test-Path -LiteralPath $stdout) { $totalLogBytes += (Get-Item -LiteralPath $stdout).Length }
            if (Test-Path -LiteralPath $stderr) { $totalLogBytes += (Get-Item -LiteralPath $stderr).Length }
            if ($totalLogBytes -gt ([long]33554432)) { throw "Log budget exceeded at $Stage (32 MiB)" }
            if (-not $finished -and $watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Timeout at $Stage after $TimeoutSeconds seconds"
            }
        }
        $process.WaitForExit()
        $exitCode = [int]$process.ExitCode
    }
    catch {
        if (-not $process.HasExited) { try { $process.Kill() } catch { } }
        throw
    }
    finally { $process.Dispose(); $watch.Stop() }
    if ($exitCode -ne 0) {
        $outTail = @(Get-Content -LiteralPath $stdout -Tail 16 -ErrorAction SilentlyContinue)
        $errTail = @(Get-Content -LiteralPath $stderr -Tail 16 -ErrorAction SilentlyContinue)
        if ($outTail.Count -gt 0) { Write-Host ('[stdout] ' + ($outTail -join [Environment]::NewLine)) }
        if ($errTail.Count -gt 0) { Write-Host ('[stderr] ' + ($errTail -join [Environment]::NewLine)) }
        throw "$Stage failed (exit code $exitCode). See logs in $LogDirectory"
    }
    Write-Host ('[PASS] ' + $Stage + ' (' + [math]::Round($watch.Elapsed.TotalSeconds, 1) + ' s)')
    return @{ OutputPath = $stdout; ErrorPath = $stderr; ExitCode = $exitCode }
}

function Get-OneLine {
    param([string]$File)
    $value = [string](Get-Content -LiteralPath $File -Raw -ErrorAction Stop)
    return $value.Trim()
}

try {
    Assert-True ($env:OS -eq 'Windows_NT') 'This entry point must run on Windows.'
    Assert-True ($PSVersionTable.PSVersion.Major -ge 5) 'Windows PowerShell 5.1 or newer is required.'
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $root = [System.IO.Path]::GetFullPath($RepoRoot)
    }
    else {
        $root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        if (-not (Test-Path -LiteralPath (Join-Path $root 'src/ClipboardPeek/ClipboardPeek.csproj'))) {
            # A standalone copy can be pasted or saved outside the repository.
            # The caller may invoke it from the repository root instead.
            $root = [System.IO.Path]::GetFullPath((Get-Location).Path)
        }
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $root 'src/ClipboardPeek/ClipboardPeek.csproj')) 'Clipboard Peek source not found; run from the repository or pass -RepoRoot.'
    Assert-True (Test-Path -LiteralPath (Join-Path $root 'containers/Dockerfile')) 'Clipboard Peek container definition not found.'
    Assert-True (Test-Path -LiteralPath (Join-Path $root 'scripts/container-release-gate.sh')) 'Clipboard Peek container gate not found.'
    $git = Get-CommandPath 'git.exe'
    $dotnet = Get-CommandPath 'dotnet.exe'

    # Create unique evidence location under the repository, never beside private files.
    $artifacts = Join-Path $root 'artifacts'
    if (-not (Test-Path -LiteralPath $artifacts)) { [void](New-Item -ItemType Directory -Path $artifacts) }
    Assert-True ((Get-Item -LiteralPath $artifacts).PSIsContainer) 'artifacts is not a directory.'
    Assert-True (-not ((Get-Item -LiteralPath $artifacts).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) 'artifacts is a junction or symlink.'
    $runs = Join-Path $artifacts 'container'
    if (-not (Test-Path -LiteralPath $runs)) { [void](New-Item -ItemType Directory -Path $runs) }
    $id = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $out = Join-Path $runs $id
    [void](New-Item -ItemType Directory -Path $out -ErrorAction Stop)
    $logs = Join-Path $out 'logs'
    [void](New-Item -ItemType Directory -Path $logs -ErrorAction Stop)

    $gitStatus = Invoke-ProcessGate 'git_status' $git @('status', '--porcelain=v1', '--untracked-files=all') $root $logs 30
    Assert-True ([string]::IsNullOrWhiteSpace((Get-OneLine $gitStatus.OutputPath))) 'Checkout has uncommitted or untracked files. No changes were discarded.'
    $remote = Invoke-ProcessGate 'git_remote' $git @('config', '--get', 'remote.origin.url') $root $logs 30
    $origin = Get-OneLine $remote.OutputPath
    Assert-True ($origin -match '(?i)(?:[/:])bconnell/Clipboard-Peek(?:\.git)?$') 'Git remote is not the expected Clipboard Peek repository.'
    $head = Invoke-ProcessGate 'git_head' $git @('rev-parse', 'HEAD') $root $logs 30
    $sha = Get-OneLine $head.OutputPath
    Assert-True ($sha -match '^[0-9a-fA-F]{40}$') 'Invalid Git HEAD identifier.'

    $version = Invoke-ProcessGate 'dotnet_version' $dotnet @('--version') $root $logs 30
    Assert-True ((Get-OneLine $version.OutputPath) -match '^10\.') '.NET 10 SDK is required.'
    $os = Get-CimInstance Win32_OperatingSystem
    Assert-True ($null -ne $os) 'Cannot inspect system memory.'
    Assert-True ([long]$os.FreePhysicalMemory -ge ([long]1048576)) 'At least 1 GiB free RAM is required.'
    $drive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($out).Substring(0, 1))
    Assert-True ($null -ne $drive -and [long]$drive.Free -ge ([long]4294967296)) 'At least 4 GiB free disk is required.'

    $project = 'src/ClipboardPeek/ClipboardPeek.csproj'
    $tests = 'tests/ClipboardPeek.Core.Tests/ClipboardPeek.Core.Tests.csproj'
    $env:NUGET_PACKAGES = Join-Path $root '.packages'
    [void](Invoke-ProcessGate 'restore_app' $dotnet @('restore', $project, '-p:RestoreDisableParallel=true') $root $logs 600)
    [void](Invoke-ProcessGate 'restore_tests' $dotnet @('restore', $tests, '-p:RestoreDisableParallel=true') $root $logs 600)
    [void](Invoke-ProcessGate 'build_release' $dotnet @('build', $project, '-c', 'Release', '--no-restore', '-m:1', '-warnaserror') $root $logs 900)
    [void](Invoke-ProcessGate 'core_tests' $dotnet @('run', '--project', $tests, '-c', 'Release', '--no-restore') $root $logs 600)
    $audit = Invoke-ProcessGate 'dependency_audit' $dotnet @('list', $project, 'package', '--vulnerable', '--include-transitive', '--format', 'json') $root $logs 300
    $auditData = (Get-Content -LiteralPath $audit.OutputPath -Raw | ConvertFrom-Json)
    Assert-True ($null -ne $auditData.projects) 'Dependency audit output was unrecognized.'
    foreach ($p in @($auditData.projects)) {
        foreach ($framework in @($p.frameworks)) {
            foreach ($package in @($framework.topLevelPackages) + @($framework.transitivePackages)) {
                if ($null -ne $package -and $null -ne $package.vulnerabilities -and @($package.vulnerabilities).Count -gt 0) {
                    throw "Vulnerable dependency found in $($p.path). Release blocked."
                }
            }
        }
    }

    # A true native Windows build is mandatory. Docker will separately build Linux.
    $native = Join-Path $out 'native-win-x64'
    [void](New-Item -ItemType Directory -Path $native)
    [void](Invoke-ProcessGate 'publish_native_windows' $dotnet @('publish', $project, '-c', 'Release', '-r', 'win-x64', '--self-contained', 'true', '-p:PublishSingleFile=true', '-p:IncludeNativeLibrariesForSelfExtract=true', '-p:DebugType=none', '-p:DebugSymbols=false', '-m:1', '-o', $native) $root $logs 900)
    $nativeExe = Join-Path $native 'ClipboardPeek.exe'
    Assert-True (Test-Path -LiteralPath $nativeExe -PathType Leaf) 'Native Windows executable was not produced.'
    $reader = New-Object System.IO.BinaryReader([System.IO.File]::OpenRead($nativeExe))
    try {
        Assert-True ($reader.ReadUInt16() -eq 0x5A4D) 'Invalid Windows MZ header.'
        $reader.BaseStream.Position = 0x3C
        $offset = $reader.ReadInt32()
        Assert-True ($offset -ge 64 -and $offset -lt ($reader.BaseStream.Length - 6)) 'Invalid PE offset.'
        $reader.BaseStream.Position = $offset
        Assert-True ($reader.ReadUInt32() -eq 0x00004550) 'Invalid PE signature.'
        Assert-True ($reader.ReadUInt16() -eq 0x8664) 'Executable is not AMD64.'
    }
    finally { $reader.Dispose() }
    # Keep the actual Windows-native build as a separate, clearly named artifact.
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $native
    Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') -Destination $native
    $nativeArchive = Join-Path $out 'ClipboardPeek-win-x64-native.zip'
    Assert-True (-not (Test-Path -LiteralPath $nativeArchive)) 'Native Windows archive already exists.'
    Compress-Archive -Path (Join-Path $native '*') -DestinationPath $nativeArchive -CompressionLevel Optimal
    Assert-True (Test-Path -LiteralPath $nativeArchive -PathType Leaf) 'Windows native archive was not created.'
    $nativeHash = [string](Get-FileHash -LiteralPath $nativeArchive -Algorithm SHA256).Hash
    Set-Content -LiteralPath (Join-Path $out 'windows-native-sha256.txt') -Value ($nativeHash + '  ClipboardPeek-win-x64-native.zip') -Encoding Ascii

    # The container stage will not start unless enough host RAM is available.
    Assert-True ([long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory -ge ([long]2621440)) 'At least 2.5 GiB currently free RAM required before Docker. Native Windows build is preserved.'
    $docker = Get-CommandPath 'docker.exe'
    [void](Invoke-ProcessGate 'docker_info' $docker @('info', '--format', '{{.ServerVersion}}') $root $logs 30)
    $image = 'clipboardpeek-gate:' + $sha.Substring(0, 12)
    [void](Invoke-ProcessGate 'docker_build' $docker @('build', '--file', 'containers/Dockerfile', '--tag', $image, '.') $root $logs 1800)
    [void](Invoke-ProcessGate 'docker_run' $docker @('run', '--rm', '--cpus=2', '--memory=2g', '--pids-limit=128', '--network=bridge', '--mount', ('type=bind,source=' + $out + ',destination=/out'), '--env', ('SOURCE_SHA=' + $sha), $image) $root $logs 1800)

    # Verify exact candidate plus both artifacts. Never upload or mark release PASS.
    $manifest = Join-Path $out 'SHA256SUMS.txt'
    Assert-True (Test-Path -LiteralPath $manifest -PathType Leaf) 'Container SHA256 manifest missing.'
    $lines = @(Get-Content -LiteralPath $manifest)
    foreach ($fileName in @('ClipboardPeek-win-x64.zip', 'ClipboardPeek-linux-x64.tar.gz')) {
        $matched = @($lines | Where-Object { $_ -match ('^[a-fA-F0-9]{64}\s+' + [regex]::Escape($fileName) + '$') })
        Assert-True ($matched.Count -eq 1) "Missing or repeated checksum: $fileName"
        $file = Join-Path $out $fileName
        Assert-True (Test-Path -LiteralPath $file -PathType Leaf) "Missing package: $fileName"
        $expected = [string]$matched[0].Substring(0, 64)
        $actual = [string](Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        Assert-True ($expected -eq $actual) "Package checksum mismatch: $fileName"
    }
    $proof = Join-Path $out 'release-evidence.txt'
    Assert-True (Test-Path -LiteralPath $proof -PathType Leaf) 'Missing container test evidence.'
    Assert-True ((Get-Content -LiteralPath $proof -Raw).Contains('candidate=' + $sha)) 'Candidate SHA mismatch.'
    Write-Host "[PASS] Build and container gates completed for $sha"
    Write-Host "[FILES] $out"
    Write-Host '[RELEASE BLOCKED] Interactive GUI, accessibility, and Linux compositor acceptance remain unverified. The native Windows archive is marked separately.'
}
catch {
    Write-Host ('[BLOCKED] ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
