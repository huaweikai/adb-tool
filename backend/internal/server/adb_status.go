package server

import (
	"context"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var (
	reRefreshRate   = regexp.MustCompile(`(?i)(refreshRate|fps)[=: ]+([0-9]+(?:\.[0-9]+)?)`)
	reWifiSSID      = regexp.MustCompile(`SSID: ([^\n,]+)`)
	reWifiRSSI      = regexp.MustCompile(`RSSI: (-?\d+)`)
	reMobileSig1    = regexp.MustCompile(`mSignalStrength=([^\n]+)`)
	reMobileSig2    = regexp.MustCompile(`SignalStrength: ([^\n]+)`)
)

type DeviceStatus struct {
	CollectedAt        string          `json:"collectedAt"`
	BatteryLevel       string          `json:"batteryLevel"`
	BatteryStatus      string          `json:"batteryStatus"`
	BatteryTemperature string          `json:"batteryTemperature"`
	CpuUsage           string          `json:"cpuUsage"`
	CpuLoad            string          `json:"cpuLoad"`
	MemoryTotal        string          `json:"memoryTotal"`
	MemoryAvailable    string          `json:"memoryAvailable"`
	MemoryUsedPercent  string          `json:"memoryUsedPercent"`
	StorageTotal       string          `json:"storageTotal"`
	StorageUsed        string          `json:"storageUsed"`
	StorageAvailable   string          `json:"storageAvailable"`
	StorageUsedPercent string          `json:"storageUsedPercent"`
	Resolution         string          `json:"resolution"`
	Density            string          `json:"density"`
	RefreshRate        string          `json:"refreshRate"`
	FrameStats         string          `json:"frameStats"`
	NetworkType        string          `json:"networkType"`
	WifiSSID           string          `json:"wifiSsid"`
	WifiRSSI           string          `json:"wifiRssi"`
	MobileSignal       string          `json:"mobileSignal"`
	IPAddress          string          `json:"ipAddress"`
	Uptime             string          `json:"uptime"`
	ThermalStatus      string          `json:"thermalStatus"`
	TopProcesses       []ProcessStatus `json:"topProcesses"`
}

type ProcessStatus struct {
	PID     string `json:"pid"`
	User    string `json:"user"`
	CPU     string `json:"cpu"`
	Memory  string `json:"memory"`
	Name    string `json:"name"`
	Command string `json:"command"`
}

func (m *AdbManager) DeviceStatus(ctx context.Context, serial string) (*DeviceStatus, error) {
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	status := &DeviceStatus{
		CollectedAt:  time.Now().Format(time.RFC3339),
		TopProcesses: []ProcessStatus{},
	}

	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		battery, err := m.runShellContext(ctx, serial, "dumpsys battery")
		if err != nil {
			return
		}
		parseBatteryStatus(status, battery)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		meminfo, err := m.runShellContext(ctx, serial, "cat /proc/meminfo")
		if err != nil {
			return
		}
		parseMemoryStatus(status, meminfo)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		stat1, err := m.runShellContext(ctx, serial, "cat /proc/stat | head -n 1")
		if err != nil {
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(180 * time.Millisecond):
		}
		stat2, err := m.runShellContext(ctx, serial, "cat /proc/stat | head -n 1")
		if err != nil {
			return
		}
		status.CpuUsage = parseCPUUsage(stat1, stat2)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		loadavg, err := m.runShellContext(ctx, serial, "cat /proc/loadavg")
		if err != nil {
			return
		}
		status.CpuLoad = firstFields(loadavg, 3)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		storage, err := m.runShellContext(ctx, serial, "df -k /data")
		if err != nil {
			return
		}
		parseStorageStatus(status, storage)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		resolution, err := m.runShellContext(ctx, serial, "wm size")
		if err != nil {
			return
		}
		status.Resolution = parseAfterColon(resolution)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		density, err := m.runShellContext(ctx, serial, "wm density")
		if err != nil {
			return
		}
		status.Density = parseAfterColon(density)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		display, err := m.runShellContext(ctx, serial, "dumpsys display")
		if err != nil {
			return
		}
		status.RefreshRate = parseRefreshRate(display)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		gfx, err := m.runShellContext(ctx, serial, "dumpsys gfxinfo framestats 2>/dev/null | head -n 20")
		if err != nil {
			return
		}
		status.FrameStats = parseFrameStats(gfx)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		wifi, err := m.runShellContext(ctx, serial, "dumpsys wifi")
		if err != nil {
			return
		}
		parseWifiStatus(status, wifi)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		telephony, err := m.runShellContext(ctx, serial, "dumpsys telephony.registry")
		if err != nil {
			return
		}
		status.MobileSignal = parseMobileSignal(telephony)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		ipaddr, err := m.runShellContext(ctx, serial, "ip -o addr show scope global 2>/dev/null")
		if err != nil {
			return
		}
		status.IPAddress = parseIPAddress(ipaddr)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		uptime, err := m.runShellContext(ctx, serial, "cat /proc/uptime")
		if err != nil {
			return
		}
		status.Uptime = parseUptime(uptime)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		thermal, err := m.runShellContext(ctx, serial, "dumpsys thermalservice 2>/dev/null | head -n 30")
		if err != nil {
			return
		}
		status.ThermalStatus = parseThermalStatus(thermal)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		top, err := m.runShellContext(ctx, serial, "top -b -n 1 -o PID,USER,%CPU,%MEM,ARGS 2>/dev/null | head -n 12")
		if err != nil {
			return
		}
		if strings.TrimSpace(top) == "" {
			top, err = m.runShellContext(ctx, serial, "top -n 1 -m 10")
			if err != nil {
				return
			}
		}
		status.TopProcesses = parseTopProcesses(top)
	}()

	wg.Wait()

	if status.WifiRSSI != "" || status.WifiSSID != "" {
		status.NetworkType = "Wi-Fi"
	} else if status.MobileSignal != "" {
		status.NetworkType = "Mobile"
	}

	return status, nil
}

