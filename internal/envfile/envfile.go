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
func Load(path string) error {
	// #nosec G304 -- path is a CLI flag (-env-file) set by the operator;
	// there is no untrusted input reaching this call site.
	f, err := os.Open(path)
	if err != nil {
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
		if key == "" {
			return fmt.Errorf("envfile: %s:%d: empty key", path, lineNo)
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		val = strings.Trim(strings.TrimSpace(val), `"'`)
		if err := os.Setenv(key, val); err != nil {
			return fmt.Errorf("envfile: %s:%d: setenv %s: %w", path, lineNo, key, err)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("envfile: %s: read: %w", path, err)
	}
	return nil
}
