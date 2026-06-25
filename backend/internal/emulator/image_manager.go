package emulator

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// SystemImage represents an Android system image.
type SystemImage struct {
	ID         string            `json:"id"`
	Name       string            `json:"name"`
	APILevel   int               `json:"apiLevel"`
	AndroidVersion string        `json:"androidVersion"`
	Arch       string            `json:"arch"`
	Variant    string            `json:"variant"` // google_apis, google_apis_playstore, default
	LocalPath  string           `json:"localPath"`
	Files      map[string]string `json:"files"` // file name -> relative path
	FileSize   int64             `json:"fileSize"`
	Status     string            `json:"status"` // pending, downloading, ready, error
	DownloadURL string          `json:"downloadUrl,omitempty"`
	SHA256     string            `json:"sha256,omitempty"`
}

// ImageManager manages Android system images.
type ImageManager struct {
	AndroidHome string
	StorageDir   string
}

// NewImageManager creates a new image manager.
func NewImageManager(androidHome string) *ImageManager {
	home, _ := os.UserHomeDir()
	storageDir := filepath.Join(home, ".adb-tool", "emulator", "system-images")

	// If androidHome is provided, use it for reading existing images
	if androidHome != "" {
		return &ImageManager{
			AndroidHome: androidHome,
			StorageDir:  storageDir,
		}
	}

	return &ImageManager{
		StorageDir: storageDir,
	}
}

// ListImages returns all images from the persisted registry, validating each
// path on the fly. It no longer re-scans the whole SDK on every call; instead
// images are discovered once via ScanAndRegister and remembered in images.json.
func (im *ImageManager) ListImages() []*SystemImage {
	registry := ValidateRegisteredImages()
	log.Printf("[image] ListImages: registry has %d entry(ies)", len(registry))

	images := make([]*SystemImage, 0, len(registry))
	for _, r := range registry {
		status := "ready"
		var files map[string]string
		var size int64
		if r.Valid {
			files = im.scanImageFiles(r.Path)
			size = im.calculateTotalSize(r.Path)
		} else {
			status = "error"
		}
		log.Printf("[image] ListImages:   id=%s valid=%v status=%s path=%s", r.ID, r.Valid, status, r.Path)
		images = append(images, &SystemImage{
			ID:             r.ID,
			Name:           r.Name,
			APILevel:       r.APILevel,
			AndroidVersion: r.AndroidVersion,
			Arch:           r.Arch,
			Variant:        r.Variant,
			LocalPath:      r.Path,
			Files:          files,
			FileSize:       size,
			Status:         status,
		})
	}

	return images
}

// scanImagesFromDir scans a directory tree for system images, returning them as
// SystemImage values (without persisting). It accepts an SDK root (containing a
// system-images subfolder), a system-images directory itself, or a single image
// directory.
func (im *ImageManager) scanImagesFromDir(root string) []*SystemImage {
	found := []*SystemImage{}

	// Case 1: root contains a "system-images" subfolder (SDK root).
	sysImagesDir := filepath.Join(root, "system-images")
	if info, err := os.Stat(sysImagesDir); err == nil && info.IsDir() {
		found = append(found, im.scanSystemImagesDir(sysImagesDir)...)
	}

	// Case 2: root IS a system-images directory (android-XX/variant/arch).
	found = append(found, im.scanSystemImagesDir(root)...)

	// Case 3: root is a single image directory (contains system.img).
	if len(found) == 0 {
		if parsed, err := im.ParseLocalImage(root); err == nil && len(parsed.Files) > 0 {
			found = append(found, parsed)
		}
	}

	return found
}

