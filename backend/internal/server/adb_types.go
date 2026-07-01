package server

// Device is one row in the response of `GET /api/devices`. It carries
// two identity fields:
//
//   - Serial:        the adb-level address (ip:port for wireless,
//                    transport-id / hardware serial for USB). This
//                    is what adb commands target — passes through to
//                    `adb -s <Serial> ...` unchanged.
//   - HardwareSerial: the device's stable hardware identity
//                    (ro.serialno). Used by the Flutter side as the
//                    saved_devices primary key so the same physical
//                    device keeps one row across reconnects, even
//                    when the adb Serial changes (typical for
//                    wireless: ip:port churns on every reconnect).
//
// For USB devices the two are usually identical. For wireless they
// are not — Serial is something like "192.168.31.141:33729" while
// HardwareSerial is the phone's ro.serialno (e.g. "R5CT70AHPDR").
type Device struct {
	Serial         string `json:"serial"`
	HardwareSerial string `json:"hardwareSerial,omitempty"`
	State          string `json:"state"`
	Model          string `json:"model"`
	Brand          string `json:"brand"`
	SDK            string `json:"sdk"`
}

type LogFilter struct {
	Tag         string `json:"tag"`
	Priority    string `json:"priority"`
	Keyword     string `json:"keyword"`
	PackageName string `json:"packageName"`
	PackagePid  string `json:"packagePid"`
}

type FileEntry struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Size        int64  `json:"size"`
	IsDir       bool   `json:"isDir"`
	Permissions string `json:"permissions"`
	Modified    string `json:"modified"`
}

type FileStat struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Size        int64  `json:"size"`
	IsDir       bool   `json:"isDir"`
	Permissions string `json:"permissions"`
	Modified    string `json:"modified"`
	Raw         string `json:"raw"`
}

type PackageInfo struct {
	PackageName string `json:"packageName"`
	SourceDir   string `json:"sourceDir"`
}

type WirelessAdbDevice struct {
	Name        string `json:"name"`
	Host        string `json:"host"`
	PairPort    string `json:"pairPort,omitempty"`
	ConnectPort string `json:"connectPort,omitempty"`
	PairAddress string `json:"pairAddress,omitempty"`
	Address     string `json:"address,omitempty"`
	Source      string `json:"source"`
}
