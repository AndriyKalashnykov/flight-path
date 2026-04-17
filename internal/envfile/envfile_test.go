package envfile

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad(t *testing.T) {
	// Using FP_TEST_* keys so the tests don't collide with real flight-path
	// configuration if the binary and tests share a process (they don't today,
	// but the prefix keeps future refactors safe).
	tests := []struct {
		name    string
		content string
		preset  map[string]string
		want    map[string]string
		wantErr bool
	}{
		{
			name:    "single key=value pair",
			content: "FP_TEST_FOO=bar\n",
			want:    map[string]string{"FP_TEST_FOO": "bar"},
		},
		{
			name:    "comments and blank lines are skipped",
			content: "# header\n\nFP_TEST_FOO=bar\n# mid\nFP_TEST_BAZ=qux\n\n",
			want:    map[string]string{"FP_TEST_FOO": "bar", "FP_TEST_BAZ": "qux"},
		},
		{
			name:    "whitespace around equals is trimmed",
			content: "  FP_TEST_FOO = bar  \n",
			want:    map[string]string{"FP_TEST_FOO": "bar"},
		},
		{
			name:    "double-quoted values are unquoted",
			content: `FP_TEST_FOO="bar baz"` + "\n",
			want:    map[string]string{"FP_TEST_FOO": "bar baz"},
		},
		{
			name:    "single-quoted values are unquoted",
			content: `FP_TEST_FOO='bar baz'` + "\n",
			want:    map[string]string{"FP_TEST_FOO": "bar baz"},
		},
		{
			name:    "preset env vars are preserved (no overwrite)",
			content: "FP_TEST_FOO=filevalue\n",
			preset:  map[string]string{"FP_TEST_FOO": "presetvalue"},
			want:    map[string]string{"FP_TEST_FOO": "presetvalue"},
		},
		{
			name:    "missing equals is an error",
			content: "FP_TEST_NOEQUALS\n",
			wantErr: true,
		},
		{
			name:    "empty key is an error",
			content: "=value\n",
			wantErr: true,
		},
		{
			name:    "end-of-file without trailing newline parses",
			content: "FP_TEST_FOO=bar",
			want:    map[string]string{"FP_TEST_FOO": "bar"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), ".env")
			if err := os.WriteFile(path, []byte(tc.content), 0o600); err != nil {
				t.Fatalf("write fixture: %v", err)
			}

			// Ensure every key we care about starts unset. t.Setenv captures the
			// prior value and restores it at cleanup, so subtests are isolated.
			for k := range tc.want {
				t.Setenv(k, "")
				_ = os.Unsetenv(k)
			}
			for k, v := range tc.preset {
				t.Setenv(k, v)
			}

			err := Load(path)
			if tc.wantErr {
				if err == nil {
					t.Fatal("want error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			for k, want := range tc.want {
				if got := os.Getenv(k); got != want {
					t.Errorf("%s = %q, want %q", k, got, want)
				}
			}
		})
	}
}

func TestLoadFileNotFound(t *testing.T) {
	if err := Load(filepath.Join(t.TempDir(), "does-not-exist.env")); err == nil {
		t.Fatal("want error for missing file, got nil")
	}
}
