package server

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	devicesListTimeout = 20 * time.Second
	devicePropsTimeout = 10 * time.Second
	// devicePropsShellCmd is run once per online device. The four
	// values populate the Device fields the Flutter side needs to
	// reconcile "is this the same device as last time?":
	//   - ro.product.model / brand / sdk — display info
	//   - ro.serialno                   — the STABLE identity, used
	//                                     by the frontend as the
	//                                     saved_devices PK. The adb
	//                                     serial (ip:port for wireless,
	//                                     transport-id for USB) is
	//                                     transient; ro.serialno is
	//                                     what survives across
	//                                     reconnects.
	devicePropsShellCmd = "getprop ro.product.model; getprop ro.product.brand; getprop ro.build.version.sdk; getprop ro.serialno"
)

func (m *AdbManager) Devices() ([]Device, error) {
	return m.DevicesContext(context.Background())
}

func (m *AdbManager) DevicesContext(ctx context.Context) ([]Device, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	listCtx, cancel := context.WithTimeout(ctx, devicesListTimeout)
	defer cancel()

	out, err := m.runRawContext(listCtx, "devices", "-l")
	if err != nil && errors.Is(err, context.DeadlineExceeded) {
		m.restartAdbServer()
		retryCtx, retryCancel := context.WithTimeout(context.Background(), devicesListTimeout)
		defer retryCancel()
		out, err = m.runRawContext(retryCtx, "devices", "-l")
	}
	if err != nil {
		return nil, err
	}

	devices := parseDeviceLines(out)
	m.enrichDevicesProps(devices)
	return devices, nil
}

func parseDeviceLines(out string) []Device {
	var devices []Device
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "*") || strings.HasPrefix(line, "List of devices") {
			continue
		}
		serial, state, ok := parseDeviceLine(line)
		if !ok {
			continue
		}
		devices = append(devices, Device{Serial: serial, State: state})
	}
	return devices
}

func (m *AdbManager) enrichDevicesProps(devices []Device) {
	enrichStart := time.Now()

	// Snapshot the serials we'll enrich, so we can log them even after the
	// loop below mutates devices[i].Serial in unusual paths.
	serials := make([]string, 0, len(devices))
	for i := range devices {
		if devices[i].State == "device" {
			serials = append(serials, devices[i].Serial)
		}
	}
	Log.Add(
		"enrich props start",
		fmt.Sprintf("count=%d serials=%v", len(serials), serials),
		nil, 0,
	)

	var wg sync.WaitGroup
	var mu sync.Mutex
	perSerialElapsed := make(map[string]time.Duration, len(serials))
	for i := range devices {
		if devices[i].State != "device" {
			continue
		}
		wg.Add(1)
		idx := i
		serial := devices[i].Serial
		goSafe("enrich-props", func() {
			defer wg.Done()
			serialStart := time.Now()
			props := m.devicePropsForList(serial)
			elapsed := time.Since(serialStart)
			mu.Lock()
			perSerialElapsed[serial] = elapsed
			mu.Unlock()
			if props == nil {
				return
			}
			mu.Lock()
			devices[idx].Model = props["ro.product.model"]
			devices[idx].Brand = props["ro.product.brand"]
			devices[idx].SDK = props["ro.build.version.sdk"]
			// ro.serialno is the device's stable hardware identity.
			// Frontend uses it (not the adb serial) as the
			// saved_devices PK so the same physical device keeps
			// one row across wireless reconnects. Empty string is
			// acceptable: the frontend treats it as "no match" and
			// falls back to adb-serial matching.
			devices[idx].HardwareSerial = props["ro.serialno"]
			mu.Unlock()
		})
	}
	wg.Wait()

	// Log per-serial prop shell timings so we can tell which device (if any)
	// blocked enrichDevicesProps (e.g. adb was being held by Android Studio).
	pairs := make([]string, 0, len(perSerialElapsed))
	for s, d := range perSerialElapsed {
		pairs = append(pairs, fmt.Sprintf("%s=%dms", s, d.Milliseconds()))
	}
	sort.Slice(pairs, func(i, j int) bool {
		// Stable-ish ordering by serial; not critical for readability.
		return pairs[i] < pairs[j]
	})
	Log.Add(
		"enrich props done",
		fmt.Sprintf("total=%dms per=%v", time.Since(enrichStart).Milliseconds(), pairs),
		nil, time.Since(enrichStart),
	)
}

