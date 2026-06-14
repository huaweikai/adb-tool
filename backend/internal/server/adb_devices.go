package server

import "strings"

func (m *AdbManager) Devices() ([]Device, error) {
	out, err := m.run("devices", "-l")
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

		props, err := m.deviceProps(serial)
		if err == nil {
			device.Model = props["ro.product.model"]
			device.Brand = props["ro.product.brand"]
			device.SDK = props["ro.build.version.sdk"]
		}

		devices = append(devices, device)
	}

	return devices, nil
}

func parseDeviceLine(line string) (string, string, bool) {
	fields := strings.Fields(line)
	for _, state := range []string{"device", "offline", "unauthorized", "recovery", "sideload", "bootloader", "host", "no permissions"} {
		marker := "\t" + state
		if idx := strings.Index(line, marker); idx > 0 {
			return strings.TrimSpace(line[:idx]), state, true
		}
		marker = " " + state
		if idx := strings.Index(line, marker); idx > 0 {
			return strings.TrimSpace(line[:idx]), state, true
		}
	}
	if len(fields) >= 2 {
		return fields[0], fields[1], true
	}
	return "", "", false
}

func (m *AdbManager) deviceProps(serial string) (map[string]string, error) {
	out, err := m.run("-s", serial, "shell", "getprop")
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
