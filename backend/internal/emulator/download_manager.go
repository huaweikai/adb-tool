package emulator

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// DownloadType represents the type of download.
type DownloadType string

const (
	DownloadTypeJava  DownloadType = "java"
	DownloadTypeAVD    DownloadType = "avd"
	DownloadTypeQEMU   DownloadType = "qemu"
	DownloadTypeImage  DownloadType = "image"
	DownloadTypeSDK    DownloadType = "sdk"
	DownloadTypeOther DownloadType = "other"
)

// DownloadItem represents a single download with all its metadata.
type DownloadItem struct {
	ID          string       `json:"id"`
	Type        DownloadType `json:"type"`
	Name        string       `json:"name"`
	URL         string       `json:"url"`
	DestPath    string       `json:"destPath"`
	ExtractedPath string     `json:"extractedPath"`
	SHA256      string       `json:"sha256,omitempty"`
	Size        int64        `json:"size"`
	Downloaded  int64        `json:"downloaded"`
	Status      string       `json:"status"` // pending, downloading, paused, completed, error
	Progress    float64      `json:"progress"`
	Error       string       `json:"error,omitempty"`
	Cancel      chan struct{}
}

// DownloadManager manages all downloads across different types.
type DownloadManager struct {
	mu        sync.RWMutex
	downloads map[string]*DownloadItem
}

// NewDownloadManager creates a new download manager.
func NewDownloadManager() *DownloadManager {
	return &DownloadManager{
		downloads: make(map[string]*DownloadItem),
	}
}

// StartDownload begins a new download and returns the download item.
func (dm *DownloadManager) StartDownload(item *DownloadItem) *DownloadItem {
	dm.mu.Lock()
	item.Cancel = make(chan struct{})
	item.Status = "pending"
	dm.downloads[item.ID] = item
	dm.mu.Unlock()

	go dm.runDownload(item)

	return item
}

// runDownload executes the download in a goroutine.
func (dm *DownloadManager) runDownload(item *DownloadItem) {
	item.Status = "downloading"

	// Ensure directory exists
	dir := filepath.Dir(item.DestPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		item.Status = "error"
		item.Error = fmt.Sprintf("failed to create directory: %v", err)
		dm.notifyUpdate(item)
		return
	}

	// Check for resume
	startPos := dm.getExistingSize(item)

	// Create file
	file, err := os.OpenFile(item.DestPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		item.Status = "error"
		item.Error = fmt.Sprintf("failed to open file: %v", err)
		dm.notifyUpdate(item)
		return
	}

	if startPos > 0 {
		file.Seek(0, io.SeekEnd)
	}

	// Create request with Range header for resume
	req, err := http.NewRequest("GET", item.URL, nil)
	if err != nil {
		file.Close()
		item.Status = "error"
		item.Error = fmt.Sprintf("failed to create request: %v", err)
		dm.notifyUpdate(item)
		return
	}

	if startPos > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", startPos))
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		file.Close()
		item.Status = "error"
		item.Error = fmt.Sprintf("request failed: %v", err)
		dm.notifyUpdate(item)
		return
	}
	defer resp.Body.Close()

	// Check response
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		file.Close()
		item.Status = "error"
		item.Error = fmt.Sprintf("unexpected status: %d", resp.StatusCode)
		dm.notifyUpdate(item)
		return
	}

	totalSize := resp.ContentLength + startPos
	if item.Size > 0 {
		totalSize = item.Size
	}

	// Copy with progress
	buf := make([]byte, 64*1024)
	for {
		select {
		case <-item.Cancel:
			file.Close()
			item.Status = "paused"
			dm.notifyUpdate(item)
			return
		default:
		}

		n, err := resp.Body.Read(buf)
		if n > 0 {
			_, wErr := file.Write(buf[:n])
			if wErr != nil {
				file.Close()
				item.Status = "error"
				item.Error = fmt.Sprintf("write failed: %v", wErr)
				dm.notifyUpdate(item)
				return
			}
			item.Downloaded = startPos + int64(n)
			if totalSize > 0 {
				item.Progress = float64(item.Downloaded) / float64(totalSize)
			}
			dm.notifyUpdate(item)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			file.Close()
			item.Status = "error"
			item.Error = fmt.Sprintf("read failed: %v", err)
			dm.notifyUpdate(item)
			return
		}
	}

	file.Close()
	item.Status = "completed"
	item.Progress = 1.0
	dm.notifyUpdate(item)

	// Verify checksum if provided
	if item.SHA256 != "" {
		if err := VerifyFileSHA256(item.DestPath, item.SHA256); err != nil {
			item.Status = "error"
			item.Error = fmt.Sprintf("checksum failed: %v", err)
			os.Remove(item.DestPath)
			dm.notifyUpdate(item)
			return
		}
	}

	// Extract if ZIP
	if strings.HasSuffix(item.DestPath, ".zip") {
		extractDir := strings.TrimSuffix(item.DestPath, ".zip")
		if err := ExtractZip(item.DestPath, extractDir); err != nil {
			item.Status = "error"
			item.Error = fmt.Sprintf("extraction failed: %v", err)
			dm.notifyUpdate(item)
			return
		}
		item.ExtractedPath = extractDir
		os.Remove(item.DestPath)
	}
}

