package emulator

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// StatusMonitor broadcasts emulator status updates via WebSocket.
type StatusMonitor struct {
	instanceManager *InstanceManager
	clients         map[*websocket.Conn]map[string]bool // conn -> instance IDs to watch
	mu              sync.RWMutex
	broadcast       chan StatusUpdate
	stop            chan struct{}
}

// StatusUpdate represents a status change notification.
type StatusUpdate struct {
	Type      string       `json:"type"` // "status", "log", "metrics"
	InstanceID string      `json:"instanceId"`
	Status    InstanceStatus `json:"status,omitempty"`
	Message   string       `json:"message,omitempty"`
	Timestamp time.Time    `json:"timestamp"`
	Data      interface{}  `json:"data,omitempty"`
}

// NewStatusMonitor creates a new status monitor.
func NewStatusMonitor(instanceManager *InstanceManager) *StatusMonitor {
	sm := &StatusMonitor{
		instanceManager: instanceManager,
		clients:         make(map[*websocket.Conn]map[string]bool),
		broadcast:       make(chan StatusUpdate, 100),
		stop:            make(chan struct{}),
	}

	// Start status polling goroutine
	go sm.pollStatus()

	return sm
}

// Register registers a WebSocket connection to receive status updates.
func (sm *StatusMonitor) Register(conn *websocket.Conn, instanceIDs []string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	watchMap := make(map[string]bool)
	for _, id := range instanceIDs {
		watchMap[id] = true
	}
	sm.clients[conn] = watchMap
}

// Unregister removes a WebSocket connection.
func (sm *StatusMonitor) Unregister(conn *websocket.Conn) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	delete(sm.clients, conn)
}

// SendUpdate sends a status update to all watching clients.
func (sm *StatusMonitor) SendUpdate(update StatusUpdate) {
	select {
	case sm.broadcast <- update:
	default:
		// Channel full, skip
	}
}

// BroadcastStatus broadcasts a status change to all watching clients.
func (sm *StatusMonitor) BroadcastStatus(instanceID string, status InstanceStatus) {
	sm.SendUpdate(StatusUpdate{
		Type:       "status",
		InstanceID: instanceID,
		Status:     status,
		Timestamp:  time.Now(),
	})
}

// BroadcastLog sends a log message to watching clients.
func (sm *StatusMonitor) BroadcastLog(instanceID, message string) {
	sm.SendUpdate(StatusUpdate{
		Type:       "log",
		InstanceID: instanceID,
		Message:    message,
		Timestamp:  time.Now(),
	})
}

// pollStatus periodically checks instance status and broadcasts updates.
func (sm *StatusMonitor) pollStatus() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sm.stop:
			return
		case <-ticker.C:
			sm.checkAndBroadcastStatus()
		}
	}
}

// checkAndBroadcastStatus checks all instances and broadcasts changes.
func (sm *StatusMonitor) checkAndBroadcastStatus() {
	instances := sm.instanceManager.List()

	sm.mu.RLock()
	// Check each client's watched instances
	for conn, watchMap := range sm.clients {
		for _, inst := range instances {
			if watchMap[inst.ID] || watchMap["*"] { // "*" means watch all
				update := StatusUpdate{
					Type:       "status",
					InstanceID: inst.ID,
					Status:     inst.Status,
					Timestamp:  time.Now(),
					Data: map[string]interface{}{
						"pid":       inst.PID,
						"serial":    inst.Serial,
						"lastStart": inst.LastStartedAt,
					},
				}
				if err := sm.writeJSON(conn, update); err != nil {
					// Connection error, will be cleaned up
					go sm.Unregister(conn)
				}
			}
		}
	}
	sm.mu.RUnlock()
}

// writeJSON writes a JSON message to the WebSocket.
func (sm *StatusMonitor) writeJSON(conn *websocket.Conn, update StatusUpdate) error {
	return conn.WriteJSON(update)
}

// Stop stops the status monitor.
func (sm *StatusMonitor) Stop() {
	close(sm.stop)
}

// EmulatorMetrics holds performance metrics for an emulator instance.
type EmulatorMetrics struct {
	InstanceID    string    `json:"instanceId"`
	CPUUsage      float64   `json:"cpuUsage"`
	MemoryUsageMB int      `json:"memoryUsageMb"`
	MemoryTotalMB int      `json:"memoryTotalMb"`
	DiskUsageMB   int      `json:"diskUsageMb"`
	NetworkRxKB   int64    `json:"networkRxKb"`
	NetworkTxKB   int64    `json:"networkTxKb"`
	FrameRate     int       `json:"frameRate"`
	Timestamp    time.Time `json:"timestamp"`
}

// GetMetrics returns current metrics for an instance.
func (sm *StatusMonitor) GetMetrics(instanceID string) (*EmulatorMetrics, error) {
	inst, err := sm.instanceManager.Get(instanceID)
	if err != nil {
		return nil, err
	}

	if inst.PID <= 0 {
		return nil, fmt.Errorf("instance not running")
	}

	metrics := &EmulatorMetrics{
		InstanceID: instanceID,
		Timestamp:  time.Now(),
	}

	// Get metrics using platform-specific commands
	metrics.MemoryTotalMB = inst.Config.MemoryMB

	// Note: Full metrics collection would require platform-specific code
	// For now, return basic info

	return metrics, nil
}

// MarshalJSON implements json.Marshaler for StatusUpdate.
func (s StatusUpdate) MarshalJSON() ([]byte, error) {
	type Alias StatusUpdate
	return json.Marshal(&struct {
		Alias
		Timestamp string `json:"timestamp"`
	}{
		Alias:     Alias(s),
		Timestamp: s.Timestamp.Format(time.RFC3339),
	})
}
