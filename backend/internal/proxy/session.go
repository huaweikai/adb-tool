package proxy

import (
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ProxySession represents a captured HTTP or HTTPS request and response.
type ProxySession struct {
	ID          string            `json:"id"`
	Timestamp   int64             `json:"timestamp"`
	Method      string            `json:"method"`
	URL         string            `json:"url"`
	Host        string            `json:"host"`
	Path        string            `json:"path"`
	Scheme      string            `json:"scheme"`
	StatusCode  int               `json:"statusCode"`
	StatusText  string            `json:"statusText"`
	DurationMs  int64             `json:"durationMs"`
	ReqHeaders  map[string]string `json:"reqHeaders"`
	ReqBody     string            `json:"reqBody"`
	ReqSize     int64             `json:"reqSize"`
	RespHeaders map[string]string `json:"respHeaders"`
	RespBody    string            `json:"respBody"`
	RespSize    int64             `json:"respSize"`
	IsMocked    bool              `json:"isMocked"`
	MatchedRule string            `json:"matchedRule,omitempty"`
	ClientIP    string            `json:"clientIP"`
}

// SessionStore maintains an in-memory buffer of captured sessions and fan-out notifications.
type SessionStore struct {
	mu          sync.RWMutex
	sessions    []*ProxySession
	maxSessions int
	counter     uint64
	subscribers map[chan *ProxySession]struct{}
}

// NewSessionStore creates a store with a capacity limit.
func NewSessionStore(max int) *SessionStore {
	if max <= 0 {
		max = 1000
	}
	return &SessionStore{
		sessions:    make([]*ProxySession, 0, max),
		maxSessions: max,
		subscribers: make(map[chan *ProxySession]struct{}),
	}
}

// Add appends a session to the store and notifies subscribers.
func (s *SessionStore) Add(session *ProxySession) {
	if session.ID == "" {
		idNum := atomic.AddUint64(&s.counter, 1)
		session.ID = time.Now().Format("150405") + "_" + strings.TrimLeft(string(rune('0'+(idNum%10000))), "\x00")
	}

	s.mu.Lock()
	if len(s.sessions) >= s.maxSessions {
		s.sessions = s.sessions[1:]
	}
	s.sessions = append(s.sessions, session)

	// Fan out to subscribers non-blocking
	for ch := range s.subscribers {
		select {
		case ch <- session:
		default:
		}
	}
	s.mu.Unlock()
}

// Subscribe returns a channel that receives newly captured sessions.
func (s *SessionStore) Subscribe() chan *ProxySession {
	ch := make(chan *ProxySession, 100)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.subscribers[ch] = struct{}{}
	return ch
}

// Unsubscribe removes a listener channel.
func (s *SessionStore) Unsubscribe(ch chan *ProxySession) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.subscribers, ch)
	close(ch)
}

// GetAll returns sessions, optionally filtered and sorted newest-first.
func (s *SessionStore) GetAll(filter string, limit int) []*ProxySession {
	s.mu.RLock()
	defer s.mu.RUnlock()

	filter = strings.ToLower(strings.TrimSpace(filter))
	result := make([]*ProxySession, 0, len(s.sessions))

	// Iterate newest first
	for i := len(s.sessions) - 1; i >= 0; i-- {
		sess := s.sessions[i]
		if filter != "" {
			if !strings.Contains(strings.ToLower(sess.URL), filter) &&
				!strings.Contains(strings.ToLower(sess.Method), filter) &&
				!strings.Contains(strings.ToLower(sess.ClientIP), filter) &&
				!strings.Contains(strings.ToLower(sess.MatchedRule), filter) {
				continue
			}
		}
		result = append(result, sess)
		if limit > 0 && len(result) >= limit {
			break
		}
	}
	return result
}

// GetByID finds a session by ID.
func (s *SessionStore) GetByID(id string) *ProxySession {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, sess := range s.sessions {
		if sess.ID == id {
			return sess
		}
	}
	return nil
}

// Clear removes all captured sessions.
func (s *SessionStore) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessions = make([]*ProxySession, 0, s.maxSessions)
}

// Count returns the number of captured sessions.
func (s *SessionStore) Count() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.sessions)
}
