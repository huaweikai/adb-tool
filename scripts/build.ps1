param(
  [ValidateSet('Debug', 'Release')][string]$Mode = 'Release',
  [ValidateSet('Windows')][string]$Platform = 'Windows',
  [ValidateSet('amd64', 'arm64')][string]$GoArch = 'amd64',
  [string]$ProductVersion = '1.0.0'
)

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command not found: $Name"
  }
}

function Run-Command([string]$Name, [string[]]$ArgsList) {
  & $Name @ArgsList
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $Name $($ArgsList -join ' ')"
  }
}

function Get-WixMajorVersion {
  $versionOutput = & wix --version 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to get WiX version"
  }

  $versionText = ($versionOutput | Select-Object -First 1).ToString()
  if ($versionText -match '^(\d+)\.') {
    return [int]$Matches[1]
  }

  throw "Unable to parse WiX version: $versionText"
}

function Ensure-WixSupportedVersion {
  $major = Get-WixMajorVersion
  if ($major -ge 7) {
    throw "WiX Toolset v$major requires OSMF EULA acceptance. Please install WiX v5 instead: dotnet tool uninstall --global wix; dotnet tool install --global wix --version 5.0.2"
  }
}

function Ensure-WixExtension([string]$ExtensionName, [string]$ExtensionVersion) {
  Ensure-WixSupportedVersion

  $list = & wix extension list 2>$null
  $listText = $list -join "`n"
  if ($LASTEXITCODE -eq 0 -and $listText -match [regex]::Escape($ExtensionName) -and $listText -match [regex]::Escape($ExtensionVersion)) {
    return
  }

  & wix extension remove $ExtensionName 2>$null | Out-Null

  Write-Host "==> Installing WiX extension: $ExtensionName/$ExtensionVersion"
  & wix extension add "$ExtensionName/$ExtensionVersion"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to install WiX extension: $ExtensionName/$ExtensionVersion"
  }
}

function Stop-BuildProcesses {
  $names = @('launcher', 'runtime', 'adb-tool', 'adb_tool', 'adb_tool_server', 'adb_tool_ui')
  foreach ($name in $names) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 500
}

function Remove-DirectoryStrict([string]$Path) {
  if (-not (Test-Path $Path)) {
    return
  }

  Remove-Item $Path -Recurse -Force -ErrorAction Stop
  if (Test-Path $Path) {
    throw "Failed to remove directory: $Path"
  }
}

function ConvertTo-WixId([string]$Value) {
  $id = $Value -replace '[^A-Za-z0-9_]', '_'
  if ($id -notmatch '^[A-Za-z_]') {
    $id = "_$id"
  }
  return $id
}

function ConvertTo-XmlAttribute([string]$Value) {
  return [System.Security.SecurityElement]::Escape($Value)
}

