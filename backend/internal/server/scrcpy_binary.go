package server

import (
	"embed"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"runtime"
)

// ScrcpyPaths holds the file locations of an extracted scrcpy distribution.
// All paths are absolute and ready to use.
type ScrcpyPaths struct {
	// Dir is the directory containing the scrcpy binary and its sibling
	// files (DLLs on Windows, scrcpy-server on all platforms). Pass this
	// as the cwd when spawning scrcpy so relative DLL lookup works.
	Dir string

	// Binary is the absolute path to the scrcpy executable itself.
	// On Windows this is scrcpy.exe; on macOS/Linux it's scrcpy.
	Binary string

	// ServerJar is the absolute path to the scrcpy-server file. v4.0
	// renamed it to be extensionless but it's still a Java archive —
	// scrcpy figures that out internally when it pushes the file.
	ServerJar string

	// Arch records which architecture bundle was selected (aarch64,
	// amd64, 386). Useful for diagnostics in log output.
	Arch string
}

// FindScrcpy returns the absolute paths to a usable scrcpy distribution.
// It extracts the bundled copy (from scrcpyEmbedFS in embed_scrcpy_*.go)
// on first call and caches it in the OS temp directory; subsequent calls
// are a no-op fast path.
//
// Returns an error if:
//   - runtime.GOOS is linux (no Linux bundle shipped)
//   - the embed is missing the expected layout
//   - extraction fails
func FindScrcpy(embedFS embed.FS) (*ScrcpyPaths, error) {
	if runtime.GOOS == "linux" {
		return nil, fmt.Errorf("scrcpy is not bundled for linux; install it and put it on PATH")
	}

	archDir, err := selectScrcpyArch(embedFS)
	if err != nil {
		return nil, err
	}

	binaryName := "scrcpy"
	if runtime.GOOS == "windows" {
		binaryName = "scrcpy.exe"
	}

	cacheDir := filepath.Join(os.TempDir(), "adb-tool-cache", "scrcpy", archDir)
	binaryPath := filepath.Join(cacheDir, binaryName)

	// Fast path: already extracted.
	if info, err := os.Stat(binaryPath); err == nil && !info.IsDir() {
		// Re-apply chmod on every call — temp dirs sometimes lose
		// the executable bit after extraction (especially on macOS
		// after an OS update invalidates quarantine attrs).
		_ = os.Chmod(binaryPath, 0755)
		return &ScrcpyPaths{
			Dir:       cacheDir,
			Binary:    binaryPath,
			ServerJar: filepath.Join(cacheDir, "scrcpy-server"),
			Arch:      archDir,
		}, nil
	}

	// Cold path: extract from embed. embed.FS always uses forward
	// slashes, so build the source prefix with path (not filepath,
	// which would emit backslashes on Windows and never match).
	if err := extractScrcpyDir(embedFS, path.Join("binaries", "scrcpy", runtime.GOOS, archDir), cacheDir); err != nil {
		return nil, fmt.Errorf("extract scrcpy (%s): %w", archDir, err)
	}

	if err := os.Chmod(binaryPath, 0755); err != nil {
		return nil, fmt.Errorf("chmod scrcpy binary: %w", err)
	}

	return &ScrcpyPaths{
		Dir:       cacheDir,
		Binary:    binaryPath,
		ServerJar: filepath.Join(cacheDir, "scrcpy-server"),
		Arch:      archDir,
	}, nil
}

// selectScrcpyArch picks the arch subdirectory matching runtime.GOARCH.
// If the matching arch is missing but an alternative exists (e.g. running
// an amd64 Go toolchain on Apple Silicon without the native aarch64 bundle),
// we fall back to whatever is available and log it via Arch.
func selectScrcpyArch(embedFS embed.FS) (string, error) {
	want := runtime.GOARCH
	candidates := []string{want}

	// Cross-arch fallback: amd64 binary can run via Rosetta on macOS,
	// and 386 binary can run on amd64 Windows. Prefer those over failing.
	switch want {
	case "arm64":
		candidates = append(candidates, "amd64")
	case "amd64":
		candidates = append(candidates, "386")
	}

	for _, arch := range candidates {
		prefix := path.Join("binaries", "scrcpy", runtime.GOOS, arch)
		if _, err := fs.Stat(embedFS, prefix); err == nil {
			return arch, nil
		}
	}

	return "", fmt.Errorf("no scrcpy bundle for %s/%s (looked for %v)", runtime.GOOS, runtime.GOARCH, candidates)
}

// extractScrcpyDir walks an embed.FS subtree rooted at srcPrefix and
// writes every file to dstDir, preserving relative paths. Empty
// directories in the embed are not recreated (no empty dirs in the
// shipped scrcpy bundles, so this is fine in practice).
func extractScrcpyDir(embedFS embed.FS, srcPrefix, dstDir string) error {
	if err := os.MkdirAll(dstDir, 0755); err != nil {
		return fmt.Errorf("mkdir %s: %w", dstDir, err)
	}

	return fs.WalkDir(embedFS, srcPrefix, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == srcPrefix {
			return nil
		}

		// embed.FS yields forward-slash paths; convert both sides to
		// native separators before computing the relative path so the
		// on-disk destination is correct on Windows too.
		rel, err := filepath.Rel(filepath.FromSlash(srcPrefix), filepath.FromSlash(path))
		if err != nil {
			return err
		}
		dst := filepath.Join(dstDir, rel)

		if d.IsDir() {
			return os.MkdirAll(dst, 0755)
		}

		return copyEmbedFile(embedFS, path, dst)
	})
}

func copyEmbedFile(embedFS embed.FS, src, dst string) error {
	in, err := embedFS.Open(src)
	if err != nil {
		return fmt.Errorf("open embed %s: %w", src, err)
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return fmt.Errorf("mkdir parent of %s: %w", dst, err)
	}

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("create %s: %w", dst, err)
	}

	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return fmt.Errorf("copy to %s: %w", dst, err)
	}
	return out.Close()
}