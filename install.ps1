param(
    [string]$Repository = "StationPC-Technology/stationospro-cli",
    [string]$Version = "latest",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "StationOS\bin"),
    [ValidateSet("", "cursor", "claude", "codex")][string]$WithSkill = ""
)
$ErrorActionPreference = "Stop"
if ($Repository -eq "StationPC-Technology/stationospro-cli" -or $Repository -notmatch '^[\w.-]+/[\w.-]+$') {
    throw "Specify the distribution repository with -Repository owner/repository"
}
if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") { throw "Only Windows x64 is currently supported" }
if ($Version -eq "latest") {
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest"
    $Version = $release.tag_name
}
$Version = $Version -replace '^v', ''
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid release version" }
$name = "stationos-cli-$Version-windows-amd64.exe"
$base = "https://github.com/$Repository/releases/download/v$Version"
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$installTemp = $null
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $download = Join-Path $tempDir $name
    Invoke-WebRequest "$base/$name" -OutFile $download
    Invoke-WebRequest "$base/checksums.txt" -OutFile (Join-Path $tempDir "checksums.txt")
    $line = Get-Content (Join-Path $tempDir "checksums.txt") | Where-Object { ($_ -split '\s+')[1] -eq $name }
    if (-not $line) { throw "Asset missing from checksums.txt" }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash $download -Algorithm SHA256).Hash
    if ($expected -ne $actual) { throw "Checksum mismatch; existing CLI was not changed" }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $installTemp = Join-Path $InstallDir (".stationos-cli-" + [guid]::NewGuid().ToString() + ".exe")
    Copy-Item $download $installTemp
    Move-Item $installTemp (Join-Path $InstallDir "stationos-cli.exe") -Force
    $userPath = [string][Environment]::GetEnvironmentVariable("PATH", "User")
    if (($userPath -split ';') -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable("PATH", ($userPath.TrimEnd(';') + ';' + $InstallDir).TrimStart(';'), "User")
    }
    $env:PATH = "$InstallDir;$env:PATH"
    Write-Output "Installed stationos-cli $Version. Restart terminals to refresh PATH."
    if ($WithSkill) {
        & (Join-Path $InstallDir "stationos-cli.exe") skills install --client $WithSkill
        if ($LASTEXITCODE -ne 0) { throw "CLI installed, but skill installation failed" }
    }
} finally {
    Remove-Item $tempDir -Recurse -Force
    if ($installTemp -and (Test-Path $installTemp)) { Remove-Item $installTemp -Force }
}
