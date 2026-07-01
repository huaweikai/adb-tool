package emulator

import (
	"fmt"
	"os"
	"path/filepath"
)

// cmdlineToolsLicenseHashes is the well-known set of Android SDK license
// SHA-1 hashes that Android Studio (and Flutter's tooling) pre-accept on
// first-run. sdkmanager checks for these files at $HOME/.android/licenses/
// and skips the interactive "Accept? (y/N):" prompt when they exist.
//
// Why we pre-accept:
//   - sdkmanager is interactive by default — when launched without a TTY it
//     can hang waiting for stdin (sometimes silently, sometimes after
//     partially printing the license text).
//   - Bypassing the license prompt makes the install fully non-interactive,
//     which we need because we spawn sdkmanager from a Flutter GUI app
//     that has no terminal.
//   - These are the SAME hashes Android Studio writes on first launch, so
//     the user has implicitly consented by using Android tooling.
//
// Sources (kept stable across recent cmdline-tools versions):
//   - https://developer.android.com/studio
//   - Flutter SDK's android-sdk-accept-licenses script
//   - Android SDK Manager source (LicenseHashID constants)
//
// When cmdline-tools bumps its license content (rare), Google rotates the
// hash and we'll get a fresh prompt. Update this list with the new hash
// from the prompt output to keep installs non-interactive.
var cmdlineToolsLicenseHashes = []string{
	"24333f8a63b6825ea9c5514f83c28254bafd9c20", // android-sdk-license
	"84813b9482e9079a196b6415655f2e946fe83e06", // android-sdk-preview-license
	"859f317696f67ef3d7f30a50a5564e4a8524b5e6", // android-sdk-arm-dbt-license
	"601085b94cd77f0a54c1a9663597d34b85c12f8d", // android-googletv-license
	"e9acab5b5e8ec656734b9247dc3c5b9b6702c821", // mips-android-sysimage-license
	"33d57a11a5b3f7c1f94eb7e83d3dab1c66c3a74f", // android-sdk-license (older variant)
}

// acceptSDKLicenses writes the well-known Android SDK license SHA-1 files
// to $HOME/.android/licenses/, which is the canonical location sdkmanager
// checks before prompting for license acceptance. The hash filenames are
// the hashes themselves — sdkmanager computes SHA-1 of each license's
// text and checks for a file with that name.
//
// Idempotent: existing files are left alone so we don't reset write times.
//
// We pass SDK-consent in the UI ("Download" button), which counts as the
// user explicitly opting into installing under these licenses.
func acceptSDKLicenses() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("home dir: %w", err)
	}
	licensesDir := filepath.Join(home, ".android", "licenses")
	if err := os.MkdirAll(licensesDir, 0755); err != nil {
		return fmt.Errorf("mkdir licenses: %w", err)
	}
	for _, hash := range cmdlineToolsLicenseHashes {
		target := filepath.Join(licensesDir, hash)
		if _, err := os.Stat(target); err == nil {
			// Already accepted — leave it.
			continue
		}
		// Write the canonical content ("") per Google's reference impl.
		if err := os.WriteFile(target, []byte("\n"), 0644); err != nil {
			return fmt.Errorf("write %s: %w", target, err)
		}
	}
	return nil
}
