param(
  [ValidateSet('Debug', 'Release')][string]$Mode = 'Release',
  [ValidateSet('Windows')][string]$Platform = 'Windows',
  [ValidateSet('amd64', 'arm64')][string]$GoArch = 'amd64',
  [string]$ProductVersion = '1.0.0'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildScript = Join-Path $ScriptDir 'build.ps1'

if (-not (Test-Path $BuildScript)) {
  throw "Build script not found: $BuildScript"
}

& $BuildScript -Mode $Mode -Platform $Platform -GoArch $GoArch -ProductVersion $ProductVersion
exit $LASTEXITCODE