// ScanAndRegister scans the given path for system images and registers each
// discovered image's own concrete on-disk path into the persisted registry
// (deduplicated by path). For example, scanning "A" that contains three images
// stores the three real paths like "A/android-29/default/x86" — not "A" itself.
// Subsequent launches just validate these stored paths. Returns the number of
// images discovered in this scan.
func (im *ImageManager) ScanAndRegister(path string) (int, error) {
	log.Printf("[image] ScanAndRegister: scanning path=%s", path)
	scanned := im.scanImagesFromDir(path)
	log.Printf("[image] ScanAndRegister: found %d image(s) under %s", len(scanned), path)

	now := time.Now().Format(time.RFC3339)
	regImages := make([]RegisteredImage, 0, len(scanned))
	for _, s := range scanned {
		valid := imagePathValid(s.LocalPath)
		log.Printf("[image] ScanAndRegister:   register id=%s valid=%v path=%s", s.ID, valid, s.LocalPath)
		regImages = append(regImages, RegisteredImage{
			ID:             s.ID,
			Name:           s.Name,
			Path:           s.LocalPath,
			APILevel:       s.APILevel,
			AndroidVersion: s.AndroidVersion,
			Arch:           s.Arch,
			Variant:        s.Variant,
			AddedAt:        now,
			Valid:          valid,
		})
	}

	imageRegistryMu.Lock()
	defer imageRegistryMu.Unlock()
	merged := registerImagesLocked(regImages)
	if err := saveRegisteredImagesLocked(merged); err != nil {
		log.Printf("[image] ScanAndRegister: save failed: %v", err)
		return 0, err
	}
	log.Printf("[image] ScanAndRegister: registry now has %d entry(ies) total", len(merged))
	return len(scanned), nil
}

// scanSystemImagesDir scans a directory for system images.
func (im *ImageManager) scanSystemImagesDir(baseDir string) []*SystemImage {
	images := []*SystemImage{}

	entries, err := os.ReadDir(baseDir)
	if err != nil {
		return images
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		apiLevelDir := entry.Name() // e.g., "android-34"
		apiLevel := im.parseAPILevel(apiLevelDir)

		variantDir := filepath.Join(baseDir, entry.Name())
		variants, _ := os.ReadDir(variantDir)
		for _, variant := range variants {
			if !variant.IsDir() {
				continue
			}

			archDir := filepath.Join(variantDir, variant.Name())
			archs, _ := os.ReadDir(archDir)
			for _, arch := range archs {
				if !arch.IsDir() {
					continue
				}

				imagePath := filepath.Join(archDir, arch.Name())
				files := im.scanImageFiles(imagePath)
				totalSize := im.calculateTotalSize(imagePath)

				images = append(images, &SystemImage{
					ID:            im.buildImageID(apiLevelDir, variant.Name(), arch.Name()),
					Name:          fmt.Sprintf("Android %d (%s, %s)", apiLevel, variant.Name(), arch.Name()),
					APILevel:      apiLevel,
					AndroidVersion: im.apiLevelToVersion(apiLevel),
					Arch:          arch.Name(),
					Variant:       variant.Name(),
					LocalPath:     imagePath,
					Files:         files,
					FileSize:      totalSize,
					Status:        "ready",
				})
			}
		}
	}

	return images
}

// scanImageFiles scans an image directory for required files.
func (im *ImageManager) scanImageFiles(imageDir string) map[string]string {
	files := map[string]string{}
	requiredFiles := []string{"system.img", "userdata.img", "ramdisk.img"}

	entries, err := os.ReadDir(imageDir)
	if err != nil {
		return files
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		for _, required := range requiredFiles {
			if name == required || strings.HasPrefix(name, required) {
				files[name] = filepath.Join(imageDir, name)
			}
		}
		// Also check for kernel
		if strings.Contains(name, "kernel") {
			files["kernel"] = filepath.Join(imageDir, name)
		}
	}

	return files
}

// calculateTotalSize calculates total size of all files in an image directory.
func (im *ImageManager) calculateTotalSize(imageDir string) int64 {
	var total int64

	entries, err := os.ReadDir(imageDir)
	if err != nil {
		return 0
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		info, err := entry.Info()
		if err == nil {
			total += info.Size()
		}
	}

	return total
}

