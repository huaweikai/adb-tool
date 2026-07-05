param(
  [ValidateSet('Debug','Release')][string]$Mode = 'Release',
  [string]$ProductVersion = '0.0.0'
)

$Root = (Resolve-Path "$PSScriptRoot/..").Path

$Dist = "$Root/dist/windows"
$Android = "$Root/dist/android"

function Build-Android {
  $src="$Root/adb_tool_app/app/build/outputs/apk/release/app-release.apk"

  if (Test-Path "$Root/adb_tool_app") {
    Push-Location "$Root/adb_tool_app"
    ./gradlew assembleRelease | Out-Null
    Pop-Location
  }

  if (Test-Path $src) {
    Copy-Item $src "$Root/backend/clipboard-helper.apk" -Force
    Copy-Item $src "$Android/clipboard-helper.apk" -Force
  }
}

function Build-Go {
  $runner="$Root/flutter_app/windows/runner"

  Push-Location "$Root/backend"
  go build -ldflags "-s -w" -o "$runner/runtime.exe" .
  go build -ldflags "-H windowsgui -s -w" -o "$runner/uninstall.exe" ./uninstall/
  Pop-Location
}

function Build-Flutter {
  Push-Location "$Root/flutter_app"
  flutter pub get
  flutter build windows --release
  Pop-Location

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
}

function Build-MSI {

  $runner="$Root/flutter_app/build/windows/x64/runner/Release"

  # Ensure WiX v5 is available — v7 requires an OSMF EULA and breaks
  # WixToolset.UI.wixext/5.0.2.
  dotnet tool uninstall --global wix 2>$null
  dotnet tool install --global wix --version 5.0.2 2>$null
  if ($LASTEXITCODE -ne 0) {
    dotnet tool update --global wix --version 5.0.2 2>$null
  }

  $wixVersion = (& wix --version 2>$null | Select-Object -First 1) -join ''
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
  #    so they nest under their parent.
  Get-ChildItem $Dir -Recurse -Directory | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\','/'
    $idx = $rel.LastIndexOf('/')
    $parentRel = if ($idx -ge 0) { $rel.Substring(0, $idx) } else { '' }
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

New-Item -ItemType Directory -Force -Path $Dist,$Android | Out-Null

Build-Android
Build-Go
Build-Flutter
Build-MSI

Write-Host "Windows OK"