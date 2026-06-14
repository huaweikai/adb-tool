Add-Type -AssemblyName System.Drawing

$root = Get-Location
$macDir = Join-Path $root 'flutter_app\macos\Runner\Assets.xcassets\AppIcon.appiconset'
$icoPath = Join-Path $root 'flutter_app\windows\runner\resources\app_icon.ico'
$sizes = @(16, 32, 64, 128, 256, 512, 1024)

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-IconBitmap([int]$size) {
  $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $graphics.Clear([System.Drawing.Color]::Transparent)

  $scale = $size / 1024.0
  $rect = New-Object System.Drawing.RectangleF (96 * $scale), (96 * $scale), (832 * $scale), (832 * $scale)
  $radius = 188 * $scale
  $path = New-RoundedRectPath $rect.X $rect.Y $rect.Width $rect.Height $radius

  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(255, 31, 41, 55)), ([System.Drawing.Color]::FromArgb(255, 9, 15, 26)), 45
  $graphics.FillPath($bgBrush, $path)
  $bgBrush.Dispose()

  if ($size -ge 64) {
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(24, 255, 255, 255)), ([Math]::Max(1, 20 * $scale))
    $graphics.DrawPath($pen, $path)
    $pen.Dispose()
  }

  $fontFamily = New-Object System.Drawing.FontFamily 'Arial'
  $adbSize = if ($size -le 32) { 250 * $scale } else { 208 * $scale }
  $adbFont = New-Object System.Drawing.Font $fontFamily, $adbSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $adbBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 245, 248, 252))
  $adbY = if ($size -le 32) { 496 * $scale } else { 480 * $scale }
  $adbRect = New-Object System.Drawing.RectangleF 0, ($adbY - 180 * $scale), $size, (360 * $scale)
  $graphics.DrawString('ADB', $adbFont, $adbBrush, $adbRect, $format)

  $lineY = if ($size -le 32) { 650 * $scale } else { 654 * $scale }
  $lineX1 = 328 * $scale
  $lineX2 = 696 * $scale
  $lineMid = 476 * $scale
  $lineW = [Math]::Max(2, 34 * $scale)
  $basePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 255, 255, 255)), $lineW
  $basePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $basePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($basePen, $lineX1, $lineY, $lineX2, $lineY)
  $basePen.Dispose()
  $greenPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 53, 224, 161)), $lineW
  $greenPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $greenPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($greenPen, $lineX1, $lineY, $lineMid, $lineY)
  $greenPen.Dispose()

  if ($size -ge 64) {
    $debugFont = New-Object System.Drawing.Font $fontFamily, (54 * $scale), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $debugBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 148, 163, 184))
    $debugRect = New-Object System.Drawing.RectangleF 0, (700 * $scale), $size, (92 * $scale)
    $graphics.DrawString('DEBUG', $debugFont, $debugBrush, $debugRect, $format)
    $debugBrush.Dispose()
    $debugFont.Dispose()
  }

  $adbBrush.Dispose()
  $adbFont.Dispose()
  $fontFamily.Dispose()
  $format.Dispose()
  $path.Dispose()
  $graphics.Dispose()
  return $bitmap
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

foreach ($size in $sizes) {
  $bitmap = New-IconBitmap $size
  Save-Png $bitmap (Join-Path $macDir "app_icon_$size.png")
  $bitmap.Dispose()
}

$icoSizes = @(256, 128, 64, 48, 32, 24, 16)
$pngEntries = @()
foreach ($size in $icoSizes) {
  $bitmap = New-IconBitmap $size
  $stream = New-Object System.IO.MemoryStream
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngEntries += [PSCustomObject]@{ Size = $size; Bytes = $stream.ToArray() }
  $stream.Dispose()
  $bitmap.Dispose()
}

$out = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = New-Object System.IO.BinaryWriter $out
$writer.Write([UInt16]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]$pngEntries.Count)
$offset = 6 + ($pngEntries.Count * 16)
foreach ($entry in $pngEntries) {
  if ($entry.Size -eq 256) {
    $dimension = [byte]0
  } else {
    $dimension = [byte]$entry.Size
  }
  $writer.Write($dimension)
  $writer.Write($dimension)
  $writer.Write([byte]0)
  $writer.Write([byte]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]32)
  $writer.Write([UInt32]$entry.Bytes.Length)
  $writer.Write([UInt32]$offset)
  $offset += $entry.Bytes.Length
}
foreach ($entry in $pngEntries) {
  $writer.Write($entry.Bytes)
}
$writer.Dispose()
$out.Dispose()
