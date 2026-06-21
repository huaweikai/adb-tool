//go:build windows

package main

import "embed"

// scrcpyEmbedFS holds the bundled scrcpy distribution for Windows.
//
// Both 32-bit and 64-bit binaries are bundled so the same installer works
// on either architecture — runtime picks the matching one via runtime.GOARCH.
//
// Source archives (kept in repo for reproducibility, not committed):
//   - binaries/scrcpy-win32-v4.0.zip (Genymobile/scrcpy v4.0)
//   - binaries/scrcpy-win64-v4.0.zip
//
// Windows v4.0 ships scrcpy + its DLLs (SDL3, avcodec-62, avformat-62,
// avutil-60, swresample-6, libusb-1.0, AdbWinApi, AdbWinUsbApi) plus a
// renamed scrcpy-server (extensionless, still a JAR).
//
//go:embed binaries/scrcpy/windows
var scrcpyEmbedFS embed.FS