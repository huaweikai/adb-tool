//go:build !darwin && !windows

package main

import _ "embed"

//go:embed platform-tools-latest-darwin.zip
var adbPlatformToolsZip []byte
