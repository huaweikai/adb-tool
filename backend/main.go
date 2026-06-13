package main

import (
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"adb-tool/backend/internal/server"
)

//go:embed web
var webFS embed.FS

func main() {
	fmt.Println("[1/3] Extracting ADB platform-tools...")
	adbPath, err := server.FindOrExtractADB(adbPlatformToolsZip)
	if err != nil {
		log.Fatalf("Failed to extract ADB: %v", err)
	}
	fmt.Printf("       ADB ready at: %s\n", adbPath)

	fmt.Println("[2/3] Starting HTTP server on :9876...")
	srv := server.New(adbPath, webFS, clipboardHelperApk)
	shutdownCh := make(chan struct{})
	var shutdownOnce sync.Once
	requestShutdown := func() {
		shutdownOnce.Do(func() {
			close(shutdownCh)
		})
	}
	srv.SetShutdownFunc(requestShutdown)

	httpServer := &http.Server{
		Addr:    ":9876",
		Handler: srv.Handler(),
	}

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("Server error: %v", err)
			requestShutdown()
		}
	}()

	fmt.Println("[3/3] Server ready. Listening on :9876")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		requestShutdown()
	}()
	watchParentProcess(requestShutdown)

	<-shutdownCh

	fmt.Println("\nShutting down...")
	srv.Close()
	if err := httpServer.Close(); err != nil && err != http.ErrServerClosed {
		log.Printf("HTTP server close error: %v", err)
	}
}

func watchParentProcess(onExit func()) {
	parentPidText := os.Getenv("ADB_TOOL_PARENT_PID")
	if parentPidText == "" {
		return
	}
	parentPid, err := strconv.Atoi(parentPidText)
	if err != nil || parentPid <= 0 {
		return
	}
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for range ticker.C {
			if !isProcessAlive(parentPid) {
				onExit()
				return
			}
		}
	}()
}

func isProcessAlive(pid int) bool {
	if runtime.GOOS == "windows" {
		out, err := exec.Command("tasklist", "/FI", fmt.Sprintf("PID eq %d", pid), "/FO", "CSV", "/NH").Output()
		if err != nil {
			return false
		}
		return strings.Contains(string(out), fmt.Sprintf("\"%d\"", pid))
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return process.Signal(syscall.Signal(0)) == nil
}
