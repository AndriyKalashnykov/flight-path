//go:build integration

// Package app integration tests exercise the full middleware chain end-to-end
// through httptest.NewServer, covering surfaces that bypass the direct handler
// unit tests: CORS branch, Secure headers, Cache-Control, error envelope,
// preflight, and disconnected-graph / circular-path inputs at the HTTP layer.
package app_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"

	"github.com/AndriyKalashnykov/flight-path/internal/app"
)

func newTestServer(t *testing.T, env map[string]string) *httptest.Server {
	t.Helper()
	for k, v := range env {
		t.Setenv(k, v)
	}
	s := httptest.NewServer(app.New())
	t.Cleanup(s.Close)
	return s
}

func do(t *testing.T, req *http.Request) *http.Response {
	t.Helper()
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	return resp
}

func TestHealthCheckSecurityHeaders(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/", nil)))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	wantHeaders := map[string]string{
		"X-Content-Type-Options":       "nosniff",
		"X-Frame-Options":              "DENY",
		"X-XSS-Protection":             "1; mode=block",
		"Referrer-Policy":              "strict-origin-when-cross-origin",
		"Cross-Origin-Resource-Policy": "same-origin",
		"Cache-Control":                "no-store",
	}
	for k, v := range wantHeaders {
		if got := resp.Header.Get(k); got != v {
			t.Errorf("%s: want %q, got %q", k, v, got)
		}
	}
	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["data"] == "" {
		t.Errorf("health body missing non-empty data field: %v", body)
	}
}

func TestCORSDefaultWildcard(t *testing.T) {
	s := newTestServer(t, nil)
	req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
	req.Header.Set("Origin", "https://anywhere.example")
	resp := do(t, req)
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "*" {
		t.Errorf("Access-Control-Allow-Origin: want *, got %q", got)
	}
}

func TestCORSCustomOrigin(t *testing.T) {
	s := newTestServer(t, map[string]string{"CORS_ORIGIN": "https://app.example"})
	req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
	req.Header.Set("Origin", "https://app.example")
	resp := do(t, req)
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "https://app.example" {
		t.Errorf("Access-Control-Allow-Origin: want https://app.example, got %q", got)
	}
}

func TestCORSPreflight(t *testing.T) {
	s := newTestServer(t, nil)
	req := must(http.NewRequest(http.MethodOptions, s.URL+"/calculate", nil))
	req.Header.Set("Origin", "https://app.example")
	req.Header.Set("Access-Control-Request-Method", http.MethodPost)
	req.Header.Set("Access-Control-Request-Headers", "Content-Type")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		t.Errorf("preflight: want 204 or 200, got %d", resp.StatusCode)
	}
	if got := resp.Header.Get("Access-Control-Allow-Methods"); got == "" {
		t.Errorf("preflight missing Access-Control-Allow-Methods")
	}
}

func TestCORSPreflightCustomOrigin(t *testing.T) {
	s := newTestServer(t, map[string]string{"CORS_ORIGIN": "https://app.example"})
	req := must(http.NewRequest(http.MethodOptions, s.URL+"/calculate", nil))
	req.Header.Set("Origin", "https://app.example")
	req.Header.Set("Access-Control-Request-Method", http.MethodPost)
	req.Header.Set("Access-Control-Request-Headers", "Content-Type")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		t.Errorf("preflight: want 204 or 200, got %d", resp.StatusCode)
	}
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "https://app.example" {
		t.Errorf("preflight Access-Control-Allow-Origin: want https://app.example, got %q", got)
	}
}