func (m *AdbManager) runShellContext(ctx context.Context, serial, command string) (string, error) {
	return m.runContext(ctx, "-s", serial, "shell", command)
}

func (m *AdbManager) runContext(ctx context.Context, args ...string) (string, error) {
	return m.runRawContext(ctx, args...)
}

func parseBatteryStatus(status *DeviceStatus, text string) {
	status.BatteryLevel = findLineValue(text, "level")
	status.BatteryTemperature = formatBatteryTemp(findLineValue(text, "temperature"))
	status.BatteryStatus = batteryStatusName(findLineValue(text, "status"))
}

func parseMemoryStatus(status *DeviceStatus, text string) {
	values := map[string]int64{}
	for _, line := range strings.Split(text, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		value, err := strconv.ParseInt(fields[1], 10, 64)
		if err == nil {
			values[key] = value
		}
	}
	total := values["MemTotal"]
	available := values["MemAvailable"]
	if available == 0 {
		available = values["MemFree"] + values["Buffers"] + values["Cached"]
	}
	if total <= 0 {
		return
	}
	used := total - available
	status.MemoryTotal = formatKiB(total)
	status.MemoryAvailable = formatKiB(available)
	status.MemoryUsedPercent = formatPercent(float64(used) / float64(total) * 100)
}

func parseCPUUsage(a, b string) string {
	first := parseCPUFields(a)
	second := parseCPUFields(b)
	if len(first) < 5 || len(second) < 5 {
		return ""
	}
	total1, idle1 := cpuTotals(first)
	total2, idle2 := cpuTotals(second)
	totalDelta := total2 - total1
	idleDelta := idle2 - idle1
	if totalDelta <= 0 {
		return ""
	}
	return formatPercent(float64(totalDelta-idleDelta) / float64(totalDelta) * 100)
}

func parseCPUFields(line string) []int64 {
	fields := strings.Fields(line)
	values := []int64{}
	for _, field := range fields[1:] {
		value, err := strconv.ParseInt(field, 10, 64)
		if err == nil {
			values = append(values, value)
		}
	}
	return values
}

func cpuTotals(values []int64) (int64, int64) {
	var total int64
	for _, value := range values {
		total += value
	}
	idle := values[3]
	if len(values) > 4 {
		idle += values[4]
	}
	return total, idle
}

func parseStorageStatus(status *DeviceStatus, text string) {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	if len(lines) < 2 {
		return
	}
	fields := strings.Fields(lines[len(lines)-1])
	if len(fields) < 5 {
		return
	}
	total, totalErr := strconv.ParseInt(fields[1], 10, 64)
	used, usedErr := strconv.ParseInt(fields[2], 10, 64)
	available, availableErr := strconv.ParseInt(fields[3], 10, 64)
	if totalErr != nil || usedErr != nil || availableErr != nil {
		return
	}
	status.StorageTotal = formatKiB(total)
	status.StorageUsed = formatKiB(used)
	status.StorageAvailable = formatKiB(available)
	status.StorageUsedPercent = strings.TrimSuffix(fields[4], "%") + "%"
}

func parseRefreshRate(text string) string {
	matches := reRefreshRate.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 {
		return ""
	}
	values := map[string]bool{}
	for _, match := range matches {
		values[match[2]+" Hz"] = true
	}
	list := make([]string, 0, len(values))
	for value := range values {
		list = append(list, value)
	}
	sort.Strings(list)
	return strings.Join(list, " / ")
}