function Build-ClipboardHelperApk([string]$ProjectDir, [string]$ApkSource, [string]$ApkDestination) {
  if ([string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    if (Test-Path $ApkDestination) {
      Write-Warning "ANDROID_HOME is not set, using existing clipboard helper APK: $ApkDestination"
      return
    }
    throw "ANDROID_HOME is not set and existing clipboard helper APK was not found: $ApkDestination. Please set ANDROID_HOME to your Android SDK path."
  }

  if (-not (Test-Path $ProjectDir)) {
    if (Test-Path $ApkDestination) {
      Write-Warning "adb_tool_app not found, using existing clipboard helper APK: $ApkDestination"
      return
    }
    throw "adb_tool_app not found and existing clipboard helper APK was not found: $ApkDestination"
  }

  $gradleWrapper = Join-Path $ProjectDir 'gradlew.bat'
  if (-not (Test-Path $gradleWrapper)) {
    if (Test-Path $ApkDestination) {
      Write-Warning "gradlew.bat not found, using existing clipboard helper APK: $ApkDestination"
      return
    }
    throw "gradlew.bat not found and existing clipboard helper APK was not found: $ApkDestination"
  }

  Write-Host "==> Building clipboard helper APK"
  Push-Location $ProjectDir
  & $gradleWrapper @('assembleDebug', '-x', 'lintVitalAnalyzeRelease', '-x', 'lintVitalReportRelease', '-x', 'lintAnalyzeRelease', '-x', 'lintVitalRelease', '-x', 'lintReportRelease')
  $gradleExitCode = $LASTEXITCODE
  Pop-Location

  if ($gradleExitCode -eq 0 -and (Test-Path $ApkSource)) {
    Copy-Item -Force $ApkSource $ApkDestination
    Write-Host "Clipboard helper APK output: $ApkDestination"
    return
  }

  if (Test-Path $ApkDestination) {
    Write-Warning "Clipboard helper APK build failed or output was not found, using existing APK: $ApkDestination"
    return
  }

  throw "Clipboard helper APK build failed and existing APK was not found: $ApkDestination. Please set ANDROID_HOME to a valid Android SDK path and rebuild."
}

function New-WixSource([string]$TemplatePath, [string]$SourceDir, [string]$OutputPath) {
  $sourceRoot = (Resolve-Path $SourceDir).Path
  $sourceRootWithSlash = $sourceRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  $directories = New-Object System.Text.StringBuilder
  $components = New-Object System.Text.StringBuilder
  $refs = New-Object System.Text.StringBuilder
  $directoryIds = @{'__ROOT__' = 'INSTALLFOLDER'}

  $dirs = Get-ChildItem -Path $sourceRoot -Directory -Recurse | Sort-Object FullName
  foreach ($dir in $dirs) {
    $relative = $dir.FullName.Substring($sourceRootWithSlash.Length)
    $dirId = 'Dir_' + (ConvertTo-WixId $relative)
    $directoryIds[$relative] = $dirId
    $parentRelative = [System.IO.Path]::GetDirectoryName($relative)
    if ([string]::IsNullOrEmpty($parentRelative)) {
      $parentRelative = '__ROOT__'
    }
    $parentId = $directoryIds[$parentRelative]
    $name = ConvertTo-XmlAttribute $dir.Name

    if ($parentId -eq 'INSTALLFOLDER') {
      [void]$directories.AppendLine(('        <Directory Id="{0}" Name="{1}" />' -f $dirId, $name))
    } else {
      [void]$components.AppendLine(('    <DirectoryRef Id="{0}">' -f $parentId))
      [void]$components.AppendLine(('      <Directory Id="{0}" Name="{1}" />' -f $dirId, $name))
      [void]$components.AppendLine('    </DirectoryRef>')
    }
  }

  $files = Get-ChildItem -Path $sourceRoot -File -Recurse | Sort-Object FullName
  $index = 0
  foreach ($file in $files) {
    $index++
    if ($file.DirectoryName -ieq $sourceRoot) {
      $relativeDir = '__ROOT__'
    } else {
      $relativeDir = $file.DirectoryName.Substring($sourceRootWithSlash.Length)
    }
    $dirId = $directoryIds[$relativeDir]
    $componentId = "Cmp_$index"
    $fileId = "File_$index"
    $source = ConvertTo-XmlAttribute $file.FullName

    [void]$components.AppendLine(('    <DirectoryRef Id="{0}">' -f $dirId))
    [void]$components.AppendLine(('      <Component Id="{0}" Guid="*" Bitness="always64">' -f $componentId))
    [void]$components.AppendLine(('        <File Id="{0}" Source="{1}" KeyPath="yes" />' -f $fileId, $source))
    [void]$components.AppendLine('      </Component>')
    [void]$components.AppendLine('    </DirectoryRef>')
    [void]$refs.AppendLine(('      <ComponentRef Id="{0}" />' -f $componentId))
  }

  $content = Get-Content $TemplatePath -Raw
  $content = $content.Replace('__APP_DIRECTORIES__', $directories.ToString().TrimEnd())
  $content = $content.Replace('__APP_COMPONENTS__', $components.ToString().TrimEnd())
  $content = $content.Replace('__APP_COMPONENT_REFS__', $refs.ToString().TrimEnd())
  Set-Content -Path $OutputPath -Value $content -Encoding UTF8
}

Require-Command go
Require-Command flutter
Require-Command wix
Ensure-WixSupportedVersion

if ($Platform -ne 'Windows') {
  throw "This script is for Windows build only"
}

if ($ProductVersion -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') {
  throw "ProductVersion must be numeric, for example 1.0.0 or 1.0.0.0"
}

$BackendDir = Join-Path $RootDir 'backend'
$FlutterDir = Join-Path $RootDir 'flutter_app'
$ClipboardAppDir = Join-Path $RootDir 'adb_tool_app'
$ClipboardApkSource = Join-Path $ClipboardAppDir 'app\build\outputs\apk\debug\app-debug.apk'
$ClipboardApkDestination = Join-Path $BackendDir 'clipboard-helper.apk'
$RunnerResDir = Join-Path $FlutterDir 'windows\runner\Resources'
$BuildWindowsDir = Join-Path $FlutterDir 'build\windows'
$DistDir = Join-Path $RootDir 'dist\windows'
$InstallerSource = Join-Path $RootDir 'scripts\installer.wxs'
$GeneratedInstallerSource = Join-Path $DistDir 'installer.generated.wxs'
$BackendOut = Join-Path $RunnerResDir 'runtime.exe'

New-Item -ItemType Directory -Force -Path $RunnerResDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "==> Stopping running build outputs"
Stop-BuildProcesses

if (Test-Path $BuildWindowsDir) {
  Write-Host "==> Removing stale Flutter Windows build cache"
  Remove-DirectoryStrict $BuildWindowsDir
}

Build-ClipboardHelperApk $ClipboardAppDir $ClipboardApkSource $ClipboardApkDestination
if (-not (Test-Path $ClipboardApkDestination)) {
  throw "Clipboard helper APK was not found: $ClipboardApkDestination"
}

Write-Host "==> Building runtime (GOOS=windows GOARCH=$GoArch)"
Push-Location $BackendDir
$env:GOOS = 'windows'
$env:GOARCH = $GoArch
Run-Command go @('build', '-ldflags=-s -w', '-o', $BackendOut, '.')
Pop-Location
Write-Host "Runtime output: $BackendOut"

if (-not (Test-Path (Join-Path $FlutterDir 'windows'))) {
  throw "flutter_app/windows not found. Run in flutter_app: flutter create --platforms=windows ."
}

$FlutterFlag = if ($Mode -eq 'Release') { '--release' } else { '--debug' }

Write-Host "==> Building Flutter Windows ($Mode)"
Push-Location $FlutterDir
Run-Command flutter @('build', 'windows', $FlutterFlag)
Pop-Location

$ExpectedRunnerOut = Join-Path $BuildWindowsDir "x64\runner\$Mode"
if ($GoArch -eq 'arm64') {
  $ExpectedRunnerOut = Join-Path $BuildWindowsDir "arm64\runner\$Mode"
}

if (Test-Path $ExpectedRunnerOut) {
  $RunnerOutDir = Get-Item $ExpectedRunnerOut
} else {
  $RunnerOutDir = Get-ChildItem -Path $BuildWindowsDir -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\runner\\[^\\]*$' } |
    Select-Object -First 1
}

if (-not $RunnerOutDir) {
  throw "Runner output directory not found under: $BuildWindowsDir"
}

Write-Host "Flutter build output: $($RunnerOutDir.FullName)"

$RuntimeInOutput = Join-Path $RunnerOutDir.FullName 'runtime.exe'
if (-not (Test-Path $RuntimeInOutput)) {
  Copy-Item -Force $BackendOut $RuntimeInOutput
}

$UninstallOut = Join-Path $RunnerOutDir.FullName 'uninstall.exe'
Write-Host "==> Building uninstaller"
Push-Location $BackendDir
Run-Command go @('build', '-ldflags=-H windowsgui -s -w', '-o', $UninstallOut, './uninstall/')
Pop-Location

Get-ChildItem -Path $RunnerOutDir.FullName -Filter 'adb_tool*.exe' -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $RunnerOutDir.FullName -Filter 'adb-tool.exe' -File -ErrorAction SilentlyContinue | Remove-Item -Force

$MsiOut = Join-Path $DistDir "ADBToolSetup-$ProductVersion-windows-$GoArch.msi"
if (Test-Path $MsiOut) {
  Remove-Item $MsiOut -Force
}

Ensure-WixExtension 'WixToolset.UI.wixext' '5.0.2'

Write-Host "==> Generating MSI source"
New-WixSource $InstallerSource $RunnerOutDir.FullName $GeneratedInstallerSource

Write-Host "==> Building MSI"
Run-Command wix @('build', $GeneratedInstallerSource, '-ext', 'WixToolset.UI.wixext', '-d', "ProductVersion=$ProductVersion", '-o', $MsiOut)

if (-not (Test-Path $MsiOut)) {
  throw "MSI was not created: $MsiOut"
}

Write-Host "==> MSI ready: $MsiOut"
Write-Host "Installed app entry: launcher.exe"
Write-Host "Installed runtime: runtime.exe"
Write-Host "Installed uninstaller: uninstall.exe"
