package server

import (
	"context"
	"errors"
	"strings"
	"sync"
	"time"
)

const (
	devicesListTimeout  = 20 * time.Second
	devicePropsTimeout  = 10 * time.Second
	devicePropsShellCmd = "getprop ro.product.model; getprop ro.product.brand; getprop ro.build.version.sdk"
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
	var wg sync.WaitGroup
	var mu sync.Mutex
	for i := range devices {
		if devices[i].State != "device" {
			continue
		}
		wg.Add(1)
		go func(idx int, serial string) {
			defer wg.Done()
			props := m.devicePropsForList(serial)
			if props == nil {
				return
			}
			mu.Lock()
			devices[idx].Model = props["ro.product.model"]
			devices[idx].Brand = props["ro.product.brand"]
			devices[idx].SDK = props["ro.build.version.sdk"]
			mu.Unlock()
		}(i, devices[i].Serial)
	}
	wg.Wait()
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
	if len(lines) < 3 {
		return nil
	}
	return map[string]string{
		"ro.product.model":       strings.TrimSpace(lines[0]),
		"ro.product.brand":       strings.TrimSpace(lines[1]),
		"ro.build.version.sdk":   strings.TrimSpace(lines[2]),
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
