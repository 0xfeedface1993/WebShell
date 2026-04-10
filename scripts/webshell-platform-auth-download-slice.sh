#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
CLIENT_REPO="$WORKSPACE_ROOT/WebShellClient-Apple"
FIXTURE_SERVER="$CLIENT_REPO/scripts/auth_download_fixture_server.py"
PACKAGE_DIR="$CLIENT_REPO/Packages/WebShellClientKit"

PORT="${WEBSHELL_AUTH_SLICE_PORT:-18080}"
BASE_URL="${WEBSHELL_AUTH_SLICE_BASE_URL:-http://127.0.0.1:${PORT}}"

if [[ ! -f "$FIXTURE_SERVER" ]]; then
  echo "Missing fixture server: $FIXTURE_SERVER" >&2
  exit 1
fi

python3 "$FIXTURE_SERVER" --port "$PORT" >/tmp/webshell-auth-fixture.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

for _ in {1..30}; do
  if curl -sf "$BASE_URL/file-7.html" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

cd "$PACKAGE_DIR"
swift run WebShellClientSmoke auth-download-open --base-url "$BASE_URL"
