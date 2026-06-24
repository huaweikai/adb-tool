package emulator

import (
	"fmt"
	"net"
	"sync"
)

// PortAllocator manages console and ADB ports for emulator instances.
// Emulator ports come in pairs: console port (5554, 5556, ...) and ADB port (5555, 5557, ...).
type PortAllocator struct {
	mu          sync.Mutex
	baseConsole int // base console port (must be even, defaults to 5554)
	baseADB     int // base ADB port (must be odd, defaults to 5555)
	inUse       map[int]bool // track in-use ports
}

func NewPortAllocator() *PortAllocator {
	return &PortAllocator{
		baseConsole: 5554,
		baseADB:     5555,
		inUse:       make(map[int]bool),
	}
}

// Allocate finds a free console/adb port pair and marks them as in use.
func (p *PortAllocator) Allocate() (consolePort, adbPort int, err error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	consolePort = p.baseConsole
	adbPort = p.baseADB

	// Scan for free ports starting from base
	maxAttempts := 100 // max 100 pairs (200 ports total)
	for attempt := 0; attempt < maxAttempts; attempt++ {
		consolePort = p.baseConsole + (attempt * 2)
		adbPort = p.baseADB + (attempt * 2)

		if !p.inUse[consolePort] && !p.inUse[adbPort] {
			if !p.isPortInUse(consolePort) && !p.isPortInUse(adbPort) {
				p.inUse[consolePort] = true
				p.inUse[adbPort] = true
				return consolePort, adbPort, nil
			}
		}
	}

	return 0, 0, fmt.Errorf("no available ports in range %d-%d", p.baseConsole, consolePort)
}

// Release marks the console/adb port pair as available.
func (p *PortAllocator) Release(consolePort, adbPort int) {
	p.mu.Lock()
	defer p.mu.Unlock()

	delete(p.inUse, consolePort)
	delete(p.inUse, adbPort)
}

// IsInUse checks if a specific port is currently allocated.
func (p *PortAllocator) IsInUse(consolePort, adbPort int) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.inUse[consolePort] || p.inUse[adbPort]
}

// isPortInUse checks if a TCP port is currently bound.
func (p *PortAllocator) isPortInUse(port int) bool {
	addr := fmt.Sprintf(":%d", port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return true // port is in use or not accessible
	}
	listener.Close()
	return false
}

// GetSerial returns the emulator serial for a given port pair.
func GetSerial(consolePort int) string {
	return fmt.Sprintf("emulator-%d", consolePort)
}
