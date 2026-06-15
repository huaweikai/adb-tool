package server

import "testing"

func TestParseDevicePropsOutput(t *testing.T) {
	props := parseDevicePropsOutput("Pixel 8\nGoogle\n35\n")
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
}

func TestDevicePropsCache(t *testing.T) {
	m := NewAdbManager("adb")
	props := map[string]string{
		"ro.product.model":     "Pixel",
		"ro.product.brand":     "Google",
		"ro.build.version.sdk": "35",
	}
	m.storeDeviceProps("serial-1", props)

	cached := m.cachedDeviceProps("serial-1")
	if cached == nil {
		t.Fatal("expected cached props")
	}
	if cached["ro.product.model"] != "Pixel" {
		t.Fatalf("unexpected cached model: %q", cached["ro.product.model"])
	}
	if m.cachedDeviceProps("missing") != nil {
		t.Fatal("expected cache miss")
	}
}
