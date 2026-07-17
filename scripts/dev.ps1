# scripts/dev.ps1 - Windows development-mode one-shot launcher
#
# Mirrors scripts/dev.sh (macOS). Optimized for daily dev loop:
#   - Incremental builds (Gradle / Go / Flutter all reuse prior artifacts)
#   - No codesign, no MSI (flutter run handles it)
#   - flutter run instead of flutter build (hot reload enabled)
#
# Flow:
#   1. Build Android helper App (release APK) -> backend/clipboard-helper.apk
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
# Gradle priority: ANDROID_HOME env > local.properties sdk.dir
#
# Fix (code-review M16): the previous fallback to the developer-specific
# 'D:\Documents\SDK' hard-coded in this repo made the script fail for
# every other contributor and CI. Don't silently default to a host-
# specific path; fail fast and tell the caller to pass -AndroidHome
# or set $env:ANDROID_HOME.
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

  Die 'No ANDROID_HOME found. Pass -AndroidHome <path>, set $env:ANDROID_HOME, or write sdk.dir in adb_tool_app\local.properties.'
}

$ResolvedAndroidHome = Resolve-AndroidHome
$env:ANDROID_HOME = $ResolvedAndroidHome
$env:ANDROID_SDK_ROOT = $ResolvedAndroidHome
# PATH uses ';' on Windows. engine.go's findBinary now also handles .bat, so
# modern cmdline-tools (no .exe, only .bat wrappers) are picked up correctly.
$env:Path = "$ResolvedAndroidHome\emulator;$ResolvedAndroidHome\platform-tools;$ResolvedAndroidHome\cmdline-tools\latest\bin;$env:Path"

function Build-AndroidApk {
  $apkSrc = Join-Path $Root 'adb_tool_app\app\build\outputs\apk\release\app-release.apk'
  $apkDst = Join-Path $Root 'backend\clipboard-helper.apk'
  $apkDir = Join-Path $Root 'adb_tool_app'

  if (-not (Test-Path $apkDir)) {
    Warn 'adb_tool_app/ not found, skip APK build'
    return
  }

  Step "[1/2] Build Android helper APK (release)... [ANDROID_HOME=$ResolvedAndroidHome]"

  Push-Location $apkDir
  try {
    & .\gradlew.bat assembleRelease -x lintVitalAnalyzeRelease -x lintVitalReportRelease -x lintAnalyzeRelease -x lintVitalRelease -x lintReportRelease --console=plain
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

  # Kill any leftover runtime.exe from a previous dev session before we
  # overwrite the binary. On Windows an in-use binary can stay open with
  # a file lock, and the new process would still read the *old* code in
  # some edge cases. Killing first makes the rebuild deterministic.
  Stop-RuntimeBackend

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

  # Sync the freshly built binary into every Flutter build-mode directory
  # the running `flutter run` is actually launching from. Without this,
  # Resources/runtime.exe is the only one we just updated — but `flutter
  # run` dev mode starts a process from
  # `flutter_app/build/windows/x64/runner/Debug/runtime.exe` (copied by
  # CMake at the start of `flutter run`), so all our changes look like
  # they have no effect.
  Sync-BackendToFlutterBuild
}

function Sync-BackendToFlutterBuild {
  $src = Join-Path $Root 'flutter_app\windows\runner\Resources\runtime.exe'
  if (-not (Test-Path $src)) { return }

  $buildRoot = Join-Path $Root 'flutter_app\build\windows\x64\runner'
  if (-not (Test-Path $buildRoot)) { return }

  foreach ($mode in @('Debug', 'Profile', 'Release')) {
    $dst = Join-Path $buildRoot $mode
    if (Test-Path $dst) {
      try {
        Copy-Item -Path $src -Destination (Join-Path $dst 'runtime.exe') -Force
        Write-Host "  synced runtime.exe -> $dst" -ForegroundColor DarkGray
      } catch {
        Write-Host "  could not sync to $dst (binary may be in use): $_" -ForegroundColor Yellow
      }
    }
  }
}

# Kill every lingering adb-tool backend binary (any previous `flutter run`
# that didn't clean up its child process). Without this the next `flutter
# run` either fails to bind 9876 or picks up the stale binary.
function Stop-RuntimeBackend {
  $procs = Get-Process -Name 'runtime' -ErrorAction SilentlyContinue
  if (-not $procs) { return }
  foreach ($p in $procs) {
    Write-Host "  killing stale runtime.exe (pid=$($p.Id))" -ForegroundColor DarkGray
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
  }
  Start-Sleep -Milliseconds 400
}

# Main flow
if (-not $SkipApk)     { Build-AndroidApk }
if (-not $SkipBackend) { Build-GoBackend }

if ($BuildOnly) {
  Ok 'Build complete (-BuildOnly set, Flutter not launched).'
  exit 0
}

# Belt-and-suspenders: kill again right before launching Flutter in case
# the previous session's child popped back up after Build-GoBackend ran.
Stop-RuntimeBackend

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