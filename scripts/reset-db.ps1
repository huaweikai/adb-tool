# scripts/reset-db.ps1
#
# Wipes the local SQLite DB for the adb_tool Flutter app. Useful while
# we're still refactoring — the schema is in flux, and the cheapest
# way to land a new schema is to delete the file and let the app
# re-create it via AppDatabase.onCreate.
#
# Usage:
#   pwsh scripts/reset-db.ps1                # kill app, delete db, done
#   pwsh scripts/reset-db.ps1 -KeepRunning   # delete the db file only
#                                           # (fails if app is running —
#                                           #  SQLite holds the file open)
#   pwsh scripts/reset-db.ps1 -DbPath "..."  # override the path
#
# Default path matches what `getApplicationSupportDirectory()` resolves
# to on Windows for the `com.example\ADB Tool` bundle id.

param(
  [string]$DbPath = "$env:APPDATA\com.example\ADB Tool\adb_tool.db",
  [switch]$KeepRunning
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$AppProcessNames = @('adb_tool_app', 'adb_tool')

function Find-AppProcess {
  foreach ($name in $AppProcessNames) {
    $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($proc) { return $proc }
  }
  return $null
}

if (-not $KeepRunning) {
  $proc = Find-AppProcess
  if ($proc) {
    Write-Host "Stopping running app process: $($proc.ProcessName) (PID $($proc.Id))"
    Stop-Process -Id $proc.Id -Force
    # Give the OS a moment to release the SQLite file handle.
    Start-Sleep -Milliseconds 500
  } else {
    Write-Host "No adb_tool process running."
  }
}

if (-not (Test-Path -Path $DbPath)) {
  Write-Host "DB not found at $DbPath — nothing to delete."
  exit 0
}

$size = (Get-Item $DbPath).Length
Remove-Item -Path $DbPath -Force
Write-Host "Deleted $DbPath ($size bytes). App will recreate it on next launch via onCreate."
