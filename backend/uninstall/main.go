//go:build windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"unsafe"
)

const upgradeCode = "{7EEE1BBA-2B37-408A-9C03-D6E670D2EB8F}"

const (
	errorSuccess     = 0
	errorNoMoreItems = 259
)

func main() {
	productCode, err := findProductCode()
	if err != nil {
		alert("Installed product was not found.\n" + err.Error())
		return
	}

	cmd := exec.Command("msiexec.exe", "/x", productCode)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: false}
	if err := cmd.Start(); err != nil {
		alert("Failed to start uninstaller:\n" + err.Error())
		return
	}
}

func findProductCode() (string, error) {
	msi := syscall.NewLazyDLL("msi.dll")
	proc := msi.NewProc("MsiEnumRelatedProductsW")
	upgrade, err := syscall.UTF16PtrFromString(upgradeCode)
	if err != nil {
		return "", err
	}

	buf := make([]uint16, 39)
	ret, _, _ := proc.Call(
		uintptr(unsafe.Pointer(upgrade)),
		0,
		0,
		uintptr(unsafe.Pointer(&buf[0])),
	)

	switch uint32(ret) {
	case errorSuccess:
		return syscall.UTF16ToString(buf), nil
	case errorNoMoreItems:
		return "", fmt.Errorf("no installed MSI product matches upgrade code %s", upgradeCode)
	default:
		return "", fmt.Errorf("MsiEnumRelatedProductsW failed with code %d", ret)
	}
}

func alert(msg string) {
	title, _ := syscall.UTF16PtrFromString("ADB Tool")
	body, _ := syscall.UTF16PtrFromString(msg)
	user32 := syscall.NewLazyDLL("user32.dll")
	msgBox := user32.NewProc("MessageBoxW")
	msgBox.Call(0, uintptr(unsafe.Pointer(body)), uintptr(unsafe.Pointer(title)), 0x30)
	fmt.Fprintln(os.Stderr, msg)
}
