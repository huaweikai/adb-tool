//go:build !darwin && !windows

package main

import "embed"

// Linux is not officially supported by the bundled scrcpy distribution
// (the user did not provide Linux archives). On non-darwin/non-windows
// builds, embed the macOS bundle as a best-effort fallback so the binary
// still compiles. At runtime FindScrcpy will return an error if GOOS=linux.
//
//go:embed binaries/scrcpy/darwin
var scrcpyEmbedFS embed.FS