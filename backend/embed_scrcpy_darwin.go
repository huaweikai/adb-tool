//go:build darwin

package main

import "embed"

// scrcpyEmbedFS holds the bundled scrcpy distribution for the active platform.
//
// On macOS, BOTH architectures are bundled so the same binary works on:
//   - Apple Silicon (aarch64) — native
//   - Intel (x86_64)          — native + Rosetta fallback
//
// Source archives (kept in repo for reproducibility, not committed):
//   - binaries/scrcpy-macos-aarch64-v4.0.tar.gz (Genymobile/scrcpy v4.0)
//   - binaries/scrcpy-macos-x86_64-v4.0.tar.gz
//
// v4.0 renames scrcpy-server.jar → scrcpy-server (extensionless). This is
// intentional upstream — the file is still a Java archive and the server
// launcher (`app_process`) loads it via CLASSPATH regardless of name.
//
//go:embed binaries/scrcpy/darwin
var scrcpyEmbedFS embed.FS