// parseAPILevel extracts API level from directory name (e.g., "android-34" -> 34).
func (im *ImageManager) parseAPILevel(dirName string) int {
	parts := strings.Split(dirName, "-")
	if len(parts) < 2 {
		return 0
	}
	var level int
	fmt.Sscanf(parts[len(parts)-1], "%d", &level)
	return level
}

// apiLevelToVersion converts API level to Android version string.
func (im *ImageManager) apiLevelToVersion(apiLevel int) string {
	versions := map[int]string{
		21: "5.0",
		22: "5.1",
		23: "6.0",
		24: "7.0",
		25: "7.1",
		26: "8.0",
		27: "8.1",
		28: "9.0",
		29: "10.0",
		30: "11.0",
		31: "12.0",
		32: "12.1",
		33: "13.0",
		34: "14.0",
		35: "15.0",
	}
	if v, ok := versions[apiLevel]; ok {
		return v
	}
	return fmt.Sprintf("%d.0", apiLevel-23) // rough estimate
}

// buildImageID builds a unique ID for an image.
func (im *ImageManager) buildImageID(apiLevel, variant, arch string) string {
	return fmt.Sprintf("%s-%s-%s", apiLevel, variant, arch)
}

// GetImage returns a specific image by ID.
func (im *ImageManager) GetImage(id string) *SystemImage {
	images := im.ListImages()
	for _, img := range images {
		if img.ID == id {
			return img
		}
	}
	return nil
}

// ParseLocalImage parses an image from a local directory.
func (im *ImageManager) ParseLocalImage(localPath string) (*SystemImage, error) {
	info, err := os.Stat(localPath)
	if err != nil {
		return nil, fmt.Errorf("path does not exist: %w", err)
	}

	if !info.IsDir() {
		return nil, fmt.Errorf("path is not a directory")
	}

	// Read config.ini / source.properties for metadata.
	config := im.parseConfigIni(localPath)

	// Accept the keys actually emitted by the Android SDK as well as a couple
	// of friendlier aliases — different tooling uses different conventions.
	apiLevel := firstNonEmpty(
		config["sdk"],
		config["sdk.version"],
		config["AndroidVersion.ApiLevel"],
	)
	if apiLevel == "" {
		// Last resort: pull a "android-XX" segment out of the directory path.
		apiLevel = im.inferAPILevelFromPath(localPath)
	}
	arch := firstNonEmpty(
		config["abi"],
		config["abi.type"],
		config["Arch"],
	)
	variant := im.detectVariant(localPath)

	if apiLevel == "" {
		apiLevel = "android-unknown"
	}
	if arch == "" {
		arch = im.detectArch(localPath)
	}

	parsedLevel := im.parseAPILevel(apiLevel)
	image := &SystemImage{
		ID:             im.buildImageID(apiLevel, variant, arch),
		Name:           filepath.Base(localPath),
		APILevel:       parsedLevel,
		AndroidVersion: im.apiLevelToVersion(parsedLevel),
		Arch:           arch,
		Variant:        variant,
		LocalPath:      localPath,
		Files:          im.scanImageFiles(localPath),
		FileSize:       im.calculateTotalSize(localPath),
		Status:         "ready",
	}

	// If we couldn't find any of the required files, mark as error.
	if len(image.Files) == 0 {
		image.Status = "error"
	}

	return image, nil
}

// firstNonEmpty returns the first non-empty string among its arguments.
func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// inferAPILevelFromPath looks for an "android-XX" segment anywhere in the
// path. Used as a final fallback when neither config.ini nor
// source.properties carries an API level.
func (im *ImageManager) inferAPILevelFromPath(p string) string {
	for _, part := range strings.Split(p, string(filepath.Separator)) {
		if strings.HasPrefix(strings.ToLower(part), "android-") {
			return part
		}
	}
	return ""
}

