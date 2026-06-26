package emulator

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// InstallJob represents a running (or completed) sdkmanager install job.
//
// Progress is reported as a fraction in [0, 1] and is parsed out of
// sdkmanager's verbose stdout — sdkmanager emits lines like
// `[==========================] 100%` and per-file "Downloading" /
// "Installing" markers. We track only the most recent 20 output lines so
// the UI can show what happened if the job fails.
type InstallJob struct {
	ID         string     `json:"id"`
	Packages   []string   `json:"packages"`
	Status     string     `json:"status"` // pending, running, completed, error
	Progress   float64    `json:"progress"`
	Message    string     `json:"message"`
	OutputTail []string   `json:"outputTail,omitempty"`
	Error      string     `json:"error,omitempty"`
	StartedAt  time.Time  `json:"startedAt"`
	FinishedAt *time.Time `json:"finishedAt,omitempty"`
}

// SDKInstaller runs sdkmanager install commands asynchronously and exposes
// their progress to the UI. Multiple jobs can be active at once; each job
// is tracked by an ID returned from Start.
//
// When an imageManager is wired in via SetImageManager, every successful
// install re-scans the SDK's system-images directory and registers any new
// images into the persisted registry so they show up in the UI list without
// the user having to manually re-scan.
type SDKInstaller struct {
	mu       sync.RWMutex
	jobs     map[string]*InstallJob
	imageMgr *ImageManager // optional — see SetImageManager
}

// splitCRorLF is a bufio.SplitFunc that splits on either '\r' or '\n'.
//
// Why we need this: sdkmanager paints progress updates in place by emitting
// `\r[X...] NN% Activity...` and only flushes a real `\n` when the
// operation is done. The default bufio.Scanner uses ScanLines which only
// recognises `\n`, so the whole progress phase accumulates as one giant
// "line" and we never see updates. Splitting on `\r` (and the optional
// trailing `\n`) makes each paint arrive as its own token.
func splitCRorLF(data []byte, atEOF bool) (advance int, token []byte, err error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}
	for i, b := range data {
		if b == '\r' || b == '\n' {
			j := i + 1
			// Eat the LF half of a CRLF so we don't return an empty token.
			if b == '\r' && j < len(data) && data[j] == '\n' {
				j++
			}
			return j, data[:i], nil
		}
	}
	if atEOF {
		return len(data), data, nil
	}
	return 0, nil, nil
}

// streamLines reads from r, splits on either CR or LF, and feeds each
// non-empty line into handleLine. We bump the scanner buffer to 1 MiB
// because sdkmanager can pack multiple paint updates back-to-back without
// a `\n`, and the default 64 KiB would clip them.
func streamLines(r io.Reader, handleLine func(string)) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	scanner.Split(splitCRorLF)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			handleLine(line)
		}
	}
}

// NewSDKInstaller creates a new SDKInstaller.
func NewSDKInstaller() *SDKInstaller {
	return &SDKInstaller{jobs: make(map[string]*InstallJob)}
}

// SetImageManager wires in the image manager used to register newly
// installed system images once a job completes. Safe to call before or
// after jobs are in flight — the installer reads imageMgr at scan time.
func (s *SDKInstaller) SetImageManager(mgr *ImageManager) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.imageMgr = mgr
}

// percentRegex matches the percentage in sdkmanager's progress lines
// (e.g. "[==========================]  70%  3.2 MB/s" -> "70").
var percentRegex = regexp.MustCompile(`(\d{1,3})\s*%`)

// Start launches an install job. Returns the job immediately; the actual
// sdkmanager process runs in a goroutine.
func (s *SDKInstaller) Start(sdkmanagerPath, sdkPath string, packages []string) (*InstallJob, error) {
	if _, err := os.Stat(sdkmanagerPath); err != nil {
		return nil, fmt.Errorf("sdkmanager not found at %s: %w", sdkmanagerPath, err)
	}
	if sdkPath == "" {
		return nil, fmt.Errorf("sdk path is required")
	}
	if len(packages) == 0 {
		return nil, fmt.Errorf("at least one package is required")
	}

	job := &InstallJob{
		ID:       "install-" + uuid.New().String()[:8],
		Packages: packages,
		Status:   "pending",
	}

	s.mu.Lock()
	s.jobs[job.ID] = job
	s.mu.Unlock()

	go s.run(job, sdkmanagerPath, sdkPath)
	return job, nil
}

func (s *SDKInstaller) run(job *InstallJob, sdkmanagerPath, sdkPath string) {
	s.update(job, func() {
		job.Status = "running"
		job.StartedAt = time.Now()
		job.Message = fmt.Sprintf("Installing %s", strings.Join(job.Packages, ", "))
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// sdkmanager requires license acceptance before installing. It prompts
	// once per license and waits for a 'y' on stdin — so we pump answers
	// in a goroutine, with a small delay between each, until the process
	// exits. The user has explicitly pressed "download" in the UI, which
	// counts as informed consent for the SDK licenses.
	args := append([]string{"--sdk_root=" + sdkPath}, job.Packages...)
	cmd := exec.CommandContext(ctx, sdkmanagerPath, args...)
	cmd.Env = append(os.Environ(),
		"ANDROID_HOME="+sdkPath,
		"ANDROID_SDK_ROOT="+sdkPath,
	)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		s.fail(job, fmt.Errorf("stdin pipe: %w", err))
		return
	}
	go func() {
		defer stdin.Close()
		ticker := time.NewTicker(200 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if _, err := stdin.Write([]byte("y\n")); err != nil {
					return
				}
			}
		}
	}()

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		s.fail(job, fmt.Errorf("stdout pipe: %w", err))
		return
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		s.fail(job, fmt.Errorf("stderr pipe: %w", err))
		return
	}

