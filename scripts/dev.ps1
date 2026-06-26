# scripts/dev.ps1 - Windows development-mode one-shot launcher
#
# Mirrors scripts/dev.sh (macOS). Optimized for daily dev loop:
#   - Incremental builds (Gradle / Go / Flutter all reuse prior artifacts)
#   - No codesign, no MSI (flutter run handles it)
#   - flutter run instead of flutter build (hot reload enabled)
#
# Flow:
#   1. Build Android helper App (debug APK) -> backend/clipboard-helper.apk
#   2. Build Go backend -> flutter_app/windows/runner/Resources/runtime.exe
#   3. Launch Flutter (debug, foreground, Ctrl+C to exit)
#
# Usage:
#   scripts\dev.ps1                        # all three steps, then flutter run
#   scripts\dev.ps1 -SkipApk              # skip APK build (Android code unchanged)
#   scripts\dev.ps1 -SkipBackend          # skip Go build (Go code unchanged)
#   scripts\dev.ps1 -Device windows       # target Flutter device
#   scripts\dev.ps1 -BuildOnly            # build only, do not launch Flutter
#   scripts\dev.ps1 -BackendOnly          # only build Go backend (sets -SkipApk -BuildOnly)
#   scripts\dev.ps1 -AndroidHome D:\X     # override Android SDK root
#
# Output text below is intentionally in CJK for the user's terminal. All CJK
# strings are runtime output only (never inside comments), so PowerShell 5.1
# ANSI-vs-UTF8 parsing is not affected. UTF-8 output is enabled via
# [Console]::OutputEncoding below.

[CmdletBinding()]
param(
  [switch]$SkipApk,
  [switch]$SkipBackend,
  [switch]$BuildOnly,
  [switch]$BackendOnly,
  [string]$Device = '',
  [string]$AndroidHome = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path (Join-Path $ScriptDir '..')).Path

# -BackendOnly is shorthand for -SkipApk -BuildOnly
if ($BackendOnly) {
  $SkipApk = $true
  $BuildOnly = $true
}

function Step([string]$Msg) {
  Write-Host ''
  Write-Host "[>>] $Msg" -ForegroundColor Cyan
}
function Ok([string]$Msg) {
  Write-Host "[OK] $Msg" -ForegroundColor Green
}
function Warn([string]$Msg) {
  Write-Host "[! ] $Msg" -ForegroundColor Yellow
}
function Die([string]$Msg) {
  Write-Host "[X ] $Msg" -ForegroundColor Red
  exit 1
}

# Resolve ANDROID_HOME. Priority:
#   1. -AndroidHome param
#   2. $env:ANDROID_HOME
#   3. sdk.dir from adb_tool_app\local.properties
#   4. D:\Documents\SDK (project default)
# Gradle priority: ANDROID_HOME env > local.properties sdk.dir
function Resolve-AndroidHome {
  if ($AndroidHome -ne '') { return $AndroidHome }
  if ($env:ANDROID_HOME) { return $env:ANDROID_HOME }

  $localProps = Join-Path $Root 'adb_tool_app\local.properties'
  if (Test-Path $localProps) {
    $line = Select-String -Path $localProps -Pattern '^sdk\.dir=' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($line) {
      $val = ($line.Line -replace '^sdk\.dir=', '').Trim()
      # local.properties escapes backslashes as \\; restore them
      $val = $val -replace '\\\\', '\'
      if ($val -ne '' -and (Test-Path $val)) { return $val }
    }
  }

  return 'D:\Documents\SDK'
}

$ResolvedAndroidHome = Resolve-AndroidHome
$env:ANDROID_HOME = $ResolvedAndroidHome
$env:ANDROID_SDK_ROOT = $ResolvedAndroidHome
# PATH uses ';' on Windows. engine.go's findBinary now also handles .bat, so
# modern cmdline-tools (no .exe, only .bat wrappers) are picked up correctly.
$env:Path = "$ResolvedAndroidHome\emulator;$ResolvedAndroidHome\platform-tools;$ResolvedAndroidHome\cmdline-tools\latest\bin;$env:Path"

function Build-AndroidApk {
  $apkSrc = Join-Path $Root 'adb_tool_app\app\build\outputs\apk\debug\app-debug.apk'
  $apkDst = Join-Path $Root 'backend\clipboard-helper.apk'
  $apkDir = Join-Path $Root 'adb_tool_app'

  if (-not (Test-Path $apkDir)) {
    Warn 'adb_tool_app/ not found, skip APK build'
    return
  }

  Step "[1/2] Build Android helper APK (debug)... [ANDROID_HOME=$ResolvedAndroidHome]"

  Push-Location $apkDir
  try {
    & .\gradlew.bat assembleDebug -x lintVitalAnalyzeRelease -x lintVitalReportRelease -x lintAnalyzeRelease -x lintVitalRelease -x lintReportRelease --console=plain
    if ($LASTEXITCODE -ne 0) {
      if (Test-Path $apkDst) {
        Warn "Gradle failed; reusing existing $apkDst"
        return
      }
      Die 'Gradle failed and backend\clipboard-helper.apk does not exist. Fix Android build first.'
    }
  } finally {
    Pop-Location
  }

  if (-not (Test-Path $apkSrc)) {
    if (Test-Path $apkDst) {
      Warn "$apkSrc not produced; reusing existing $apkDst"
      return
    }
    Die 'Gradle did not produce APK and no fallback APK exists.'
  }

  Copy-Item -Path $apkSrc -Destination $apkDst -Force
  Ok "APK copied: $apkDst"
}

function Build-GoBackend {
  $out = Join-Path $Root 'flutter_app\windows\runner\Resources\runtime.exe'

  Step "[2/2] Build Go backend -> $out"

  Push-Location (Join-Path $Root 'backend')
  try {
    & go build -o $out .
    if ($LASTEXITCODE -ne 0) {
      Die "go build failed (exit=$LASTEXITCODE)"
    }
  } finally {
    Pop-Location
  }

  Ok 'Backend compiled'
}

# Main flow
if (-not $SkipApk)     { Build-AndroidApk }
if (-not $SkipBackend) { Build-GoBackend }

if ($BuildOnly) {
  Ok 'Build complete (-BuildOnly set, Flutter not launched).'
  exit 0
}

Step 'Launching Flutter (debug, hot reload; Ctrl+C to exit)'
Push-Location (Join-Path $Root 'flutter_app')
try {
  $exe = (Get-Command flutter -ErrorAction Stop).Source
  $argList = @('run')
  if ($Device -ne '') { $argList += @('-d', $Device) }
  $argList += @('--debug')
  & $exe @argList
  exit $LASTEXITCODE
} finally {
  Pop-Location
}