// parseConfigIni reads key=value metadata from an image directory.
//
// It first looks for `config.ini` (the file the previous scanner relied on),
// and — if that doesn't carry an API level — falls back to
// `source.properties`, which is the file the Android SDK actually writes
// (with `AndroidVersion.ApiLevel=34` and similar keys). Missing files are
// not errors: we just return whatever we managed to collect.
func (im *ImageManager) parseConfigIni(dir string) map[string]string {
	config := map[string]string{}

	if m, ok := readKeyValueFile(filepath.Join(dir, "config.ini")); ok {
		for k, v := range m {
			config[k] = v
		}
	}

	// Only fall back to source.properties for the keys we still don't have,
	// so a config.ini that explicitly sets them keeps precedence.
	if config["sdk"] == "" && config["sdk.version"] == "" && config["AndroidVersion.ApiLevel"] == "" {
		if m, ok := readKeyValueFile(filepath.Join(dir, "source.properties")); ok {
			for k, v := range m {
				if _, present := config[k]; !present {
					config[k] = v
				}
			}
		}
	}

	return config
}

func readKeyValueFile(path string) (map[string]string, bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		if key == "" {
			continue
		}
		out[key] = value
	}
	return out, true
}

// detectVariant detects the image variant from directory structure.
func (im *ImageManager) detectVariant(dir string) string {
	// Common variant directory names
	variants := []string{"google_apis", "google_apis_playstore", "default", "aosp"}

	parent := filepath.Base(dir)
	for _, v := range variants {
		if strings.Contains(parent, v) {
			return v
		}
	}

	// Check if images are in Google APIs variant
	if strings.Contains(dir, "google_apis") {
		return "google_apis"
	}

	return "default"
}

// detectArch detects the architecture from kernel or other files.
func (im *ImageManager) detectArch(dir string) string {
	entries, _ := os.ReadDir(dir)
	for _, entry := range entries {
		name := strings.ToLower(entry.Name())
		if strings.Contains(name, "arm64") {
			return "arm64-v8a"
		}
		if strings.Contains(name, "x86_64") || strings.Contains(name, "x64") {
			return "x86_64"
		}
		if strings.Contains(name, "x86") || strings.Contains(name, "i386") {
			return "x86"
		}
	}
	// Default based on platform
	if runtime.GOARCH == "arm64" {
		return "arm64-v8a"
	}
	return "x86_64"
}

// CreateImageRecord creates a metadata file for an image.
func (im *ImageManager) CreateImageRecord(image *SystemImage) error {
	if im.StorageDir == "" {
		return fmt.Errorf("storage directory not set")
	}

	recordDir := filepath.Join(im.StorageDir, image.ID)
	if err := os.MkdirAll(recordDir, 0755); err != nil {
		return err
	}

	recordPath := filepath.Join(recordDir, "metadata.json")
	data, err := json.MarshalIndent(image, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(recordPath, data, 0644)
}

// GetImageRecords returns all stored image metadata records.
func (im *ImageManager) GetImageRecords() []*SystemImage {
	records := []*SystemImage{}

	if im.StorageDir == "" {
		return records
	}

	entries, err := os.ReadDir(im.StorageDir)
	if err != nil {
		return records
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		recordPath := filepath.Join(im.StorageDir, entry.Name(), "metadata.json")
		data, err := os.ReadFile(recordPath)
		if err != nil {
			continue
		}

		var image SystemImage
		if err := json.Unmarshal(data, &image); err != nil {
			continue
		}

		records = append(records, &image)
	}

	return records
}

// DeleteImageRecord deletes an image's metadata record.
func (im *ImageManager) DeleteImageRecord(id string) error {
	if im.StorageDir == "" {
		return fmt.Errorf("storage directory not set")
	}

	recordDir := filepath.Join(im.StorageDir, id)
	return os.RemoveAll(recordDir)
}

// ---------------------------------------------------------------------------
// Local import (directory / zip) — copies the source into the standard
// android-XX/variant/arch/ layout under StorageDir so the existing scanner
// picks it up uniformly alongside the Android SDK's own system-images dir.
// ---------------------------------------------------------------------------

// StoragePath returns the canonical path where an image should be stored,
// following the Android SDK's own nested layout (android-XX/variant/arch/).
func (im *ImageManager) StoragePath(apiLevel int, variant, arch string) string {
	return filepath.Join(im.StorageDir, fmt.Sprintf("android-%d", apiLevel), variant, arch)
}

// ImportImageFromDirectory registers an already-extracted system image
// directory in place. The path is used as-is — we don't copy images into the
// cache; the registry stores the image's own real path. The function scans
// the directory and persists every image it finds, returning the freshly
// registered entries.
func (im *ImageManager) ImportImageFromDirectory(srcPath string) ([]*SystemImage, error) {
	log.Printf("[image] ImportImageFromDirectory: src=%s", srcPath)
	count, err := im.ScanAndRegister(srcPath)
	if err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, fmt.Errorf("no system images found in %s", srcPath)
	}
	found := im.imagesFoundIn(srcPath)
	if len(found) == 0 {
		return nil, fmt.Errorf("scanned %d image(s) under %s but none passed validation", count, srcPath)
	}
	log.Printf("[image] ImportImageFromDirectory: registered %d image(s) from %s", len(found), srcPath)
	return found, nil
}

