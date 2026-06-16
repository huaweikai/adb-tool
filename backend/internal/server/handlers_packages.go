package server

import (
	"io"
	"net/http"
	"os"
	"strings"
)

// handlePackages returns the list of installed packages.
func (s *Server) handlePackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	pkgs, err := s.adb.InstalledPackages(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if pkgs == nil {
		pkgs = []PackageInfo{}
	}
	writeJSON(w, map[string]interface{}{"packages": pkgs})
}

// handleUninstallPackage uninstalls a package from the device.
func (s *Server) handleUninstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and package required")
		return
	}
	if err := s.adb.UninstallPackage(serial, packageName); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleInstallPackage installs an APK from the request body.
func (s *Server) handleInstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	defer r.Body.Close()

	tmpFile, err := os.CreateTemp("", "adb-tool-install-*.apk")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer os.Remove(tmpFile.Name())

	if _, err := io.Copy(tmpFile, r.Body); err != nil {
		if closeErr := tmpFile.Close(); closeErr != nil {
			Log.Add("install temp close", "", closeErr, 0)
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tmpFile.Close(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	output, err := s.adb.InstallPackageContext(r.Context(), serial, tmpFile.Name())
	if err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		msg := parseInstallError(output)
		writeAPIErrorData(w, http.StatusBadRequest, msg, map[string]string{"raw": output})
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "output": output})
}

// parseInstallError maps raw pm install output to a human-readable message.
func parseInstallError(output string) string {
	output = strings.TrimSpace(output)
	switch {
	case strings.Contains(output, "INSTALL_FAILED_VERSION_DOWNGRADE"):
		return "版本低于已安装版本，请先卸载原应用后再安装"
	case strings.Contains(output, "INSTALL_FAILED_ALREADY_EXISTS"):
		return "应用已存在，请先卸载后再安装"
	case strings.Contains(output, "INSTALL_FAILED_UPDATE_INCOMPATIBLE"):
		return "签名不一致，请先卸载原应用后再安装"
	case strings.Contains(output, "INSTALL_FAILED_INSUFFICIENT_STORAGE"):
		return "存储空间不足"
	case strings.Contains(output, "INSTALL_FAILED_INVALID_APK"):
		return "APK 文件无效或已损坏"
	case strings.Contains(output, "INSTALL_PARSE_FAILED"):
		return "APK 解析失败，文件可能已损坏"
	default:
		if output != "" {
			return "安装失败: " + output
		}
		return "安装失败"
	}
}
