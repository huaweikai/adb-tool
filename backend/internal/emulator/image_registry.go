package emulator

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type ImageDeleteMode string

const (
	ImageDeleteModeFilesRemoved ImageDeleteMode = "filesRemoved"
	ImageDeleteModeRegistryOnly ImageDeleteMode = "registryOnly"
)

type RegisteredImage struct {
	ID             string          `json:"id"`
	Name           string          `json:"name"`
	Path           string          `json:"path"`
	APILevel       int             `json:"apiLevel"`
	AndroidVersion string          `json:"androidVersion"`
	Arch           string          `json:"arch"`
	Variant        string          `json:"variant"`
	AddedAt        string          `json:"addedAt"`
	Valid          bool            `json:"valid"`
	Managed        bool            `json:"managed"`
	DeleteMode     ImageDeleteMode `json:"-"`
}

var imageRegistryMu sync.Mutex

// InUseCheck is invoked by DeleteRegisteredImage to ask the caller whether a
// given image ID is still referenced by any AVD instance. It returns the
// names of those instances. An empty result means "safe to delete". Pass nil
// to DeleteRegisteredImage to skip the check (e.g. from tests or admin
// tooling that doesn't care about instance linkage).
type InUseCheck func(imageID string) []string

// ImageInUseError is returned by DeleteRegisteredImage when the in-use check
// reports one or more AVD instances still pointing at this image. Surfacing
// it as a typed error lets the HTTP handler distinguish it from generic
// filesystem failures and respond with a 409 plus the instance names.
type ImageInUseError struct {
	ImageID string
	UsedBy  []string
}

func (e *ImageInUseError) Error() string {
	return fmt.Sprintf("image %q is in use by %d instance(s): %v", e.ImageID, len(e.UsedBy), e.UsedBy)
}

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
	for i := range images {
		images[i].Managed = isManagedImagePath(images[i].Path)
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

func managedImageRoot() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "system-images")
}

// managedImageRoots returns every root under ~/.adb-tool that ImageManager
// itself manages and may safely delete from. Scan paths must stay in sync
// with this list — otherwise an image gets scanned in, but DeleteRegistered
// falls back to "registry only" because it doesn't recognise the path as
// ours. Currently:
//   - ~/.adb-tool/emulator/system-images (legacy / default StorageDir)
//   - ~/.adb-tool/sdk/system-images       (managed Android SDK installed by us)
func managedImageRoots() []string {
	home, _ := os.UserHomeDir()
	return []string{
		filepath.Join(home, ".adb-tool", "emulator", "system-images"),
		filepath.Join(home, ".adb-tool", "sdk", "system-images"),
	}
}

func IsManagedImagePath(path string) bool {
	return isManagedImagePath(path)
}

func isManagedImagePath(path string) bool {
	if path == "" {
		return false
	}
	target, err := filepath.Abs(path)
	if err != nil {
		target = path
	}
	for _, root := range managedImageRoots() {
		rootAbs, err := filepath.Abs(root)
		if err != nil {
			rootAbs = root
		}
		rel, err := filepath.Rel(rootAbs, target)
		if err != nil {
			continue
		}
		if rel == "." || (rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator))) {
			return true
		}
	}
	return false
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

func DeleteRegisteredImage(id string, inUseCheck InUseCheck) (RegisteredImage, error) {
	imageRegistryMu.Lock()
	defer imageRegistryMu.Unlock()

	images := loadRegisteredImagesLocked()
	idx := -1
	var target RegisteredImage
	for i, img := range images {
		if img.ID == id {
			idx = i
			target = img
			break
		}
	}
	if idx < 0 {
		return RegisteredImage{}, fmt.Errorf("image not found: %s", id)
	}

	if inUseCheck != nil {
		if users := inUseCheck(id); len(users) > 0 {
			log.Printf("[image] delete: id=%s blocked: in use by %d instance(s): %v", id, len(users), users)
			return RegisteredImage{}, &ImageInUseError{ImageID: id, UsedBy: users}
		}
	}

	target.DeleteMode = ImageDeleteModeRegistryOnly
	if target.Managed && target.Path != "" {
		if err := os.RemoveAll(target.Path); err != nil {
			log.Printf("[image] delete: os.RemoveAll(%q) failed: %v (still dropping from registry)", target.Path, err)
		} else {
			target.DeleteMode = ImageDeleteModeFilesRemoved
		}
	}

	images = append(images[:idx], images[idx+1:]...)
	if err := saveRegisteredImagesLocked(images); err != nil {
		return target, fmt.Errorf("removed from registry but failed to persist registry: %w", err)
	}
	log.Printf("[image] delete: id=%s path=%s mode=%s", id, target.Path, target.DeleteMode)
	return target, nil
}
