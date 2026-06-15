package server

import (
	"context"
	"strings"
	"time"
)

func (m *AdbManager) Devices() ([]Device, error) {
	return m.DevicesContext(context.Background())
}

func (m *AdbManager) DevicesContext(ctx context.Context) ([]Device, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	out, err := m.runRawContext(ctx, "devices", "-l")
	if err != nil {
		return nil, err
	}

	var devices []Device
	lines := strings.Split(out, "\n")
	for _, line := range lines {
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

		device := Device{Serial: serial, State: state}

		if state == "device" {
			props, err := m.devicePropsContext(ctx, serial)
			if err == nil {
				device.Model = props["ro.product.model"]
				device.Brand = props["ro.product.brand"]
				device.SDK = props["ro.build.version.sdk"]
			}
		}

		devices = append(devices, device)
	}

	return devices, nil
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
	return m.devicePropsContext(context.Background(), serial)
}

func (m *AdbManager) devicePropsContext(ctx context.Context, serial string) (map[string]string, error) {
	out, err := m.runRawContext(ctx, "-s", serial, "shell", "getprop")
	if err != nil {
		return nil, err
	}
	props := make(map[string]string)
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "[ro.product") && !strings.HasPrefix(line, "[ro.build.version.sdk") {
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
