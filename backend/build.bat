@echo off
cd /d "%~dp0"
echo Building ADB Tool backend...
set GOOS=darwin
set GOARCH=arm64
go build -ldflags="-s -w" -o ..\flutter_app\macos\Runner\adb-tool .
echo Backend copied to flutter_app\macos\Runner\adb-tool
pause
