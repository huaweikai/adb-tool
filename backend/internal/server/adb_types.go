package server

type Device struct {
	Serial string `json:"serial"`
	State  string `json:"state"`
	Model  string `json:"model"`
	Brand  string `json:"brand"`
	SDK    string `json:"sdk"`
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
