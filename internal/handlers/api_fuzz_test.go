package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v5"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// FuzzFindItinerary tests that FindItinerary never panics on adversarial
// 2-segment inputs. Kept as a tight inner-loop fuzz target — the broader
// HTTP-layer fuzz lives in FuzzFlightCalculate below.
func FuzzFindItinerary(f *testing.F) {
	// Seed corpus from existing test cases.
	f.Add("SFO", "EWR", "EWR", "ATL")
	f.Add("ATL", "EWR", "SFO", "ATL")
	f.Add("IND", "EWR", "SFO", "ATL")
	f.Add("", "", "", "")

	f.Fuzz(func(_ *testing.T, s1, d1, s2, d2 string) {
		flights := []api.Flight{
			{Start: s1, End: d1},
			{Start: s2, End: d2},
		}
		_, _, _ = FindItinerary(flights)
	})
}

// FuzzFlightCalculate exercises the bind layer + algorithm together, using
// a single byte-slice input that is JSON-unmarshalled into [][]string. This
// mirrors the production request path so fuzzing surfaces both
// JSON-parsing edge cases and arbitrary-length itinerary shapes — neither
// of which the FuzzFindItinerary 2-segment harness can find.
func FuzzFlightCalculate(f *testing.F) {
	// Seed corpus mirrors the well-known happy and negative shapes.
	f.Add([]byte(`[["SFO","EWR"]]`))
	f.Add([]byte(`[["ATL","EWR"],["SFO","ATL"]]`))
	f.Add([]byte(`[["IND","EWR"],["SFO","ATL"],["GSO","IND"],["ATL","GSO"]]`))
	f.Add([]byte(`[]`))
	f.Add([]byte(`[["A","B"],["C","D"]]`)) // disconnected
	f.Add([]byte(`[["A","B"],["B","A"]]`)) // circular
	f.Add([]byte(`not json`))
	f.Add([]byte(``))

	e := echo.New()
	h := New()

	f.Fuzz(func(t *testing.T, body []byte) {
		// Reject inputs that aren't even superficially shaped like JSON arrays —
		// keeps the fuzzer focused on the call path, not on echo's bind error
		// branches we already cover in unit tests.
		var probe any
		if json.Unmarshal(body, &probe) != nil {
			return
		}
		req := httptest.NewRequestWithContext(context.Background(), http.MethodPost, "/calculate", bytes.NewReader(body))
		req.Header.Set(echo.HeaderContentType, "application/json")
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		// Handler must never panic and must always return a 2xx or 4xx —
		// 5xx would indicate an unhandled internal error.
		if err := h.FlightCalculate(c); err != nil {
			t.Fatalf("handler returned error: %v", err)
		}
		if rec.Code >= 500 {
			t.Fatalf("handler returned 5xx for input %q: %d", body, rec.Code)
		}
	})
}