func TestCalculateHappyPath(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[["SFO","ATL"],["ATL","EWR"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var got []string
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	want := []string{"SFO", "EWR"}
	if !slices.Equal(got, want) {
		t.Errorf("body: want %v, got %v", want, got)
	}
}

func TestCalculateEmptyArray(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	msg, _ := env["Error"].(string)
	if !strings.Contains(strings.ToLower(msg), "empty") {
		t.Errorf("Error: want substring 'empty', got %q", msg)
	}
	if _, hasIndex := env["Index"]; hasIndex {
		t.Errorf("empty-array response should not include Index field, got %v", env)
	}
}

func TestCalculateMalformedJSON(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`not valid json`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	msg, _ := env["Error"].(string)
	if !strings.Contains(strings.ToLower(msg), "parse") {
		t.Errorf("Error: want substring 'parse', got %q", msg)
	}
}

func TestCalculateIncompleteSegmentBody(t *testing.T) {
	s := newTestServer(t, nil)
	// Second segment is incomplete — handler should report Error + Index=1.
	body := bytes.NewBufferString(`[["SFO","EWR"],["JFK"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	msg, _ := env["Error"].(string)
	if !strings.Contains(strings.ToLower(msg), "source and destination") {
		t.Errorf("Error: want substring 'source and destination', got %q", msg)
	}
	idx, ok := env["Index"].(float64) // JSON numbers decode to float64 in map[string]any
	if !ok {
		t.Fatalf("Index: want number, got %T (body: %v)", env["Index"], env)
	}
	if int(idx) != 1 {
		t.Errorf("Index: want 1, got %v", idx)
	}
}

func TestCalculateWrongContentType(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[["SFO","EWR"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "text/plain")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode < 400 || resp.StatusCode >= 500 {
		t.Errorf("want 4xx for text/plain body, got %d", resp.StatusCode)
	}
}

func TestCalculateMethodNotAllowed(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/calculate", nil)))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("want 405, got %d", resp.StatusCode)
	}
}

func TestUnknownRoute(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/does-not-exist", nil)))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

// TestCalculateDisconnectedGraph asserts the documented contract for
// disconnected inputs: the handler rejects them with 400 because no single
// connected itinerary exists.
func TestCalculateDisconnectedGraph(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[["A","B"],["C","D"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("disconnected graph: want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if msg, _ := env["Error"].(string); !strings.Contains(strings.ToLower(msg), "disconnected") {
		t.Errorf("Error: want substring 'disconnected', got %q", msg)
	}
}

// TestCalculateCircularPath asserts that circular inputs (every airport has
// both in- and out-edges) are rejected with 400 — there is no unambiguous
// start/end pair.
func TestCalculateCircularPath(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[["A","B"],["B","A"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("circular path: want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if msg, _ := env["Error"].(string); !strings.Contains(strings.ToLower(msg), "circular") {
		t.Errorf("Error: want substring 'circular', got %q", msg)
	}
}

func TestSwaggerUIRedirect(t *testing.T) {
	s := newTestServer(t, nil)
	client := &http.Client{CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	req := must(http.NewRequest(http.MethodGet, s.URL+"/swagger/", nil))
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusMovedPermanently && resp.StatusCode != http.StatusFound && resp.StatusCode != http.StatusOK {
		t.Errorf("swagger redirect: want 2xx/3xx, got %d", resp.StatusCode)
	}
}

func TestPortDefault(t *testing.T) {
	t.Setenv("SERVER_PORT", "")
	if got := app.Port(); got != "8080" {
		t.Errorf("Port default: want 8080, got %s", got)
	}
}

func TestPortFromEnv(t *testing.T) {
	t.Setenv("SERVER_PORT", "9090")
	if got := app.Port(); got != "9090" {
		t.Errorf("Port from env: want 9090, got %s", got)
	}
}

// TestCalculateEmptyBody covers POSTing with no payload at all (Content-Length: 0).
// Mirrors Newman cases that exercise the bind-failure path through the full
// middleware chain — the unit tests use httptest.NewRecorder and skip middleware.
func TestCalculateEmptyBody(t *testing.T) {
	s := newTestServer(t, nil)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", http.NoBody))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	msg, _ := env["Error"].(string)
	if msg == "" {
		t.Errorf("Error: want non-empty error message, got %q", msg)
	}
}

// TestCalculateObjectRoot mirrors Newman UseCase09: a JSON object root instead
// of an array — must fail bind with a parse-style error.
func TestCalculateObjectRoot(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`{"foo":"bar"}`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("want 400, got %d", resp.StatusCode)
	}
	var env map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	msg, _ := env["Error"].(string)
	if !strings.Contains(strings.ToLower(msg), "parse") {
		t.Errorf("Error: want substring 'parse', got %q", msg)
	}
}

// TestCalculateExtraItemsIgnored mirrors Newman UseCase07: extra elements
// past the second in a segment must be silently ignored — first two used.
func TestCalculateExtraItemsIgnored(t *testing.T) {
	s := newTestServer(t, nil)
	body := bytes.NewBufferString(`[["SFO","EWR","JFK"]]`)
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", body))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var got []string
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	want := []string{"SFO", "EWR"}
	if !slices.Equal(got, want) {
		t.Errorf("body: want %v, got %v", want, got)
	}
}

// TestCalculate100SegmentChain mirrors Newman UseCase13: a scrambled 100-segment
// chain protects against algorithm regressions at scale through the HTTP layer.
// Builds A0→A1→...→A100, scrambles, posts, and asserts start/end.
func TestCalculate100SegmentChain(t *testing.T) {
	s := newTestServer(t, nil)
	const n = 100
	segments := make([][]string, 0, n)
	for i := 0; i < n; i++ {
		segments = append(segments, []string{
			"A" + itoa(i),
			"A" + itoa(i+1),
		})
	}
	// Deterministic scramble: reverse halves and interleave.
	mid := n / 2
	scrambled := make([][]string, 0, n)
	for i := 0; i < mid; i++ {
		scrambled = append(scrambled, segments[mid-1-i])
		scrambled = append(scrambled, segments[n-1-i])
	}
	body, err := json.Marshal(scrambled)
	if err != nil {
		t.Fatalf("marshal segments: %v", err)
	}
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", bytes.NewReader(body)))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var got []string
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	want := []string{"A0", "A" + itoa(n)}
	if !slices.Equal(got, want) {
		t.Errorf("body: want %v, got %v", want, got)
	}
}

// TestSwaggerIndexServesHTML mirrors Newman Swagger_UI: GET /swagger/index.html
// must return HTML containing 'swagger-ui' so the embedded UI bootstraps.
func TestSwaggerIndexServesHTML(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/swagger/index.html", nil)))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	buf := new(bytes.Buffer)
	if _, err := buf.ReadFrom(resp.Body); err != nil {
		t.Fatalf("read body: %v", err)
	}
	if !strings.Contains(buf.String(), "swagger-ui") {
		t.Errorf("body missing 'swagger-ui' marker (first 200 chars): %q", buf.String()[:min(200, buf.Len())])
	}
}

// itoa is a tiny strconv-free helper — keeps the test file's import surface
// to what it already pulls in.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

func must(req *http.Request, err error) *http.Request {
	if err != nil {
		panic(err)
	}
	return req
}

// TestBodyLimitEnforced asserts the BodyLimit("1M") middleware rejects 2 MiB
// bodies with 413, preventing unbounded request memory consumption.
func TestBodyLimitEnforced(t *testing.T) {
	s := newTestServer(t, nil)
	const twoMiB = 2 * 1024 * 1024
	body := make([]byte, twoMiB)
	for i := range body {
		body[i] = 'a'
	}
	req := must(http.NewRequest(http.MethodPost, s.URL+"/calculate", bytes.NewReader(body)))
	req.Header.Set("Content-Type", "application/json")
	resp := do(t, req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Fatalf("want 413 for 2 MiB body, got %d", resp.StatusCode)
	}
}

// TestRequestIDPropagated asserts every response carries an X-Request-ID
// header (RequestID middleware enabled). Two consecutive requests must
// produce different IDs.
func TestRequestIDPropagated(t *testing.T) {
	s := newTestServer(t, nil)
	resp1 := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/", nil)))
	resp1.Body.Close()
	id1 := resp1.Header.Get("X-Request-Id")
	if id1 == "" {
		t.Fatalf("X-Request-Id missing on response 1")
	}
	resp2 := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/", nil)))
	resp2.Body.Close()
	id2 := resp2.Header.Get("X-Request-Id")
	if id2 == "" {
		t.Fatalf("X-Request-Id missing on response 2")
	}
	if id1 == id2 {
		t.Errorf("request IDs should differ between requests, got %q twice", id1)
	}
}

// TestGzipNegotiated asserts that requests with Accept-Encoding: gzip receive
// a gzip-encoded response. The Gzip middleware compresses successful 2xx
// responses transparently.
func TestGzipNegotiated(t *testing.T) {
	s := newTestServer(t, nil)
	req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
	req.Header.Set("Accept-Encoding", "gzip")
	resp := do(t, req)
	defer resp.Body.Close()
	if got := resp.Header.Get("Content-Encoding"); got != "gzip" {
		t.Errorf("Content-Encoding: want gzip, got %q", got)
	}
}

// TestCORSDisallowedOriginNotEchoed asserts that when CORS_ORIGIN restricts
// origins to a specific domain, requests from unrelated origins do not get
// their origin echoed in Access-Control-Allow-Origin.
func TestCORSDisallowedOriginNotEchoed(t *testing.T) {
	s := newTestServer(t, map[string]string{"CORS_ORIGIN": "https://app.example"})
	req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
	req.Header.Set("Origin", "https://evil.example")
	resp := do(t, req)
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got == "https://evil.example" {
		t.Errorf("disallowed origin echoed back: got %q", got)
	}
}

// TestCORSMultiOriginCommaSeparated asserts the CORS_ORIGIN env supports a
// comma-separated allowlist — both listed origins must be echoed back, and
// unlisted origins must not.
func TestCORSMultiOriginCommaSeparated(t *testing.T) {
	s := newTestServer(t, map[string]string{
		"CORS_ORIGIN": "https://app.example, https://admin.example",
	})
	for _, origin := range []string{"https://app.example", "https://admin.example"} {
		req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
		req.Header.Set("Origin", origin)
		resp := do(t, req)
		resp.Body.Close()
		if got := resp.Header.Get("Access-Control-Allow-Origin"); got != origin {
			t.Errorf("origin %q not echoed: got %q", origin, got)
		}
	}
	// Unlisted origin should not be echoed.
	req := must(http.NewRequest(http.MethodGet, s.URL+"/", nil))
	req.Header.Set("Origin", "https://evil.example")
	resp := do(t, req)
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got == "https://evil.example" {
		t.Errorf("unlisted origin echoed: got %q", got)
	}
}

// TestSwaggerJSONSpec asserts the generated Swagger spec is valid JSON and
// describes the /calculate endpoint. Catches regressions where `make api-docs`
// produces a malformed spec that the HTML UI silently fails to render.
func TestSwaggerJSONSpec(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/swagger/doc.json", nil)))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	var spec map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&spec); err != nil {
		t.Fatalf("decode swagger spec: %v", err)
	}
	paths, ok := spec["paths"].(map[string]any)
	if !ok {
		t.Fatalf("swagger spec missing paths: %v", spec)
	}
	if _, ok := paths["/calculate"]; !ok {
		keys := make([]string, 0, len(paths))
		for k := range paths {
			keys = append(keys, k)
		}
		t.Errorf("swagger spec missing /calculate path; have: %v", keys)
	}
}

// TestHealthCheckBodyContract locks the exact health response shape so future
// drift is caught by tests rather than by Newman in production.
func TestHealthCheckBodyContract(t *testing.T) {
	s := newTestServer(t, nil)
	resp := do(t, must(http.NewRequest(http.MethodGet, s.URL+"/", nil)))
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	got, _ := body["data"].(string)
	if got != "Server is up and running" {
		t.Errorf("data: want %q, got %q", "Server is up and running", got)
	}
}
