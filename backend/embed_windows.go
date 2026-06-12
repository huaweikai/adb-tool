//go:build windows

package main

import _ "embed"

//go:embed platform-tools-latest-windows.zip
var adbPlatformToolsZip []byte
