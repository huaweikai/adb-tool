package emulator

import (
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

// resolveSDKManagerClasspath resolves the classpath that the cmdline-tools
// sdkmanager classloader needs. Google's sdkmanager shell wrapper constructs
// this on the fly:
//
//	CLASSPATH=$APP_HOME/lib/sdkmanager-classpath.jar
//
// where APP_HOME = `dirname sdkmanager`/.. . Empirically a single fat jar
// (sdkmanager-classpath.jar) holds the entire sdkmanager class graph,
// but we also fall back to aggregating every jar under lib/ in case
// Google ever changes that convention.
//
// Returns (classpath, appHome, error). AppHome is exposed because callers
// typically also need it for diagnosis logging.
func resolveSDKManagerClasspath(sdkmanagerPath string) (string, string, error) {
	appHome, err := filepath.Abs(filepath.Join(filepath.Dir(sdkmanagerPath), ".."))
	if err != nil {
		return "", "", err
	}

	lib := filepath.Join(appHome, "lib")

	// Fast path: the canonical single fat jar shipped with cmdline-tools.
	fat := filepath.Join(lib, "sdkmanager-classpath.jar")
	if _, err := os.Stat(fat); err == nil {
		return fat, appHome, nil
	}

	// Fallback: aggregate every jar under lib/.
	entries, err := os.ReadDir(lib)
	if err != nil {
		return "", appHome, err
	}
	var jars []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if !strings.EqualFold(filepath.Ext(e.Name()), ".jar") {
			continue
		}
		jars = append(jars, filepath.Join(lib, e.Name()))
	}
	if len(jars) == 0 {
		return "", appHome, os.ErrNotExist
	}
	sort.Strings(jars) // deterministic order for stable logs / no classpath collisions
	sep := ":"
	if runtime.GOOS == "windows" {
		sep = ";"
	}
	return strings.Join(jars, sep), appHome, nil
}
