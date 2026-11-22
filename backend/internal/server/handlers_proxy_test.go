package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"adb-tool/backend/internal/proxy"
)

func newTestProxyServer(t *testing.T) *Server {
	tempDir, err := os.MkdirTemp("", "server_proxy_test_*")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(tempDir) })

	proxySrv, err := proxy.NewServer(proxy.Config{
		Port:       9988,
		StorageDir: tempDir,
		MaxHistory: 100,
	})
	if err != nil {
		t.Fatalf("failed to create proxy: %v", err)
	}

	return &Server{
		proxyServer: proxySrv,
	}
}

func TestProxyHandlersStatusAndLifecycle(t *testing.T) {
	s := newTestProxyServer(t)

	// Status check
	req := httptest.NewRequest(http.MethodGet, "/api/proxy/status", nil)
	w := httptest.NewRecorder()
	s.handleProxyStatus(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode JSON: %v", err)
	}
	status := resp.Data.(map[string]interface{})
	if status["running"] != false {
		t.Errorf("expected running=false initially")
	}

	// CA cert download
	reqCA := httptest.NewRequest(http.MethodGet, "/api/proxy/ca.crt", nil)
	wCA := httptest.NewRecorder()
	s.handleProxyCACert(wCA, reqCA)

	if wCA.Code != http.StatusOK {
		t.Fatalf("expected 200 for CA download, got %d", wCA.Code)
	}
	if !strings.Contains(wCA.Body.String(), "BEGIN CERTIFICATE") {
		t.Errorf("expected PEM certificate in response")
	}
}

func TestProxyHandlersRulesCRUD(t *testing.T) {
	s := newTestProxyServer(t)

	// Create a rule
	rule := proxy.MockRule{
		Name:       "Test Rule 1",
		Enabled:    true,
		Method:     "GET",
		URLPattern: "/api/test",
		Action:     "mock",
		MockStatus: 200,
		MockBody:   `{"success": true}`,
	}
	bodyBytes, _ := json.Marshal(rule)
	req := httptest.NewRequest(http.MethodPost, "/api/proxy/rules", bytes.NewReader(bodyBytes))
	w := httptest.NewRecorder()
	s.handleProxyRules(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 on create, got %d", w.Code)
	}
	var respCreated apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &respCreated); err != nil {
		t.Fatalf("failed to unmarshal created rule response: %v", err)
	}
	dataBytes, _ := json.Marshal(respCreated.Data)
	var created proxy.MockRule
	if err := json.Unmarshal(dataBytes, &created); err != nil {
		t.Fatalf("failed to unmarshal created rule: %v", err)
	}
	if created.ID == "" || created.Name != "Test Rule 1" {
		t.Errorf("unexpected created rule: %+v", created)
	}

	// List rules
	reqList := httptest.NewRequest(http.MethodGet, "/api/proxy/rules", nil)
	wList := httptest.NewRecorder()
	s.handleProxyRules(wList, reqList)

	var respList apiResponse
	if err := json.Unmarshal(wList.Body.Bytes(), &respList); err != nil {
		t.Fatalf("failed to list rules: %v", err)
	}
	listBytes, _ := json.Marshal(respList.Data)
	var list []proxy.MockRule
	if err := json.Unmarshal(listBytes, &list); err != nil {
		t.Fatalf("failed to parse rule list: %v", err)
	}
	if len(list) != 1 || list[0].ID != created.ID {
		t.Errorf("expected 1 rule with ID %s, got %v", created.ID, list)
	}

	// Delete rule
	reqDel := httptest.NewRequest(http.MethodDelete, "/api/proxy/rules?id="+created.ID, nil)
	wDel := httptest.NewRecorder()
	s.handleProxyRules(wDel, reqDel)

	if wDel.Code != http.StatusOK {
		t.Fatalf("expected 200 on delete, got %d", wDel.Code)
	}

	// Verify empty list
	wList2 := httptest.NewRecorder()
	s.handleProxyRules(wList2, reqList)
	var respList2 apiResponse
	_ = json.Unmarshal(wList2.Body.Bytes(), &respList2)
	listBytes2, _ := json.Marshal(respList2.Data)
	var list2 []proxy.MockRule
	_ = json.Unmarshal(listBytes2, &list2)
	if len(list2) != 0 {
		t.Errorf("expected 0 rules after delete, got %d", len(list2))
	}
}

func TestProxyHandlersSessions(t *testing.T) {
	s := newTestProxyServer(t)

	s.proxyServer.Sessions().Add(&proxy.ProxySession{
		ID:         "sess_1",
		Method:     "GET",
		URL:        "https://example.com/api/v1/test",
		StatusCode: 200,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/proxy/sessions", nil)
	w := httptest.NewRecorder()
	s.handleProxySessions(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var respSessions apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &respSessions); err != nil {
		t.Fatalf("failed to decode sessions envelope: %v", err)
	}
	sessBytes, _ := json.Marshal(respSessions.Data)
	var sessions []*proxy.ProxySession
	if err := json.Unmarshal(sessBytes, &sessions); err != nil {
		t.Fatalf("failed to decode sessions: %v", err)
	}
	if len(sessions) != 1 || sessions[0].ID != "sess_1" {
		t.Errorf("unexpected sessions: %+v", sessions)
	}

	// Clear
	reqClear := httptest.NewRequest(http.MethodPost, "/api/proxy/sessions/clear", nil)
	wClear := httptest.NewRecorder()
	s.handleProxySessionsClear(wClear, reqClear)

	if wClear.Code != http.StatusOK {
		t.Fatalf("expected 200 on clear, got %d", wClear.Code)
	}

	wAfter := httptest.NewRecorder()
	s.handleProxySessions(wAfter, req)
	var respAfter apiResponse
	_ = json.Unmarshal(wAfter.Body.Bytes(), &respAfter)
	afterBytes, _ := json.Marshal(respAfter.Data)
	var after []*proxy.ProxySession
	_ = json.Unmarshal(afterBytes, &after)
	if len(after) != 0 {
		t.Errorf("expected 0 sessions after clear, got %d", len(after))
	}
}
