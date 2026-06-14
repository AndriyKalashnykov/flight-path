// Package envfile loads KEY=VALUE pairs from a .env-style file into the
// process environment. It replaces the previously used github.com/joho/godotenv
// dependency: flight-path's .env contains a single variable (SERVER_PORT), and
// godotenv's last release was v1.5.1 in February 2023, so the external
// dependency no longer justified its weight.
//
// Syntax accepted:
//
//	# comments on their own line are ignored
//	KEY=value
//	KEY = value            (whitespace around '=' is trimmed)
//	KEY="quoted value"     (outer single or double quotes are stripped)
//	export KEY=value       (a leading "export " prefix is stripped)
//	KEY=value # comment     (an inline comment after whitespace is stripped
//	                         from UNQUOTED values; '#' inside quotes is kept)
//	                       (blank lines are ignored)
//
// Already-set variables are NOT overwritten, which matches godotenv's default
// and lets callers (tests, containers, shells) override file values.
package envfile

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// Load parses the file at path and calls os.Setenv for each non-comment
// KEY=VALUE line whose key is not already defined in the process environment.
//
// A missing file is treated as a no-op (returns nil) — env vars can also come
// from the OS environment, docker `-e` flags, or `--env-file` host injection,
// so the file is an optional override, not a hard requirement. Other I/O
// errors (permission denied, malformed lines) still return an error.
func Load(path string) error {
	// #nosec G304 -- path is a CLI flag (-env-file) set by the operator;
	// there is no untrusted input reaching this call site.
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("envfile: open %s: %w", path, err)
	}
	defer func() { _ = f.Close() }()

	scanner := bufio.NewScanner(f)
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			return fmt.Errorf("envfile: %s:%d: missing '='", path, lineNo)
		}
		key = strings.TrimSpace(key)
		// Strip an optional "export " prefix (common in shell-sourced files).
		if rest, found := strings.CutPrefix(key, "export "); found {
			key = strings.TrimSpace(rest)
		}
		if key == "" {
			return fmt.Errorf("envfile: %s:%d: empty key", path, lineNo)
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		val = parseValue(val)
		if err := os.Setenv(key, val); err != nil {
			return fmt.Errorf("envfile: %s:%d: setenv %s: %w", path, lineNo, key, err)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("envfile: %s: read: %w", path, err)
	}
	return nil
}

// parseValue normalizes a raw value: it strips surrounding whitespace, then
// either removes outer single/double quotes (preserving any '#' inside) or, for
// an unquoted value, drops an inline comment introduced by whitespace + '#'.
// A bare '#' with no preceding whitespace (e.g. a literal "pa#ss") is kept.
func parseValue(raw string) string {
	v := strings.TrimSpace(raw)
	if v == "" {
		return ""
	}
	if v[0] == '"' || v[0] == '\'' {
		return strings.Trim(v, `"'`)
	}
	if v[0] == '#' {
		return ""
	}
	if i := strings.IndexAny(v, " \t"); i >= 0 {
		// Look for a '#' that begins a comment after the first whitespace run.
		if c := strings.Index(v[i:], "#"); c >= 0 {
			v = v[:i+c]
		}
	}
	return strings.TrimSpace(v)
}