// ImportImageFromZip extracts a system image archive into a subdirectory of
// the cache (so the registered path lives inside our software's cache and is
// stable across restarts) and registers everything it finds there. If
// extraction or scanning fails — or no valid image is found — the extract
// directory is removed so we don't leave garbage in the cache.
func (im *ImageManager) ImportImageFromZip(zipPath string) ([]*SystemImage, error) {
	log.Printf("[image] ImportImageFromZip: zip=%s", zipPath)

	if im.StorageDir == "" {
		return nil, fmt.Errorf("storage directory not configured")
	}
	importBase := filepath.Join(im.StorageDir, "imports")
	if err := os.MkdirAll(importBase, 0755); err != nil {
		return nil, fmt.Errorf("failed to create import base dir: %w", err)
	}

	baseName := filepath.Base(zipPath)
	if ext := filepath.Ext(baseName); ext != "" {
		baseName = strings.TrimSuffix(baseName, ext)
	}
	extractDir := filepath.Join(importBase, fmt.Sprintf("%s-%d", baseName, time.Now().UnixNano()))

	// We only keep the extract dir on success; otherwise clean it up so
	// failed imports don't pile up in the cache.
	registered := false
	defer func() {
		if !registered {
			log.Printf("[image] ImportImageFromZip: cleaning up %s (success=%v)", extractDir, registered)
			_ = os.RemoveAll(extractDir)
		}
	}()

	if err := os.MkdirAll(extractDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create extract dir: %w", err)
	}

	log.Printf("[image] ImportImageFromZip: extracting %s -> %s", zipPath, extractDir)
	if err := ExtractZip(zipPath, extractDir); err != nil {
		return nil, fmt.Errorf("failed to extract zip: %w", err)
	}

	count, err := im.ScanAndRegister(extractDir)
	if err != nil {
		return nil, fmt.Errorf("failed to scan extracted zip: %w", err)
	}
	if count == 0 {
		return nil, fmt.Errorf("no system images found in zip %s", zipPath)
	}

	found := im.imagesFoundIn(extractDir)
	if len(found) == 0 {
		return nil, fmt.Errorf("scanned %d image(s) from %s but none passed validation", count, zipPath)
	}

	registered = true
	log.Printf("[image] ImportImageFromZip: registered %d image(s) at %s", len(found), extractDir)
	return found, nil
}

