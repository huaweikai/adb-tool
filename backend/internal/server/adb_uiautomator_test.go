package server

import (
	"encoding/json"
	"encoding/xml"
	"testing"
)

const testHierarchyXML = `<?xml version="1.0" encoding="utf-16"?>
<hierarchy rotation="0">
  <node index="0" text="" class="android.widget.FrameLayout" package="com.android.systemui" content-desc="" resource-id="" instance="0" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][1440,3120]">
    <node index="0" text="Settings" class="android.widget.TextView" package="com.android.settings" content-desc="Settings icon" resource-id="com.android.settings:id/title" instance="3" checkable="true" checked="false" clickable="true" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[100,200][300,400]">
    </node>
  </node>
</hierarchy>`

func TestParseUiautomatorXML(t *testing.T) {
	clean := stripXMLDecl([]byte(testHierarchyXML))
	var h uiaHierarchy
	if err := xml.Unmarshal(clean, &h); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if h.Rotation != "0" {
		t.Fatalf("expected rotation=0, got %s", h.Rotation)
	}
	root := convertUiaNode(h.Node)
	if root.Class != "android.widget.FrameLayout" {
		t.Fatalf("expected FrameLayout, got %s", root.Class)
	}
	if !root.Clickable {
		// parent has clickable=false, root FrameLayout should not be clickable
	}
	if len(root.Children) != 1 {
		t.Fatalf("expected 1 child, got %d", len(root.Children))
	}
child := root.Children[0]
  if child.Text != "Settings" {
    t.Fatalf("expected text=Settings, got %s", child.Text)
  }
  if child.ResourceID != "com.android.settings:id/title" {
    t.Fatalf("expected resource-id=com.android.settings:id/title, got %s", child.ResourceID)
  }
  if child.Instance != 3 {
    t.Fatalf("expected instance=3, got %d", child.Instance)
  }
  if child.ContentDesc != "Settings icon" {
    t.Fatalf("expected content-desc=Settings icon, got %s", child.ContentDesc)
  }
	if !child.Clickable {
		t.Fatal("expected clickable=true")
	}
	if !child.Checkable {
		t.Fatal("expected checkable=true")
	}
	if child.Bounds != "[100,200][300,400]" {
		t.Fatalf("expected bounds [100,200][300,400], got %s", child.Bounds)
	}

	// Verify JSON serialization
	b, err := json.Marshal(root)
	if err != nil {
		t.Fatalf("json marshal: %v", err)
	}
	var back ViewNode
	if err := json.Unmarshal(b, &back); err != nil {
		t.Fatalf("json unmarshal: %v", err)
	}
	if len(back.Children) != 1 || back.Children[0].Text != "Settings" {
		t.Fatal("json round-trip mismatch")
	}
}
