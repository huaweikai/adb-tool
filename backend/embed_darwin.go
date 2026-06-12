//go:build darwin

package main

import _ "embed"

//go:embed platform-tools-latest-darwin.zip
var adbPlatformToolsZip []byte
