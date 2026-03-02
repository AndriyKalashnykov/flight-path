package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo/v5"
)

func TestFlightCalculate(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		wantStatus int
		wantStart  string
		wantEnd    string
	}{
		{
			name:       "single segment SFO to EWR",
			body:       `[["SFO", "EWR"]]`,
			wantStatus: http.StatusOK,
			wantStart:  "SFO",
			wantEnd:    "EWR",
		},
		{
			name:       "two segments SFO to EWR",
			body:       `[["ATL", "EWR"], ["SFO", "ATL"]]`,
			wantStatus: http.StatusOK,
			wantStart:  "SFO",
			wantEnd:    "EWR",
		},
		{
			name:       "four segments SFO to EWR",
			body:       `[["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]`,
			wantStatus: http.StatusOK,
			wantStart:  "SFO",
			wantEnd:    "EWR",
		},
		{
			name:       "empty array returns 400",
			body:       `[]`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "segment with less than 2 elements returns 400",
			body:       `[["SFO"]]`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "malformed JSON returns 400",
			body:       `not json`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "empty body returns 400",
			body:       ``,
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodPost, "/calculate", strings.NewReader(tt.body))
			req.Header.Set(echo.HeaderContentType, "application/json")
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			h := New()
			err := h.FlightCalculate(c)
			if err != nil {
				t.Fatalf("handler returned error: %v", err)
			}

			if rec.Code != tt.wantStatus {
				t.Errorf("status = %d, want %d, body = %s", rec.Code, tt.wantStatus, rec.Body.String())
			}

			if tt.wantStatus == http.StatusOK {
				var got []string
				if jsonErr := json.Unmarshal(rec.Body.Bytes(), &got); jsonErr != nil {
					t.Fatalf("failed to unmarshal response: %v", jsonErr)
				}
				if len(got) != 2 || got[0] != tt.wantStart || got[1] != tt.wantEnd {
					t.Errorf("response = %v, want [%s, %s]", got, tt.wantStart, tt.wantEnd)
				}
			}
		})
	}
}
