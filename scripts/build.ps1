param(
  [ValidateSet('Debug','Release')][string]$Mode = 'Release',
  [string]$ProductVersion = '0.0.0',
  [string]$PythonExecutable
)

$Root = (Resolve-Path "$PSScriptRoot/..").Path

$Dist = "$Root/dist/windows"
$Android = "$Root/dist/android"
$IosTools = "$Root/dist/ios-tools"

function Build-Go {
  $runner="$Root/flutter_app/windows/runner"

  Push-Location "$Root/backend"
  try {
    go build -ldflags "-s -w" -o "$runner/runtime.exe" .
    if ($LASTEXITCODE -ne 0) { throw "Failed to build the Go backend" }
    go build -ldflags "-H windowsgui -s -w" -o "$runner/uninstall.exe" ./uninstall/
    if ($LASTEXITCODE -ne 0) { throw "Failed to build the Windows uninstaller" }
  } finally {
    Pop-Location
  }
}

function Build-Flutter {
  $fullVer = (Select-String -Path "$Root/flutter_app/pubspec.yaml" -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
  $ver = $fullVer -replace '\+.*$',''
  $build = if ($fullVer -match '\+(\d+)$') { $Matches[1] } else { '0' }
  Push-Location "$Root/flutter_app"
  try {
    flutter build windows --release `
      --dart-define=APP_VERSION=$ver `
      --dart-define=APP_BUILD=$build
    if ($LASTEXITCODE -ne 0) { throw "Failed to build the Flutter Windows app" }
  } finally {
    Pop-Location
  }

  # Build-Go writes runtime.exe / uninstall.exe into flutter_app/windows/runner/
  # but Flutter's CMake build does not pick them up (they are not in the install
  # rules). Copy them into the Release output so MSI packs them up.
  $release = "$Root/flutter_app/build/windows/x64/runner/Release"
  if (Test-Path $release) {
    foreach ($bin in 'runtime.exe','uninstall.exe') {
      $src = "$Root/flutter_app/windows/runner/$bin"
      if (Test-Path $src) {
        Copy-Item -Force $src "$release/$bin"
      }
    }
  }
  Copy-Item -Force -ErrorAction Stop "$IosTools/pymobiledevice3.exe" "$release/"
  Copy-Item -Force -ErrorAction Stop "$IosTools/pymobiledevice3-source.zip" "$release/"
}

function Build-MSI {

  $runner="$Root/flutter_app/build/windows/x64/runner/Release"

  # Ensure WiX v5 is available — v7 requires an OSMF EULA and breaks
  # WixToolset.UI.wixext/5.0.2.
  $wixVersion = if (Get-Command wix -CommandType Application -ErrorAction SilentlyContinue) {
    (& wix --version 2>$null | Select-Object -First 1) -join ''
  }
  if ($wixVersion -notmatch '^5\.0\.2\b') {
    dotnet tool uninstall --global wix 2>$null
    dotnet tool install --global wix --version 5.0.2 2>$null
    if ($LASTEXITCODE -ne 0) {
      dotnet tool update --global wix --version 5.0.2 2>$null
    }
    $wixVersion = (& wix --version 2>$null | Select-Object -First 1) -join ''
  }
  if ([string]::IsNullOrWhiteSpace($wixVersion)) {
    throw "WiX not found. Install it: dotnet tool install --global wix --version 5.0.2"
  }
  if ($wixVersion -match '^(\d+)\.' -and [int]$Matches[1] -ge 7) {
    throw "WiX v$($Matches[1]) requires OSMF EULA. Downgrade: dotnet tool uninstall --global wix; dotnet tool install --global wix --version 5.0.2"
  }

  wix extension add WixToolset.UI.wixext/5.0.2

  Expand-WixTemplate `
    "$Root/scripts/installer.wxs" `
    "$Root/dist/windows/installer.generated.wxs" `
    $runner

  wix build "$Root/dist/windows/installer.generated.wxs" `
    -ext WixToolset.UI.wixext `
    -d "ProductVersion=$ProductVersion" `
    -o "$Dist/ADBTool-$ProductVersion.msi"
  if ($LASTEXITCODE -ne 0) { throw "Failed to build the Windows MSI" }
}

function Expand-WixTemplate {
  param($Template,$Out,$Dir)

  # Normalize root path: get canonical absolute path without trailing sep
  $root = (Resolve-Path $Dir).Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

  # Collect all directories under root, keyed by their path relative to root
  # (forward-slashed, '' for root itself which maps to INSTALLFOLDER).
  $dirIds = @{ '' = 'INSTALLFOLDER' }
  Get-ChildItem $Dir -Recurse -Directory | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\','/'
    $id = 'Dir_' + ($rel -replace '[^A-Za-z0-9_]','_')
    $dirIds[$rel] = $id
  }

  $topDirs = New-Object System.Text.StringBuilder
  $nestedDirs = New-Object System.Text.StringBuilder
  $components = New-Object System.Text.StringBuilder
  $refs = New-Object System.Text.StringBuilder

  # 1) Emit top-level <Directory> entries (direct children of INSTALLFOLDER)
  #    into the __APP_DIRECTORIES__ slot.
  foreach ($d in (Get-ChildItem $Dir -Directory | Sort-Object Name)) {
    $id = $dirIds['']
    $rel = $d.FullName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\','/'
    $dirId = $dirIds[$rel]
    $escName = [Security.SecurityElement]::Escape($d.Name)
    [void]$topDirs.AppendLine("    <Directory Id=`"$dirId`" Name=`"$escName`" />")
  }

  # 2) Emit non-top-level <Directory> entries as <DirectoryRef> wrappers
  #    so they nest under their parent. Skip entries whose parent is root
  #    ('' → INSTALLFOLDER) — those are already in __APP_DIRECTORIES__.
  Get-ChildItem $Dir -Recurse -Directory | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\','/'
    $idx = $rel.LastIndexOf('/')
    if ($idx -lt 0) { return }
    $parentRel = $rel.Substring(0, $idx)
    $parentId = $dirIds[$parentRel]
    $dirId = $dirIds[$rel]
    $escName = [Security.SecurityElement]::Escape($_.Name)
    [void]$nestedDirs.AppendLine("<DirectoryRef Id=`"$parentId`"><Directory Id=`"$dirId`" Name=`"$escName`" /></DirectoryRef>")
  }

  # 3) Emit one <Component> per file, anchored to its containing directory.
  $i = 0
  Get-ChildItem $Dir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $i++
    $cmp = "Cmp_$i"
    $id  = "File_$i"
    $fileRel = $_.DirectoryName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\','/'
    $dirId = if ($fileRel -eq '') { 'INSTALLFOLDER' } else { $dirIds[$fileRel] }
    $escSource = [Security.SecurityElement]::Escape($_.FullName)
    [void]$components.AppendLine("<DirectoryRef Id=`"$dirId`"><Component Id=`"$cmp`" Guid=`"*`" Bitness=`"always64`"><File Id=`"$id`" Source=`"$escSource`" KeyPath=`"yes`" /></Component></DirectoryRef>")
    [void]$refs.AppendLine("<ComponentRef Id=`"$cmp`" />")
  }

  $xml = Get-Content $Template -Raw
  $xml = $xml.Replace("__APP_DIRECTORIES__", $topDirs.ToString())
  $xml = $xml.Replace("__APP_COMPONENTS__", $components.ToString() + $nestedDirs.ToString())
  $xml = $xml.Replace("__APP_COMPONENT_REFS__", $refs.ToString())

  Set-Content -Path $Out -Value $xml -Encoding UTF8
}

