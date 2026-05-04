#!/usr/bin/env bash
# Print a free TCP port from the kernel's ephemeral range.
# Binds port 0 (kernel-allocated), reads back the assigned port, releases it.
# There is a small TOCTOU window between this script exiting and the caller
# binding — acceptable for test/CI use, not production. Used by `make e2e`
# to allow parallel runs side-by-side without colliding on a fixed port.
#
# Falls back across implementations because GitHub-Actions runners and
# developer laptops differ in what's installed by default.
set -euo pipefail

# Preferred: Python — present on every Ubuntu image and macOS 12+.
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()'
  exit 0
fi

# Fallback: GNU netcat with -l -p 0. BSD nc on macOS does not support -p,
# so we don't try it — Python covers the macOS path above.
if command -v ss >/dev/null 2>&1; then
  # Pick a high port not in use. 32 attempts to avoid pathological cases.
  for _ in $(seq 1 32); do
    p=$((40000 + RANDOM % 20000))
    if ! ss -tln "sport = :$p" 2>/dev/null | grep -q ":$p"; then
      echo "$p"
      exit 0
    fi
  done
fi

echo "pick-port.sh: no python3 or ss available — install python3 or use a fixed SERVER_PORT" >&2
exit 1
