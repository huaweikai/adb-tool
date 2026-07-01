package server

import (
	"embed"
	"testing"
)

func TestParseDevicePropsOutput(t *testing.T) {
	props := parseDevicePropsOutput("Pixel 8\nGoogle\n35\nROSN-12345\n")
	if props == nil {
		t.Fatal("expected props")
	}
	if props["ro.product.model"] != "Pixel 8" {
		t.Fatalf("unexpected model: %q", props["ro.product.model"])
	}
	if props["ro.product.brand"] != "Google" {
		t.Fatalf("unexpected brand: %q", props["ro.product.brand"])
	}
	if props["ro.build.version.sdk"] != "35" {
		t.Fatalf("unexpected sdk: %q", props["ro.build.version.sdk"])
	}
	if props["ro.serialno"] != "ROSN-12345" {
		t.Fatalf("unexpected serialno: %q", props["ro.serialno"])
	}
}

func TestParseDevicePropsOutputRejectsShortOutput(t *testing.T) {
	// 3-line output (the old format) must NOT silently parse — we
	// want callers to see a cache miss and fall back to the
	// previous cache entry rather than treat the device as having
	// no ro.serialno.
	if props := parseDevicePropsOutput("Pixel 8\nGoogle\n35\n"); props != nil {
		t.Fatalf("expected nil for short output, got: %+v", props)
	}
}

func TestDevicePropsCache(t *testing.T) {
	m := NewAdbManager("adb", embed.FS{})
	props := map[string]string{
		"ro.product.model":     "Pixel",
		"ro.product.brand":     "Google",
		"ro.build.version.sdk": "35",
		"ro.serialno":          "ROSN-CACHED",
	}
	m.storeDeviceProps("serial-1", props)

	cached := m.cachedDeviceProps("serial-1")
	if cached == nil {
		t.Fatal("expected cached props")
	}
	if cached["ro.product.model"] != "Pixel" {
		t.Fatalf("unexpected cached model: %q", cached["ro.product.model"])
	}
	if cached["ro.serialno"] != "ROSN-CACHED" {
		t.Fatalf("unexpected cached serialno: %q", cached["ro.serialno"])
	}
	if m.cachedDeviceProps("missing") != nil {
		t.Fatal("expected cache miss")
	}
}
