package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v5"
)

func TestServerHealthCheck(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", http.NoBody)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := New()
	err := h.ServerHealthCheck(c)
	if err != nil {
		t.Fatalf("handler returned error: %v", err)
	}

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body map[string]any
	if jsonErr := json.Unmarshal(rec.Body.Bytes(), &body); jsonErr != nil {
		t.Fatalf("failed to unmarshal response: %v", jsonErr)
	}

	data, ok := body["data"]
	if !ok {
		t.Fatal("response missing 'data' key")
	}

	if data != "Server is up and running" {
		t.Errorf("data = %q, want %q", data, "Server is up and running")
	}
}
