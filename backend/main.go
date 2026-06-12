package main

import (
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

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

	httpServer := &http.Server{
		Addr:    ":9876",
		Handler: srv.Handler(),
	}

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	fmt.Println("[3/3] Server ready. Listening on :9876")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	fmt.Println("\nShutting down...")
	httpServer.Close()
}