// imagesFoundIn returns the registered images whose on-disk path is at or
// under the given root. Used to translate a generic scan result into the
// list of images newly registered by a particular import call.
func (im *ImageManager) imagesFoundIn(root string) []*SystemImage {
	registered := ValidateRegisteredImages()
	rootClean := normalizePath(root)
	if rootClean == "" {
		return nil
	}

	var matched []*SystemImage
	for _, r := range registered {
		pathClean := normalizePath(r.Path)
		if pathClean == "" {
			continue
		}
		if pathClean != rootClean && !strings.HasPrefix(pathClean, rootClean+string(filepath.Separator)) {
			continue
		}
		status := "ready"
		var files map[string]string
		var size int64
		if r.Valid {
			files = im.scanImageFiles(r.Path)
			size = im.calculateTotalSize(r.Path)
		} else {
			status = "error"
		}
		matched = append(matched, &SystemImage{
			ID:             r.ID,
			Name:           r.Name,
			APILevel:       r.APILevel,
			AndroidVersion: r.AndroidVersion,
			Arch:           r.Arch,
			Variant:        r.Variant,
			LocalPath:      r.Path,
			Files:          files,
			FileSize:       size,
			Status:         status,
		})
	}
	return matched
}

// ScanAndRegisterStorage walks the default storage directory and registers
// every discovered image dir into the persisted registry. Existing entries
// are updated in place (deduplicated by path). This is the safety net for
// images that lived on disk before the registry existed — they get picked up
// the next time the backend boots.
func (im *ImageManager) ScanAndRegisterStorage() (int, error) {
	if im.StorageDir == "" {
		return 0, nil
	}
	info, err := os.Stat(im.StorageDir)
	if err != nil || !info.IsDir() {
		return 0, nil
	}

	imageDirs, err := findAllImageDirs(im.StorageDir)
	if err != nil {
		return 0, fmt.Errorf("walk storage dir: %w", err)
	}
	if len(imageDirs) == 0 {
		return 0, nil
	}

	log.Printf("[image] ScanAndRegisterStorage: found %d candidate image dir(s) under %s", len(imageDirs), im.StorageDir)
	total := 0
	for _, d := range imageDirs {
		count, err := im.ScanAndRegister(d)
		if err != nil {
			log.Printf("[image] ScanAndRegisterStorage: register %s failed: %v", d, err)
			continue
		}
		total += count
	}
	log.Printf("[image] ScanAndRegisterStorage: total %d image(s) registered", total)
	return total, nil
}

// findImageDir locates the directory inside an extracted archive that actually
// holds the system image (the deepest directory containing system.img,
// userdata.img, or config.ini). Kept as a single-result helper for the
// download flow, which expects exactly one image per archive.
func findImageDir(root string) (string, error) {
	all, err := findAllImageDirs(root)
	if err != nil {
		return "", err
	}
	if len(all) == 0 {
		return "", fmt.Errorf("no image files (system.img, userdata.img, config.ini) found in archive")
	}
	// findAllImageDirs returns paths in walk order, so the last one is
	// typically the deepest — but we re-derive "deepest" explicitly so
	// the result is stable regardless of the underlying walk implementation.
	deepest := all[0]
	for _, p := range all[1:] {
		if len(p) > len(deepest) {
			deepest = p
		}
	}
	return deepest, nil
}

// findAllImageDirs walks root and returns every directory that contains at
// least one of the canonical system-image marker files (system.img,
// userdata.img, or config.ini). The result is de-duplicated — multiple
// matching files in the same directory collapse to one entry. Used by both
// the zip import and the startup storage scan to handle zips/disks that may
// hold more than one image.
func findAllImageDirs(root string) ([]string, error) {
	seen := make(map[string]struct{})
	var out []string
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			// Don't abort the whole walk on permission errors etc.; just skip.
			return nil
		}
		if info.IsDir() {
			return nil
		}
		name := info.Name()
		if name == "system.img" || name == "userdata.img" || name == "config.ini" {
			dir := filepath.Dir(path)
			if _, ok := seen[dir]; !ok {
				seen[dir] = struct{}{}
				out = append(out, dir)
			}
		}
		return nil
	})
	return out, err
}
