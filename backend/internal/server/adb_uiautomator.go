package server

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"log"
	"strconv"
	"unicode/utf16"
)

type ViewNode struct {
	Index         int        `json:"index"`
	Text          string     `json:"text"`
	Class         string     `json:"class"`
	Package       string     `json:"package"`
	ContentDesc   string     `json:"contentDesc"`
	ResourceID    string     `json:"resourceId"`
	Instance      int        `json:"instance"`
	Checkable     bool       `json:"checkable"`
	Checked       bool       `json:"checked"`
	Clickable     bool       `json:"clickable"`
	Enabled       bool       `json:"enabled"`
	Focusable     bool       `json:"focusable"`
	Focused       bool       `json:"focused"`
	Scrollable    bool       `json:"scrollable"`
	LongClickable bool       `json:"longClickable"`
	Password      bool       `json:"password"`
	Selected      bool       `json:"selected"`
	Bounds        string     `json:"bounds"`
	Children      []ViewNode `json:"children"`
}

type uiaNode struct {
	Index         string   `xml:"index,attr"`
	Text          string   `xml:"text,attr"`
	Class         string   `xml:"class,attr"`
	Package       string   `xml:"package,attr"`
	ContentDesc   string   `xml:"content-desc,attr"`
	ResourceID    string   `xml:"resource-id,attr"`
	Instance      string   `xml:"instance,attr"`
	Checkable     string   `xml:"checkable,attr"`
	Checked       string   `xml:"checked,attr"`
	Clickable     string   `xml:"clickable,attr"`
	Enabled       string   `xml:"enabled,attr"`
	Focusable     string   `xml:"focusable,attr"`
	Focused       string   `xml:"focused,attr"`
	Scrollable    string   `xml:"scrollable,attr"`
	LongClickable string   `xml:"long-clickable,attr"`
	Password      string   `xml:"password,attr"`
	Selected      string   `xml:"selected,attr"`
	Bounds        string   `xml:"bounds,attr"`
	Children      []uiaNode `xml:"node"`
}

type uiaHierarchy struct {
	Rotation string  `xml:"rotation,attr"`
	Node     uiaNode `xml:"node"`
}

// HierarchyDump is the JSON shape returned to the client. `Rotation` tells the
// frontend how many 90° counter-clockwise turns the device has been rotated;
// the screenshot PNG is still in its physical (pre-rotation) orientation, so
// the client must apply this same rotation before laying node bounds on top.
type HierarchyDump struct {
	Hierarchy *ViewNode `json:"hierarchy"`
	Rotation  int       `json:"rotation"`
}

func attrBool(s string) bool {
	return s == "true"
}

func attrInt(s string) int {
	n, _ := strconv.Atoi(s)
	return n
}

func convertUiaNode(n uiaNode) ViewNode {
	cn := ViewNode{
		Index:         attrInt(n.Index),
		Text:          n.Text,
		Class:         n.Class,
		Package:       n.Package,
		ContentDesc:   n.ContentDesc,
		ResourceID:    n.ResourceID,
		Instance:      attrInt(n.Instance),
		Checkable:     attrBool(n.Checkable),
		Checked:       attrBool(n.Checked),
		Clickable:     attrBool(n.Clickable),
		Enabled:       attrBool(n.Enabled),
		Focusable:     attrBool(n.Focusable),
		Focused:       attrBool(n.Focused),
		Scrollable:    attrBool(n.Scrollable),
		LongClickable: attrBool(n.LongClickable),
		Password:      attrBool(n.Password),
		Selected:      attrBool(n.Selected),
		Bounds:        n.Bounds,
	}
	for _, child := range n.Children {
		cn.Children = append(cn.Children, convertUiaNode(child))
	}
	return cn
}

// decodeUTF16XML converts UTF-16 encoded XML bytes to UTF-8 if needed.
// uiautomator dump on some devices produces UTF-16LE XML.
func decodeUTF16XML(data []byte) ([]byte, error) {
	if len(data) < 2 {
		return data, nil
	}
	var order string
	switch {
	case data[0] == 0xFE && data[1] == 0xFF:
		order = "BE"
	case data[0] == 0xFF && data[1] == 0xFE:
		order = "LE"
	default:
		return data, nil
	}

	raw := data[2:]
	runes := make([]uint16, 0, len(raw)/2)
	if order == "BE" {
		for i := 0; i+1 < len(raw); i += 2 {
			runes = append(runes, uint16(raw[i])<<8|uint16(raw[i+1]))
		}
	} else {
		for i := 0; i+1 < len(raw); i += 2 {
			runes = append(runes, uint16(raw[i+1])<<8|uint16(raw[i]))
		}
	}
	// string(runes) is cheaper than per-rune AppendRune + slice growth.
	return []byte(string(utf16.Decode(runes))), nil
}

// stripXMLDecl removes <?xml ...?> declaration to avoid encoding mismatch.
func stripXMLDecl(data []byte) []byte {
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) > 5 && string(trimmed[:5]) == "<?xml" {
		if idx := bytes.Index(trimmed, []byte("?>")); idx != -1 {
			return bytes.TrimSpace(trimmed[idx+2:])
		}
	}
	return trimmed
}

func (m *AdbManager) dumpViewHierarchy(serial string) (*HierarchyDump, error) {
	// Single adb invocation: dump to /sdcard, cat raw bytes, remove. Saves one
	// adb round-trip (vs `shell dump` + `pull`) and avoids temp-file I/O.
	const remotePath = "/sdcard/window_dump.xml"
	const script = "uiautomator dump --compressed " + remotePath +
		" >/dev/null 2>&1 && cat " + remotePath +
		" && rm -f " + remotePath

	data, err := m.runOut("-s", serial, "exec-out", script)
	if err != nil {
		return nil, fmt.Errorf("uiautomator dump failed: %w", err)
	}
	if len(data) == 0 {
		return nil, fmt.Errorf("uiautomator dump returned empty output")
	}
	log.Printf("[uiautomator] dump output: serial=%s bytes=%d", serial, len(data))

	utf8Data, err := decodeUTF16XML(data)
	if err != nil {
		return nil, fmt.Errorf("decode utf16: %w", err)
	}
	// Strip XML declaration so Go's encoder doesn't trip on encoding="utf-16"
	clean := stripXMLDecl(utf8Data)

	var h uiaHierarchy
	if err := xml.Unmarshal(clean, &h); err != nil {
		return nil, fmt.Errorf("parse hierarchy xml: %w", err)
	}

	root := convertUiaNode(h.Node)
	return &HierarchyDump{
		Hierarchy: &root,
		Rotation:  attrInt(h.Rotation),
	}, nil
}