// notifyUpdate is a placeholder for future WebSocket notifications.
func (dm *DownloadManager) notifyUpdate(item *DownloadItem) {
	// TODO: Implement WebSocket notification
}

// getExistingSize returns the size of an existing file for resume support.
func (dm *DownloadManager) getExistingSize(item *DownloadItem) int64 {
	info, err := os.Stat(item.DestPath)
	if err != nil {
		return 0
	}
	return info.Size()
}

// CancelDownload cancels an ongoing download.
func (dm *DownloadManager) CancelDownload(id string) {
	dm.mu.RLock()
	item, ok := dm.downloads[id]
	dm.mu.RUnlock()

	if ok {
		close(item.Cancel)
	}
}

// PauseDownload pauses an ongoing download.
func (dm *DownloadManager) PauseDownload(id string) {
	dm.CancelDownload(id)
}

// ResumeDownload resumes a paused download.
func (dm *DownloadManager) ResumeDownload(id string) {
	dm.mu.RLock()
	item, ok := dm.downloads[id]
	dm.mu.RUnlock()

	if !ok || item.Status != "paused" {
		return
	}

	// Reset cancel channel
	item.Cancel = make(chan struct{})
	item.Status = "pending"
	go dm.runDownload(item)
}

// GetDownload returns download status.
func (dm *DownloadManager) GetDownload(id string) *DownloadItem {
	dm.mu.RLock()
	defer dm.mu.RUnlock()
	return dm.downloads[id]
}

// ListDownloads returns all downloads, optionally filtered by type.
func (dm *DownloadManager) ListDownloads(types ...DownloadType) []*DownloadItem {
	dm.mu.RLock()
	defer dm.mu.RUnlock()

	result := make([]*DownloadItem, 0, len(dm.downloads))
	for _, item := range dm.downloads {
		if len(types) == 0 {
			result = append(result, item)
		} else {
			for _, t := range types {
				if item.Type == t {
					result = append(result, item)
					break
				}
			}
		}
	}
	return result
}

// ListDownloadsByType is a convenience method for listing downloads of a specific type.
func (dm *DownloadManager) ListDownloadsByType(downloadType DownloadType) []*DownloadItem {
	return dm.ListDownloads(downloadType)
}

// DeleteDownload removes a download from the manager (does not delete files).
func (dm *DownloadManager) DeleteDownload(id string) {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	delete(dm.downloads, id)
}

// DeleteDownloadWithFiles removes a download and deletes its files.
func (dm *DownloadManager) DeleteDownloadWithFiles(id string) error {
	dm.mu.Lock()
	item, ok := dm.downloads[id]
	if ok {
		delete(dm.downloads, id)
	}
	dm.mu.Unlock()

	if !ok {
		return nil
	}

	// Cancel if running
	if item.Status == "downloading" {
		close(item.Cancel)
	}

	// Delete files
	if item.DestPath != "" {
		os.Remove(item.DestPath)
	}
	if item.ExtractedPath != "" {
		os.RemoveAll(item.ExtractedPath)
	}

	return nil
}

// VerifyFileSHA256 verifies the SHA-256 checksum of a file.
func VerifyFileSHA256(filePath, expectedSHA256 string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return err
	}

	actualSHA256 := hex.EncodeToString(hash.Sum(nil))
	if actualSHA256 != expectedSHA256 {
		return fmt.Errorf("expected %s, got %s", expectedSHA256, actualSHA256)
	}

	return nil
}

// ExtractZip extracts a ZIP file to the destination directory.
func ExtractZip(zipPath, destDir string) error {
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("failed to open zip: %w", err)
	}
	defer reader.Close()

	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	for _, file := range reader.File {
		path := filepath.Join(destDir, file.Name)

		// Security: prevent zip slip
		if !strings.HasPrefix(path, filepath.Clean(destDir)+string(filepath.Separator)) {
			return fmt.Errorf("illegal file path: %s", file.Name)
		}

		if file.FileInfo().IsDir() {
			os.MkdirAll(path, 0755)
			continue
		}

		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			return fmt.Errorf("failed to create directory: %w", err)
		}

		dst, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
		if err != nil {
			return fmt.Errorf("failed to create file: %w", err)
		}

		src, err := file.Open()
		if err != nil {
			dst.Close()
			return fmt.Errorf("failed to open zip entry: %w", err)
		}

		_, err = io.Copy(dst, src)
		src.Close()
		dst.Close()

		if err != nil {
			return fmt.Errorf("failed to copy file: %w", err)
		}
	}

	return nil
}
