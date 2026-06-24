package emulator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
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

// ListImages returns all available system images.
func (im *ImageManager) ListImages() []*SystemImage {
	images := []*SystemImage{}

	// First, scan Android SDK's system-images directory
	if im.AndroidHome != "" {
		sdkImages := im.scanSystemImagesDir(filepath.Join(im.AndroidHome, "system-images"))
		images = append(images, sdkImages...)
	}

	// Then, scan our storage directory
	if im.StorageDir != "" {
		storageImages := im.scanSystemImagesDir(im.StorageDir)
		images = append(images, storageImages...)
	}

	return images
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

	// Try to read config.ini for metadata
	config := im.parseConfigIni(localPath)

	apiLevel := config["sdk"] // e.g., "android-34"
	arch := config["abi"]     // e.g., "arm64-v8a"
	variant := im.detectVariant(localPath)

	if apiLevel == "" {
		apiLevel = "android-unknown"
	}
	if arch == "" {
		arch = im.detectArch(localPath)
	}

	image := &SystemImage{
		ID:            im.buildImageID(apiLevel, variant, arch),
		Name:          filepath.Base(localPath),
		APILevel:      im.parseAPILevel(apiLevel),
		AndroidVersion: im.apiLevelToVersion(im.parseAPILevel(apiLevel)),
		Arch:          arch,
		Variant:       variant,
		LocalPath:     localPath,
		Files:         im.scanImageFiles(localPath),
		FileSize:      im.calculateTotalSize(localPath),
		Status:        "ready",
	}

	// Check if all required files exist
	if len(image.Files) == 0 {
		image.Status = "error"
	}

	return image, nil
}

// parseConfigIni parses a config.ini file.
func (im *ImageManager) parseConfigIni(dir string) map[string]string {
	config := map[string]string{}

	configPath := filepath.Join(dir, "config.ini")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return config
	}

	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "#") || line == "" {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			config[key] = value
		}
	}

	return config
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