func parseFrameStats(text string) string {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" {
		return ""
	}
	if strings.Contains(trimmed, "Flags") || strings.Contains(trimmed, "---PROFILEDATA---") {
		return "framestats available"
	}
	return firstNonEmptyLine(trimmed)
}

func parseWifiStatus(status *DeviceStatus, text string) {
	status.WifiSSID = firstRegexMatch(reWifiSSID, text)
	status.WifiRSSI = firstRegexMatch(reWifiRSSI, text)
	if status.WifiRSSI != "" {
		status.WifiRSSI += " dBm"
	}
}

func parseMobileSignal(text string) string {
	value := firstRegexMatch(reMobileSig1, text)
	if value == "" {
		value = firstRegexMatch(reMobileSig2, text)
	}
	return strings.TrimSpace(value)
}

func parseIPAddress(text string) string {
	lines := strings.Split(text, "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		for i, field := range fields {
			if field == "inet" && i+1 < len(fields) {
				return fields[i+1]
			}
		}
	}
	return ""
}

func parseUptime(text string) string {
	fields := strings.Fields(text)
	if len(fields) == 0 {
		return ""
	}
	seconds, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return ""
	}
	d := time.Duration(seconds) * time.Second
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60
	if days > 0 {
		return strconv.Itoa(days) + "d " + strconv.Itoa(hours) + "h " + strconv.Itoa(minutes) + "m"
	}
	return strconv.Itoa(hours) + "h " + strconv.Itoa(minutes) + "m"
}

func parseThermalStatus(text string) string {
	return firstNonEmptyLine(text)
}

func parseTopProcesses(text string) []ProcessStatus {
	processes := []ProcessStatus{}
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.Contains(strings.ToLower(line), "pid") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 5 {
			continue
		}
		process := ProcessStatus{PID: fields[0]}
		if strings.Contains(fields[2], "%") || isNumericLike(fields[2]) {
			process.User = fields[1]
			process.CPU = strings.TrimSuffix(fields[2], "%") + "%"
			process.Memory = strings.TrimSuffix(fields[3], "%") + "%"
			process.Command = strings.Join(fields[4:], " ")
		} else if len(fields) >= 10 {
			process.User = fields[1]
			process.CPU = strings.TrimSuffix(fields[8], "%") + "%"
			process.Memory = ""
			process.Command = strings.Join(fields[9:], " ")
		} else {
			continue
		}
		parts := strings.Split(process.Command, "/")
		process.Name = parts[len(parts)-1]
		processes = append(processes, process)
		if len(processes) >= 8 {
			break
		}
	}
	return processes
}

func findLineValue(text, key string) string {
	prefix := key + ":"
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, prefix) {
			return strings.TrimSpace(strings.TrimPrefix(line, prefix))
		}
	}
	return ""
}

func formatBatteryTemp(value string) string {
	n, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return ""
	}
	return strconv.FormatFloat(n/10, 'f', 1, 64) + " \u2103"
}

func batteryStatusName(value string) string {
	switch strings.TrimSpace(value) {
	case "2":
		return "Charging"
	case "3":
		return "Discharging"
	case "4":
		return "Not charging"
	case "5":
		return "Full"
	default:
		return value
	}
}

func formatKiB(kib int64) string {
	if kib <= 0 {
		return ""
	}
	gib := float64(kib) / 1024 / 1024
	if gib >= 1 {
		return strconv.FormatFloat(gib, 'f', 1, 64) + " GB"
	}
	mib := float64(kib) / 1024
	return strconv.FormatFloat(mib, 'f', 1, 64) + " MB"
}

func formatPercent(value float64) string {
	return strconv.FormatFloat(value, 'f', 1, 64) + "%"
}

func parseAfterColon(text string) string {
	line := firstNonEmptyLine(text)
	if line == "" {
		return ""
	}
	idx := strings.Index(line, ":")
	if idx < 0 {
		return strings.TrimSpace(line)
	}
	return strings.TrimSpace(line[idx+1:])
}

func firstFields(text string, count int) string {
	fields := strings.Fields(text)
	if len(fields) < count {
		count = len(fields)
	}
	return strings.Join(fields[:count], " ")
}

func firstNonEmptyLine(text string) string {
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			return line
		}
	}
	return ""
}

func firstRegexMatch(re *regexp.Regexp, text string) string {
	match := re.FindStringSubmatch(text)
	if len(match) < 2 {
		return ""
	}
	return strings.TrimSpace(match[1])
}

func isNumericLike(value string) bool {
	value = strings.TrimSuffix(value, "%")
	_, err := strconv.ParseFloat(value, 64)
	return err == nil
}
