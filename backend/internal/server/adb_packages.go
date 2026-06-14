package server

import (
	"context"
	"fmt"
	"regexp"
	"strings"
)

var installPkgRe = regexp.MustCompile(`Package\s+(\S+)`)

func (m *AdbManager) InstalledPackages(serial string) ([]PackageInfo, error) {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", "-f")
	if err != nil {
		out, err = m.run("-s", serial, "shell", "pm", "list", "packages")
		if err != nil {
			return nil, err
		}
		lines := strings.Split(out, "\n")
		var packages []PackageInfo
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if !strings.HasPrefix(line, "package:") {
				continue
			}
			pkgName := strings.TrimPrefix(line, "package:")
			packages = append(packages, PackageInfo{
				PackageName: pkgName,
				SourceDir:   "",
			})
		}
		return packages, nil
	}

	lines := strings.Split(out, "\n")
	var packages []PackageInfo
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "package:") {
			continue
		}
		content := strings.TrimPrefix(line, "package:")
		idx := strings.LastIndex(content, "=")
		if idx < 0 {
			continue
		}
		sourceDir := content[:idx]
		pkgName := content[idx+1:]
		packages = append(packages, PackageInfo{
			PackageName: pkgName,
			SourceDir:   sourceDir,
		})
	}
	return packages, nil
}

func (m *AdbManager) UninstallPackage(serial, packageName string) error {
	_, err := m.run("-s", serial, "uninstall", packageName)
	return err
}

func (m *AdbManager) InstallPackage(serial, apkPath string) (string, error) {
	return m.InstallPackageContext(context.Background(), serial, apkPath)
}

func (m *AdbManager) InstallPackageContext(ctx context.Context, serial, apkPath string) (string, error) {
	output, err := m.runRawContext(ctx, "-s", serial, "install", "-r", "-d", apkPath)
	if err == nil {
		return output, nil
	}

	if ctx.Err() != nil || !strings.Contains(output, "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
		return output, err
	}

	pkg := extractPackageFromInstallError(output)
	if pkg == "" {
		return output, fmt.Errorf("签名不一致，但无法解析包名\n%s", output)
	}

	uninstallOut, uninstallErr := m.runRawContext(ctx, "-s", serial, "uninstall", pkg)
	if uninstallErr != nil {
		return output, fmt.Errorf("签名不一致，卸载旧版本(%s)也失败: %s\n原错误: %s", pkg, uninstallOut, output)
	}

	output, err = m.runRawContext(ctx, "-s", serial, "install", apkPath)
	if err != nil {
		return output, fmt.Errorf("已卸载旧版本(%s)，但安装新版本仍然失败: %s", pkg, output)
	}

	return "已卸载旧版本(" + pkg + ")并重新安装成功\n" + output, nil
}

func extractPackageFromInstallError(output string) string {
	m := installPkgRe.FindStringSubmatch(output)
	if len(m) > 1 {
		return m[1]
	}
	return ""
}