if err := cmd.Start(); err != nil {
		s.fail(job, fmt.Errorf("start sdkmanager: %w", err))
		return
	}

	// Stream stdout + stderr line by line. sdkmanager is chatty: every
	// download/install operation prints a marker line and progress updates
	// show up as `[====...]  NN%`. We keep only the last 20 lines so the
	// UI can show what happened.
	var (
		tailMu sync.Mutex
		tail   []string
	)
	consume := func(line string) {
		tailMu.Lock()
		tail = append(tail, line)
		if len(tail) > 20 {
			tail = tail[len(tail)-20:]
		}
		snapshot := append([]string{}, tail...)
		tailMu.Unlock()

		s.update(job, func() {
			job.OutputTail = snapshot
			if m := percentRegex.FindStringSubmatch(line); len(m) == 2 {
				var pct float64
				fmt.Sscanf(m[1], "%f", &pct)
				if pct < 0 {
					pct = 0
				} else if pct > 100 {
					pct = 100
				}
				p := pct / 100
				// Only advance — sdkmanager sometimes prints
				// per-file percentages that can go backwards when
				// it moves on to the next file.
				if p > job.Progress {
					job.Progress = p
				}
			}
			// Surface human-readable activity lines.
			switch {
			case strings.HasPrefix(line, "Downloading "):
				job.Message = line
			case strings.HasPrefix(line, "Installing "):
				job.Message = strings.TrimPrefix(line, "Installing ")
			case strings.HasPrefix(line, "Unzipping "):
				job.Message = strings.TrimPrefix(line, "Unzipping ")
			}
		})
	}

	go streamLines(stdout, consume)
	go streamLines(stderr, consume)

	if err := cmd.Wait(); err != nil {
		s.fail(job, fmt.Errorf("sdkmanager exited with error: %w", err))
		// Even on failure, sdkmanager may have partially unpacked some
		// images — try to register whatever landed on disk so the user
		// doesn't have to retry a full rescan.
		s.scanInstalledImages(sdkPath)
		return
	}

	now := time.Now()
	s.update(job, func() {
		job.Status = "completed"
		job.Progress = 1.0
		job.Message = "Installation complete"
		job.FinishedAt = &now
	})

	// Once the install succeeds, sdkmanager has written the image into
	// <sdkPath>/system-images/<android-XX>/<variant>/<arch>/. The frontend
	// only lists images that are in the persisted registry, so re-scan
	// that directory and pick up the new entries.
	s.scanInstalledImages(sdkPath)
}

// scanInstalledImages re-registers everything currently on disk under
// <sdkPath>/system-images so a fresh sdkmanager install shows up in the
// image list without a manual rescan. Best-effort: any scan failure is
// logged but doesn't fail the job.
func (s *SDKInstaller) scanInstalledImages(sdkPath string) {
	s.mu.RLock()
	mgr := s.imageMgr
	s.mu.RUnlock()
	if mgr == nil || sdkPath == "" {
		return
	}
	sysImagesDir := filepath.Join(sdkPath, "system-images")
	if _, err := os.Stat(sysImagesDir); err != nil {
		// No system-images dir at all yet — nothing to scan.
		return
	}
	n, err := mgr.ScanAndRegister(sysImagesDir)
	if err != nil {
		log.Printf("[sdk-installer] post-install scan of %s failed: %v", sysImagesDir, err)
		return
	}
	log.Printf("[sdk-installer] post-install scan registered %d image(s) under %s", n, sysImagesDir)
}

func (s *SDKInstaller) fail(job *InstallJob, err error) {
	now := time.Now()
	s.update(job, func() {
		job.Status = "error"
		job.Error = err.Error()
		job.FinishedAt = &now
	})
	log.Printf("[sdk-installer] job %s failed: %v", job.ID, err)
}

func (s *SDKInstaller) update(job *InstallJob, fn func()) {
	s.mu.Lock()
	defer s.mu.Unlock()
	fn()
}

// Get returns the job with the given ID, or nil if it doesn't exist.
func (s *SDKInstaller) Get(id string) *InstallJob {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.jobs[id]
}

// List returns all jobs (oldest first).
func (s *SDKInstaller) List() []*InstallJob {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]*InstallJob, 0, len(s.jobs))
	for _, j := range s.jobs {
		out = append(out, j)
	}
	return out
}

// DefaultSDKManagerPath returns the conventional sdkmanager path under the
// given SDK root. Used when the engine hasn't been initialized yet.
func DefaultSDKManagerPath(sdkPath string) string {
	p := filepath.Join(sdkPath, "cmdline-tools", "latest", "bin", "sdkmanager")
	if _, err := os.Stat(p); err == nil {
		return p
	}
	return filepath.Join(sdkPath, "tools", "bin", "sdkmanager")
}