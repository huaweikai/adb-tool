package server

import (
	"embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

// TODO: re-enable after fixing Windows batch fake adb stubbing.
func TestScreenRecordStartsWithPlainAdbScreenrecord(t *testing.T) {
	adbPath := writePlainScreenRecordFakeAdb(t)
	logPath := filepath.Join(t.TempDir(), "adb.log")
	t.Setenv("ADB_FAKE_LOG", logPath)

	manager := NewAdbManager(adbPath, embed.FS{})
	if err := manager.StartScreenRecord("serial-1"); err != nil {
		t.Fatalf("StartScreenRecord returned error: %v", err)
	}
	waitForLogContains(t, logPath, "-s serial-1 shell screenrecord /sdcard/adb-tool-record.mp4")
	if err := manager.StopScreenRecord("serial-1"); err != nil {
		logBytes, _ := os.ReadFile(logPath)
		t.Fatalf("StopScreenRecord returned error: %v\nLog:\n%s", err, string(logBytes))
	}

	logBytes, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read fake adb log: %v", err)
	}
	log := string(logBytes)
	if !strings.Contains(log, "-s serial-1 shell screenrecord /sdcard/adb-tool-record.mp4") {
		t.Fatalf("expected plain screenrecord command, log:\n%s", log)
	}
	for _, unexpected := range []string{"adb-tool-stop", "adb-tool-record.pid", "SRPID", "while !", "pkill", "killall"} {
		if strings.Contains(log, unexpected) {
			t.Fatalf("unexpected %q in screenrecord flow, log:\n%s", unexpected, log)
		}
	}
}

func waitForLogContains(t *testing.T, path string, want string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		data, _ := os.ReadFile(path)
		if strings.Contains(string(data), want) {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	data, _ := os.ReadFile(path)
	t.Fatalf("log did not contain %q, log:\n%s", want, data)
}

// writePlainScreenRecordFakeAdb creates a self-contained fake adb program.
//
// Strategy: We compile a Go program to a real executable (not a script).
// On Windows, the batch wrapper calls this exe. On Unix, it's a shell script.
// This avoids all Windows batch quoting/escaping problems (% in stat -c %s, etc.)
// that plague batch-based fakes.
func writePlainScreenRecordFakeAdb(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()

	fakeSrc := `package main

import (
	"os"
	"strings"
)

func main() {
	// Always flush output before exiting.
	os.Stdout.Sync()

	if len(os.Args) < 2 {
		os.Exit(1)
	}
	args := os.Args[1:]

	// Log invocations.
	if log := os.Getenv("ADB_FAKE_LOG"); log != "" {
		if f, err := os.OpenFile(log, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644); err == nil {
			f.WriteString(strings.Join(args, " ") + "\n")
			f.Close()
		}
	}

	// Route: -s SERIAL shell <cmd>
	if len(args) >= 4 && args[0] == "-s" && args[2] == "shell" {
		cmd, rest := args[3], args[4:]
		switch cmd {
		case "rm", "settings", "screenrecord", "sync":
			os.Exit(0)
		case "sh":
			if len(rest) >= 2 {
				payload := rest[1]
				switch {
				case strings.Contains(payload, "pgrep") || strings.Contains(payload, "pidof"):
					os.Stdout.WriteString("12345\n")
				case strings.Contains(payload, "kill"):
					// succeed silently
				default:
					os.Stdout.WriteString("1024\n") // stat / ls -l / wc -c → fake size
				}
			}
			os.Exit(0)
		}
	}
	os.Exit(1)
}
`

	// Compile Go source → real executable in temp dir.
	srcPath := filepath.Join(dir, "fake_adb.go")
	if err := os.WriteFile(srcPath, []byte(fakeSrc), 0644); err != nil {
		t.Fatalf("write fake adb source: %v", err)
	}
	binName := "adb"
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	binPath := filepath.Join(dir, binName)
	buildResult := exec.Command("go", "build", "-o", binPath, srcPath)
	if bOut, err := buildResult.CombinedOutput(); err != nil {
		t.Fatalf("compile fake adb: %v\nOutput: %s", err, string(bOut))
	}
	os.Chmod(binPath, 0755)

	if runtime.GOOS == "windows" {
		// Write a batch wrapper that calls the compiled exe.
		// Quotes in the exe path are preserved with %q.
		batPath := filepath.Join(dir, "adb.bat")
		bat := fmt.Sprintf("@echo off\n%q %s\n", binPath, "%*")
		if err := os.WriteFile(batPath, []byte(bat), 0755); err != nil {
			t.Fatalf("write fake adb .bat: %v", err)
		}
		return batPath
	}
	return binPath
}