function Test-PackagingPython([string]$Executable) {
  if (-not (Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue)) {
    return $false
  }
  $version = & $Executable --version
  return ($LASTEXITCODE -eq 0 -and $version -match '^Python 3\.12\.')
}

if (-not $PSBoundParameters.ContainsKey('PythonExecutable')) {
  foreach ($candidate in 'python3.12.exe', 'python.exe') {
    if (Test-PackagingPython $candidate) {
      $PythonExecutable = $candidate
      break
    }
  }
  if (-not $PythonExecutable -and (Get-Command uv -CommandType Application -ErrorAction SilentlyContinue)) {
    $PythonExecutable = uv --no-cache python find --managed-python 3.12 2>$null
  }
}
if (-not $PythonExecutable -or -not (Test-PackagingPython $PythonExecutable)) {
  throw "The Windows packaging script uses Python 3.12. Install it with 'uv python install 3.12' or pass its executable path with -PythonExecutable."
}

New-Item -ItemType Directory -Force -Path $Dist,$Android | Out-Null

& $PythonExecutable "$Root/scripts/build_pymobiledevice3.py" $IosTools
if ($LASTEXITCODE -ne 0) {
  throw "Failed to build pymobiledevice3"
}
Build-Go
Build-Flutter
Build-MSI

Write-Host "Windows OK"
