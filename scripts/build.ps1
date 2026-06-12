param(
  [ValidateSet('Debug', 'Release')][string]$Mode = 'Release',
  [ValidateSet('Windows')][string]$Platform = 'Windows',
  [ValidateSet('amd64', 'arm64')][string]$GoArch = 'amd64'
)

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command not found: $Name"
  }
}

Require-Command go
Require-Command flutter

if ($Platform -ne 'Windows') {
  throw "This script is for Windows build only"
}

$BackendDir = Join-Path $RootDir 'backend'
$FlutterDir = Join-Path $RootDir 'flutter_app'
$BackendOutFallback = Join-Path $FlutterDir 'adb-tool.exe'

$RunnerResDir = Join-Path $FlutterDir 'windows\runner\Resources'
$BackendOut = $BackendOutFallback
if (Test-Path $RunnerResDir) {
  $BackendOut = Join-Path $RunnerResDir 'adb-tool.exe'
}

Write-Host "==> Building Go backend (GOOS=windows GOARCH=$GoArch)"
Push-Location $BackendDir
$env:GOOS = 'windows'
$env:GOARCH = $GoArch
go build -ldflags="-s -w" -o $BackendOut .
Pop-Location
Write-Host "Backend output: $BackendOut"

if (-not (Test-Path (Join-Path $FlutterDir 'windows'))) {
  throw "flutter_app/windows not found. Run in flutter_app: flutter create --platforms=windows ."
}

$FlutterFlag = if ($Mode -eq 'Release') { '--release' } else { '--debug' }

Write-Host "==> Building Flutter Windows ($Mode)"
Push-Location $FlutterDir
flutter build windows $FlutterFlag
Pop-Location

$BuildWindowsDir = Join-Path $FlutterDir 'build\windows'
if (Test-Path $BuildWindowsDir) {
  $RunnerOutDir = Get-ChildItem -Path $BuildWindowsDir -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\runner\\[^\\]*$" } |
    Select-Object -First 1

  if ($RunnerOutDir) {
    $Dst = Join-Path $RunnerOutDir.FullName 'adb-tool.exe'
    if (-not (Test-Path $Dst)) {
      Copy-Item -Force $BackendOut $Dst
      Write-Host "Backend binary copied to build output: $Dst"
    } else {
      Write-Host "Backend binary already in build output (CMake installed it)"
    }
    Write-Host "Output directory: $($RunnerOutDir.FullName)"
  } else {
    Write-Host "Runner output directory not found, skipping copy: $BuildWindowsDir"
  }
} else {
  Write-Host "Build directory not found: $BuildWindowsDir"
}
