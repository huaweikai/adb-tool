package emulator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ImageSource represents a remembered downloadable system image source URL.
type ImageSource struct {
	URL      string `json:"url"`
	Name     string `json:"name,omitempty"`
	APILevel int    `json:"apiLevel,omitempty"`
	Arch     string `json:"arch,omitempty"`
	Variant  string `json:"variant,omitempty"`
	SHA256   string `json:"sha256,omitempty"`
	AddedAt  string `json:"addedAt,omitempty"`
}

var imageSourcesMu sync.Mutex

// imageSourcesPath returns the path to the persisted image-source address book.
func imageSourcesPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "image-sources.json")
}

// LoadImageSources returns the persisted list of image source URLs.
func LoadImageSources() []ImageSource {
	imageSourcesMu.Lock()
	defer imageSourcesMu.Unlock()
	return loadImageSourcesLocked()
}

func loadImageSourcesLocked() []ImageSource {
	data, err := os.ReadFile(imageSourcesPath())
	if err != nil {
		return []ImageSource{}
	}
	var sources []ImageSource
	if err := json.Unmarshal(data, &sources); err != nil {
		return []ImageSource{}
	}
	return sources
}

func saveImageSourcesLocked(sources []ImageSource) error {
	cfgPath := imageSourcesPath()
	if err := os.MkdirAll(filepath.Dir(cfgPath), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(sources, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(cfgPath, data, 0644)
}

// AddImageSource appends a new image source, deduplicating by URL. If the URL
// already exists it returns an error so callers can surface "already added".
func AddImageSource(src ImageSource) ([]ImageSource, error) {
	imageSourcesMu.Lock()
	defer imageSourcesMu.Unlock()

	src.URL = strings.TrimSpace(src.URL)
	if src.URL == "" {
		return nil, fmt.Errorf("url is required")
	}

	sources := loadImageSourcesLocked()
	for _, s := range sources {
		if strings.EqualFold(s.URL, src.URL) {
			return sources, fmt.Errorf("source already exists: %s", src.URL)
		}
	}

	if src.AddedAt == "" {
		src.AddedAt = time.Now().Format(time.RFC3339)
	}
	sources = append(sources, src)
	if err := saveImageSourcesLocked(sources); err != nil {
		return nil, err
	}
	return sources, nil
}

// RemoveImageSource removes a source by URL and persists the result.
func RemoveImageSource(url string) ([]ImageSource, error) {
	imageSourcesMu.Lock()
	defer imageSourcesMu.Unlock()

	url = strings.TrimSpace(url)
	sources := loadImageSourcesLocked()
	filtered := make([]ImageSource, 0, len(sources))
	for _, s := range sources {
		if strings.EqualFold(s.URL, url) {
			continue
		}
		filtered = append(filtered, s)
	}
	if err := saveImageSourcesLocked(filtered); err != nil {
		return nil, err
	}
	return filtered, nil
}
