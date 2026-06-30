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

// lookupEnv returns the value for key in a "KEY=VALUE" env slice, mirroring
// os.LookupEnv for cmd.Env. We need this because cmd.Env is a slice, not
// the parent process map, so we can't call os.LookupEnv on it directly.
func lookupEnv(env []string, key string) (string, bool) {
	prefix := key + "="
	for _, kv := range env {
		if strings.HasPrefix(kv, prefix) {
			return kv[len(prefix):], true
		}
	}
	return "", false
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
//
// javaPath is the path to the Java executable the engine resolved (may be
// empty). When non-empty we derive JAVA_HOME and pass it to the sdkmanager
// subprocess so its wrapper script can locate Java even when the parent
// process's PATH is minimal — this is the GUI-launched case where macOS
// LaunchServices strips the user's shell PATH and sdkmanager's shebang
// resolution (or its `which java` fallback) would otherwise exit 127.
func (s *SDKInstaller) Start(sdkmanagerPath, sdkPath, javaPath string, packages []string) (*InstallJob, error) {
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

	go s.run(job, sdkmanagerPath, sdkPath, javaPath)
	return job, nil
}

// buildSDKManagerEnv assembles the environment that we hand to the
// sdkmanager subprocess. ANDROID_HOME / ANDROID_SDK_ROOT always point at
// the user-selected SDK so sdkmanager resolves the install target
// regardless of where the parent daemon was launched from. JAVA_HOME is
// derived from javaPath when available — sdkmanager is a shell wrapper
// that prefers $JAVA_HOME/bin/java over `which java`, and the `which`
// fallback fails on GUI-launched macOS apps whose PATH does not include
// a JDK.
//
// When javaPath is empty (engine couldn't resolve one) we still let the
// process run — sdkmanager will fall back to `which java` and succeed
// when the parent env happens to have one on PATH.
func buildSDKManagerEnv(sdkPath, javaPath string) []string {
	env := append(os.Environ(),
		"ANDROID_HOME="+sdkPath,
		"ANDROID_SDK_ROOT="+sdkPath,
	)
	if javaPath != "" {
		// javaPath is the path to the `java` executable, e.g.
		// /Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java
		// or /usr/bin/java. JAVA_HOME is the directory above `bin/`,
		// which is the parent of the parent.
		env = append(env, "JAVA_HOME="+filepath.Dir(filepath.Dir(javaPath)))
	}
	return env
}

func (s *SDKInstaller) run(job *InstallJob, sdkmanagerPath, sdkPath, javaPath string) {
	s.update(job, func() {
		job.Status = "running"
		job.StartedAt = time.Now()
		job.Message = fmt.Sprintf("Installing %s", strings.Join(job.Packages, ", "))
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Pre-accept the well-known Android SDK licenses. Without this, the
	// first-ever install on a fresh machine blocks forever at the
	// "Accept? (y/N):" prompt — even with our 'y'-pumping stdin
	// goroutine, the prompt blocks the JVM before the goroutine's first
	// 'y' can land (and on a TTY-less parent like our Flutter GUI child
	// the prompt hangs outright). Accepting the licenses on disk is the
	// same trick Android Studio / Flutter doctor use; see licenses.go.
	if err := acceptSDKLicenses(); err != nil {
		s.fail(job, fmt.Errorf("pre-accept licenses: %w", err))
		return
	}

	// Resolve classpath from the cmdline-tools we have on disk. We
	// bypass the sdkmanager shell wrapper entirely — that wrapper has
	// too many env / shebang / cwd / `which java` quirks to be a
	// reliable non-interactive spawn target (see the historical debug
	// log in PR #... — env exit 127, JAVA_HOME propagated-but-ignored,
	// silent hangs at cd "$(dirname "$0")", ...). Running java
	// ourselves with the canonical classpath avoids all of them.
	classpath, appHome, err := resolveSDKManagerClasspath(sdkmanagerPath)
	if err != nil || appHome == "" {
		s.fail(job, fmt.Errorf("resolve sdkmanager classpath: %w", err))
		return
	}

	// Effective Java path: prefer the one engine resolved, otherwise
	// fall back to "java" on PATH (we explicitly set JAVA_HOME so the
	// wrapper's "which java" fallback isn't needed).
	if javaPath == "" {
		s.fail(job, fmt.Errorf("no java path resolved; cannot launch sdkmanager"))
		return
	}
	if _, err := os.Stat(javaPath); err != nil {
		s.fail(job, fmt.Errorf("java path not found: %s: %w", javaPath, err))
		return
	}

	args := []string{
		"-Dcom.android.sdklib.toolsdir=" + appHome,
		"-classpath", classpath,
		"com.android.sdklib.tool.sdkmanager.SdkManagerCli",
		"--sdk_root=" + sdkPath,
	}
	args = append(args, job.Packages...)
	cmd := exec.CommandContext(ctx, javaPath, args...)
	cmd.Env = buildSDKManagerEnv(sdkPath, javaPath)

	log.Printf("[sdk-installer] spawn: java=%q args=%v sdkRoot=%q", javaPath, args, sdkPath)
	for _, kv := range cmd.Env {
		switch {
		case strings.HasPrefix(kv, "JAVA_HOME="),
			strings.HasPrefix(kv, "ANDROID_HOME="),
			strings.HasPrefix(kv, "ANDROID_SDK_ROOT="):
			log.Printf("[sdk-installer] env: %s", kv)
		}
	}

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

	// Pump "y\n" answers into the subprocess's stdin so any license prompt
	// we missed in our pre-accepted hash list still gets a "yes". This
	// covers future cmdline-tools versions whose license text rotates to
	// a new SHA-1 we haven't seen yet.
	//
	// Strictly speaking our acceptSDKLicenses() pre-write is the primary
	// acceptance mechanism (covers the well-known hashes we baked in).
	// The goroutine below is a belt-and-suspenders fallback for hashes
	// we don't yet know about — the UI's "Download" button counts as
	// informed consent for any license that turns up.
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

	if err := cmd.Start(); err != nil {
		s.fail(job, fmt.Errorf("start java: %w", err))
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
	if path := findSDKTool(sdkPath, "sdkmanager"); path != "" {
		return path
	}
	return filepath.Join(sdkPath, "cmdline-tools", "latest", "bin", "sdkmanager")
}
