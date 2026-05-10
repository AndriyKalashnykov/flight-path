#!/usr/bin/env bash
# Wait for the server to become healthy.
# Usage: wait-for-server.sh [url] [max_seconds]
#
# When called without arguments, builds the URL from environment variables:
#   SERVER_HOST (default: localhost)
#   SERVER_PORT (default: 8080)
# This keeps the host/port out of the script's literal source — the same
# defaults that flow through .env and the Makefile flow through this poller.
set -euo pipefail

DEFAULT_HOST="${SERVER_HOST:-localhost}"
DEFAULT_PORT="${SERVER_PORT:-8080}"
DEFAULT_URL="http://${DEFAULT_HOST}:${DEFAULT_PORT}/"

URL="${1:-$DEFAULT_URL}"
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