func (m *AdbManager) devicePropsForList(serial string) map[string]string {
	if cached := m.cachedDeviceProps(serial); cached != nil {
		return cached
	}

	ctx, cancel := context.WithTimeout(context.Background(), devicePropsTimeout)
	defer cancel()

	out, err := m.runRawContextQuiet(ctx, "-s", serial, "shell", devicePropsShellCmd)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			m.restartAdbServer()
			retryCtx, retryCancel := context.WithTimeout(context.Background(), devicePropsTimeout)
			defer retryCancel()
			out, err = m.runRawContextQuiet(retryCtx, "-s", serial, "shell", devicePropsShellCmd)
		}
		if err != nil {
			return m.cachedDeviceProps(serial)
		}
	}

	props := parseDevicePropsOutput(out)
	if props == nil {
		return m.cachedDeviceProps(serial)
	}
	m.storeDeviceProps(serial, props)
	return props
}

func parseDevicePropsOutput(out string) map[string]string {
	lines := strings.Split(strings.TrimSpace(out), "\n")
	if len(lines) < 4 {
		return nil
	}
	return map[string]string{
		"ro.product.model":     strings.TrimSpace(lines[0]),
		"ro.product.brand":     strings.TrimSpace(lines[1]),
		"ro.build.version.sdk": strings.TrimSpace(lines[2]),
		"ro.serialno":          strings.TrimSpace(lines[3]),
	}
}

func (m *AdbManager) cachedDeviceProps(serial string) map[string]string {
	m.propsMu.Lock()
	defer m.propsMu.Unlock()
	entry, ok := m.propsCache[serial]
	if !ok || time.Now().After(entry.until) {
		return nil
	}
	props := make(map[string]string, len(entry.props))
	for key, value := range entry.props {
		props[key] = value
	}
	return props
}

func (m *AdbManager) storeDeviceProps(serial string, props map[string]string) {
	m.propsMu.Lock()
	defer m.propsMu.Unlock()
	copied := make(map[string]string, len(props))
	for key, value := range props {
		copied[key] = value
	}
	m.propsCache[serial] = cachedDeviceProps{
		props: copied,
		until: time.Now().Add(devicePropsCacheTTL),
	}
}

func parseDeviceLine(line string) (string, string, bool) {
	fields := strings.Fields(line)
	if len(fields) < 2 {
		return "", "", false
	}
	validStates := map[string]bool{
		"device":       true,
		"offline":      true,
		"unauthorized": true,
		"recovery":     true,
		"sideload":     true,
		"bootloader":   true,
		"host":         true,
	}
	for i, field := range fields {
		if validStates[field] {
			if i == 0 {
				return "", "", false
			}
			return strings.Join(fields[:i], " "), field, true
		}
		if field == "no" && i+1 < len(fields) && fields[i+1] == "permissions" {
			if i == 0 {
				return "", "", false
			}
			return strings.Join(fields[:i], " "), "no permissions", true
		}
	}
	return fields[0], fields[1], true
}

func (m *AdbManager) deviceProps(serial string) (map[string]string, error) {
	if cached := m.cachedDeviceProps(serial); cached != nil {
		return cached, nil
	}
	props := m.devicePropsForList(serial)
	if props == nil {
		return nil, errors.New("device props unavailable")
	}
	return props, nil
}

func (m *AdbManager) DeviceDetail(serial string) (map[string]string, error) {
	out, err := m.run("-s", serial, "shell", "getprop")
	if err != nil {
		return nil, err
	}

	props := make(map[string]string)
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "[") {
			continue
		}
		parts := strings.SplitN(line, "]: [", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimPrefix(parts[0], "[")
		val := strings.TrimSuffix(parts[1], "]")
		props[key] = val
	}
	return props, nil
}
