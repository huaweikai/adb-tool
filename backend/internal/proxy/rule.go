package proxy

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

// MockRule represents a user-configured rule to mock or rewrite HTTP/HTTPS responses.
type MockRule struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Enabled     bool              `json:"enabled"`
	Method      string            `json:"method"`      // "GET", "POST", etc. (empty string means any)
	URLPattern  string            `json:"urlPattern"`  // Substring or regex pattern
	IsRegex     bool              `json:"isRegex"`     // True if urlPattern is regex
	Action      string            `json:"action"`      // "mock" or "rewrite"
	MockStatus  int               `json:"mockStatus"`  // HTTP status code (e.g. 200, 403, 500)
	MockHeaders map[string]string `json:"mockHeaders"` // e.g. {"Content-Type": "application/json"}
	MockBody    string            `json:"mockBody"`    // Custom response body content
	FindText    string            `json:"findText"`    // For "rewrite": substring to find
	ReplaceText string            `json:"replaceText"` // For "rewrite": replacement string
	NewStatus   int               `json:"newStatus"`   // For "rewrite": optional new status code (0 to keep original)
	CreatedAt   int64             `json:"createdAt"`
	UpdatedAt   int64             `json:"updatedAt"`

	// compiled regex cache
	compiledRegex *regexp.Regexp
}

// RuleStore manages mock and rewrite rules with thread safety and disk persistence.
type RuleStore struct {
	mu       sync.RWMutex
	rules    []*MockRule
	filePath string
}

// NewRuleStore creates or loads a rule store from the given directory.
func NewRuleStore(storageDir string) *RuleStore {
	store := &RuleStore{
		filePath: filepath.Join(storageDir, "mock_rules.json"),
		rules:    make([]*MockRule, 0),
	}
	_ = store.load()
	return store
}

func (s *RuleStore) load() error {
	data, err := os.ReadFile(s.filePath)
	if err != nil {
		return err
	}
	var rules []*MockRule
	if err := json.Unmarshal(data, &rules); err != nil {
		return err
	}
	for _, r := range rules {
		if r.IsRegex && r.URLPattern != "" {
			if re, err := regexp.Compile(r.URLPattern); err == nil {
				r.compiledRegex = re
			}
		}
	}
	s.rules = rules
	return nil
}

func (s *RuleStore) save() error {
	data, err := json.MarshalIndent(s.rules, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.filePath, data, 0644)
}

// GetAll returns a copy of all configured rules.
func (s *RuleStore) GetAll() []*MockRule {
	s.mu.RLock()
	defer s.mu.RUnlock()
	res := make([]*MockRule, len(s.rules))
	copy(res, s.rules)
	return res
}

// Save adds or updates a rule.
func (s *RuleStore) Save(rule *MockRule) *MockRule {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UnixMilli()
	if rule.ID == "" {
		rule.ID = "rule_" + time.Now().Format("20060102150405") + "_" + randomString(6)
		rule.CreatedAt = now
	}
	rule.UpdatedAt = now

	if rule.IsRegex && rule.URLPattern != "" {
		if re, err := regexp.Compile(rule.URLPattern); err == nil {
			rule.compiledRegex = re
		}
	}

	found := false
	for i, r := range s.rules {
		if r.ID == rule.ID {
			s.rules[i] = rule
			found = true
			break
		}
	}
	if !found {
		s.rules = append(s.rules, rule)
	}
	_ = s.save()
	return rule
}

// Delete removes a rule by ID.
func (s *RuleStore) Delete(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := -1
	for i, r := range s.rules {
		if r.ID == id {
			idx = i
			break
		}
	}
	if idx == -1 {
		return false
	}
	s.rules = append(s.rules[:idx], s.rules[idx+1:]...)
	_ = s.save()
	return true
}

// Match finds the first enabled rule matching the given HTTP method and full URL.
func (s *RuleStore) Match(method, reqURL string) *MockRule {
	s.mu.RLock()
	defer s.mu.RUnlock()

	method = strings.ToUpper(strings.TrimSpace(method))
	for _, rule := range s.rules {
		if !rule.Enabled {
			continue
		}
		if rule.Method != "" && strings.ToUpper(rule.Method) != method {
			continue
		}
		if rule.IsRegex {
			if rule.compiledRegex != nil && rule.compiledRegex.MatchString(reqURL) {
				return rule
			}
		} else {
			if strings.Contains(reqURL, rule.URLPattern) {
				return rule
			}
		}
	}
	return nil
}

func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
		time.Sleep(1 * time.Nanosecond)
	}
	return string(b)
}
