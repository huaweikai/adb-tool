package emulator

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// RegisteredImage is a system image entry persisted in the registry. It stores
// the real on-disk path of an image so we never have to re-scan the whole SDK
// on every list call — we just validate the stored paths.
type RegisteredImage struct {
	ID             string `json:"id"`
	Name           string `json:"name"`
	Path           string `json:"path"`
	APILevel       int    `json:"apiLevel"`
	AndroidVersion string `json:"androidVersion"`
	Arch           string `json:"arch"`
	Variant        string `json:"variant"`
	AddedAt        string `json:"addedAt"`
	Valid          bool   `json:"valid"`
}

var imageRegistryMu sync.Mutex

// imageRegistryPath returns the path of the persisted image registry file.
func imageRegistryPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "images.json")
}

// LoadRegisteredImages returns the persisted registry entries.
func LoadRegisteredImages() []RegisteredImage {
	imageRegistryMu.Lock()
	defer imageRegistryMu.Unlock()
	return loadRegisteredImagesLocked()
}

func loadRegisteredImagesLocked() []RegisteredImage {
	data, err := os.ReadFile(imageRegistryPath())
	if err != nil {
		return []RegisteredImage{}
	}
	var images []RegisteredImage
	if err := json.Unmarshal(data, &images); err != nil {
		return []RegisteredImage{}
	}
	return images
}

func saveRegisteredImagesLocked(images []RegisteredImage) error {
	cfgPath := imageRegistryPath()
	if err := os.MkdirAll(filepath.Dir(cfgPath), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(images, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(cfgPath, data, 0644)
}

// registerImagesLocked appends the given images to the registry, deduplicating
// by on-disk path. Returns the merged list.
func registerImagesLocked(newOnes []RegisteredImage) []RegisteredImage {
	existing := loadRegisteredImagesLocked()
	seen := make(map[string]int, len(existing))
	for i, e := range existing {
		seen[normalizePath(e.Path)] = i
	}
	for _, n := range newOnes {
		key := normalizePath(n.Path)
		if idx, ok := seen[key]; ok {
			// Refresh metadata of the existing entry in place.
			existing[idx] = n
			continue
		}
		existing = append(existing, n)
		seen[key] = len(existing) - 1
	}
	return existing
}

func normalizePath(p string) string {
	return strings.ToLower(filepath.Clean(p))
}

// imagePathValid reports whether a registered image path still holds a usable
// image (i.e. system.img is present).
func imagePathValid(path string) bool {
	if path == "" {
		return false
	}
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return false
	}
	if _, err := os.Stat(filepath.Join(path, "system.img")); err == nil {
		return true
	}
	// Some images keep system.img inside subfolders; fall back to a shallow scan.
	entries, err := os.ReadDir(path)
	if err != nil {
		return false
	}
	for _, e := range entries {
		if !e.IsDir() && strings.HasPrefix(e.Name(), "system.img") {
			return true
		}
	}
	return false
}

// ValidateRegisteredImages re-checks every registered path, updates the Valid
// flag, persists the result, and returns the refreshed list.
func ValidateRegisteredImages() []RegisteredImage {
	imageRegistryMu.Lock()
	defer imageRegistryMu.Unlock()

	images := loadRegisteredImagesLocked()
	changed := false
	for i := range images {
		valid := imagePathValid(images[i].Path)
		if images[i].Valid != valid {
			log.Printf("[image] validate: %s valid %v -> %v (path=%s)", images[i].ID, images[i].Valid, valid, images[i].Path)
			images[i].Valid = valid
			changed = true
		}
	}
	if changed {
		_ = saveRegisteredImagesLocked(images)
	}
	return images
}

// StartImageRegistryValidator launches a background goroutine that periodically
// validates the registered image paths until the returned stop channel is
// closed.
func StartImageRegistryValidator(interval time.Duration) chan struct{} {
	stop := make(chan struct{})
	go func() {
		// Validate once on startup.
		ValidateRegisteredImages()
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				ValidateRegisteredImages()
			}
		}
	}()
	return stop
}
