#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
ADMIN_REPO="$WORKSPACE_ROOT/WebShellAdmin-macOS"
CLIENT_REPO="$WORKSPACE_ROOT/WebShellClient-Apple"
CONTROL_REPO="$WORKSPACE_ROOT/WebShellControlPlane"
ADMIN_PACKAGE_DIR="$ADMIN_REPO/Packages/WebShellAdminKit"
CLIENT_PACKAGE_DIR="$CLIENT_REPO/Packages/WebShellClientKit"
FIXTURE_SERVER="$CLIENT_REPO/scripts/auth_download_fixture_server.py"

DATABASE_NAME="${WEBSHELL_CONTROL_PLANE_DATABASE_NAME:-webshell_control_plane}"
DATABASE_USERNAME="${WEBSHELL_CONTROL_PLANE_DATABASE_USERNAME:-yorl}"
DATABASE_PASSWORD="${WEBSHELL_CONTROL_PLANE_DATABASE_PASSWORD:-}"
CONTROL_PORT="${WEBSHELL_X3_CONTROL_PORT:-8089}"
AUTH_PORT="${WEBSHELL_X3_AUTH_PORT:-18081}"
CONTROL_PLANE_BASE_URL="${WEBSHELL_X3_CONTROL_PLANE_BASE_URL:-http://127.0.0.1:${CONTROL_PORT}}"
AUTH_BASE_URL="${WEBSHELL_X3_AUTH_BASE_URL:-http://127.0.0.1:${AUTH_PORT}}"
TARGET_GROUP="${WEBSHELL_X3_TARGET_GROUP:-x3-operator-$(date +%s)}"
BUNDLE_VERSION="${WEBSHELL_X3_BUNDLE_VERSION:-x3.operator.$(date +%s)}"
RUN_DIR="${WEBSHELL_X3_RUN_DIR:-/tmp/webshell-x3-operator-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$RUN_DIR"

if [[ ! -f "$FIXTURE_SERVER" ]]; then
  echo "Missing fixture server: $FIXTURE_SERVER" >&2
  exit 1
fi

wait_for_http() {
  local url="$1"
  local timeout="${2:-30}"
  local elapsed=0
  until curl -sf "$url" >/dev/null 2>&1; do
    sleep 1
    elapsed=$((elapsed + 1))
    if (( elapsed >= timeout )); then
      echo "Timed out waiting for $url" >&2
      return 1
    fi
  done
}

cleanup() {
  if [[ -n "${CONTROL_PID:-}" ]]; then
    kill "$CONTROL_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${FIXTURE_PID:-}" ]]; then
    kill "$FIXTURE_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cat >"$RUN_DIR/context.txt" <<EOF
control_plane_base_url=$CONTROL_PLANE_BASE_URL
auth_base_url=$AUTH_BASE_URL
target_group=$TARGET_GROUP
bundle_version=$BUNDLE_VERSION
database_name=$DATABASE_NAME
EOF

python3 "$FIXTURE_SERVER" --port "$AUTH_PORT" >"$RUN_DIR/auth-fixture.log" 2>&1 &
FIXTURE_PID=$!
wait_for_http "$AUTH_BASE_URL/file-7.html" 30

cd "$CONTROL_REPO"
DATABASE_USERNAME="$DATABASE_USERNAME" \
DATABASE_PASSWORD="$DATABASE_PASSWORD" \
DATABASE_NAME="$DATABASE_NAME" \
PORT="$CONTROL_PORT" \
swift run WebShellControlPlane migrate -y >"$RUN_DIR/migrate.log" 2>&1

APNS_ENABLED=false \
DATABASE_USERNAME="$DATABASE_USERNAME" \
DATABASE_PASSWORD="$DATABASE_PASSWORD" \
DATABASE_NAME="$DATABASE_NAME" \
PORT="$CONTROL_PORT" \
swift run WebShellControlPlane serve --hostname 127.0.0.1 --port "$CONTROL_PORT" >"$RUN_DIR/control-plane.log" 2>&1 &
CONTROL_PID=$!

wait_for_http "$CONTROL_PLANE_BASE_URL/devices" 60

cd "$ADMIN_PACKAGE_DIR"
swift run WebShellAdminSmoke publish-local-auth-bundle \
  --control-plane-url "$CONTROL_PLANE_BASE_URL" \
  --base-url "$AUTH_BASE_URL" \
  --target-group "$TARGET_GROUP" \
  --note "WebShell X3 operator slice" \
  --bundle-version "$BUNDLE_VERSION" \
  >"$RUN_DIR/admin-publish.log" 2>&1

PUBLISHED_VERSION="$(awk '/ADMIN_PUBLISHED_BUNDLE_VERSION/ {print $2}' "$RUN_DIR/admin-publish.log" | tail -n 1)"
if [[ "$PUBLISHED_VERSION" != "$BUNDLE_VERSION" ]]; then
  echo "Expected Admin to publish $BUNDLE_VERSION, got ${PUBLISHED_VERSION:-<missing>}." >&2
  exit 1
fi

cd "$CLIENT_PACKAGE_DIR"
WEBSHELL_CONTROL_PLANE_BASE_URL="$CONTROL_PLANE_BASE_URL" \
WEBSHELL_DEVICE_TARGET_GROUP="$TARGET_GROUP" \
WEBSHELL_CLIENT_APP_VERSION="x3-operator" \
swift run WebShellClientSmoke operator-auth-download-open \
  --control-plane-url "$CONTROL_PLANE_BASE_URL" \
  --base-url "$AUTH_BASE_URL" \
  >"$RUN_DIR/macos-client.log" 2>&1

CLIENT_SYNCED_VERSION="$(awk -F'bundle_version=' '/MACOS_CLIENT_SYNCED/ {print $2}' "$RUN_DIR/macos-client.log" | tail -n 1)"
if [[ "$CLIENT_SYNCED_VERSION" != "$BUNDLE_VERSION" ]]; then
  echo "Expected macOS client to sync $BUNDLE_VERSION, got ${CLIENT_SYNCED_VERSION:-<missing>}." >&2
  exit 1
fi

DEVICE_SUMMARY="$(
  curl -sf "$CONTROL_PLANE_BASE_URL/devices" | python3 -c '
import json, sys
devices = json.load(sys.stdin)
target_group = sys.argv[1]
for device in devices:
    if device.get("targetGroup") == target_group and device.get("appVersion") == "x3-operator":
        print(json.dumps(device, ensure_ascii=False))
        break
' "$TARGET_GROUP"
)"

echo "X3_OPERATOR_SLICE_OK target_group=$TARGET_GROUP bundle_version=$BUNDLE_VERSION"
echo "X3_ADMIN_RELEASE $(tr '\n' ';' < "$RUN_DIR/admin-publish.log")"
echo "X3_MACOS_CLIENT $(tr '\n' ';' < "$RUN_DIR/macos-client.log")"
echo "X3_DEVICE $DEVICE_SUMMARY"
echo "X3_RUN_DIR $RUN_DIR"
