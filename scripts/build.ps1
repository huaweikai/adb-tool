param(
  [ValidateSet('Debug', 'Release')][string]$Mode = 'Release',
  [ValidateSet('Windows')][string]$Platform = 'Windows',
  [ValidateSet('amd64', 'arm64')][string]$GoArch = 'amd64'
)

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "找不到命令：$Name"
  }
}

Require-Command go
Require-Command flutter

if ($Platform -ne 'Windows') {
  throw "该脚本仅用于 Windows 构建"
}

$BackendDir = Join-Path $RootDir 'backend'
$FlutterDir = Join-Path $RootDir 'flutter_app'
$BackendOutFallback = Join-Path $FlutterDir 'adb-tool.exe'

$RunnerResDir = Join-Path $FlutterDir 'windows\runner\Resources'
$BackendOut = $BackendOutFallback
if (Test-Path $RunnerResDir) {
  $BackendOut = Join-Path $RunnerResDir 'adb-tool.exe'
}

Write-Host "==> 编译后端 (GOOS=windows GOARCH=$GoArch)"
Push-Location $BackendDir
$env:GOOS = 'windows'
$env:GOARCH = $GoArch
go build -ldflags="-s -w" -o $BackendOut .
Pop-Location
Write-Host "后端已输出：$BackendOut"

if (-not (Test-Path (Join-Path $FlutterDir 'windows'))) {
  throw "flutter_app/windows 不存在。请先在 flutter_app 目录执行：flutter create --platforms=windows ."
}

$FlutterFlag = if ($Mode -eq 'Release') { '--release' } else { '--debug' }

Write-Host "==> 编译 Flutter Windows ($Mode)"
Push-Location $FlutterDir
flutter build windows $FlutterFlag
Pop-Location

$BuildWindowsDir = Join-Path $FlutterDir 'build\windows'
if (Test-Path $BuildWindowsDir) {
  $RunnerOutDir = Get-ChildItem -Path $BuildWindowsDir -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\runner\\$Mode$" } |
    Select-Object -First 1

  if ($RunnerOutDir) {
    $Dst = Join-Path $RunnerOutDir.FullName 'adb-tool.exe'
    Copy-Item -Force $BackendOut $Dst
    Write-Host "已确保后端写入产物目录：$Dst"
    Write-Host "产物目录：$($RunnerOutDir.FullName)"
  } else {
    Write-Host "未找到 runner 输出目录，跳过拷贝：$BuildWindowsDir"
  }
} else {
  Write-Host "未找到构建目录：$BuildWindowsDir"
}
