#!/usr/bin/env bash
# Wait for the server to become healthy.
# Usage: wait-for-server.sh [url] [max_seconds]
set -euo pipefail

URL="${1:-http://localhost:8080/}"
MAX="${2:-30}"

for _ in $(seq 1 "$MAX"); do
  if curl -sf "$URL" >/dev/null 2>&1; then
    echo "Server is up at $URL"
    exit 0
  fi
  sleep 1
done

echo "Server failed to start within ${MAX}s at $URL" >&2
exit 1
