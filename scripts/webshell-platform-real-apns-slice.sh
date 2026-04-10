#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
CLIENT_REPO="$WORKSPACE_ROOT/WebShellClient-Apple"
CONTROL_REPO="$WORKSPACE_ROOT/WebShellControlPlane"
PACKAGE_DIR="$CLIENT_REPO/Packages/WebShellClientKit"

DEVICE_UDID="${WEBSHELL_IOS_DEVICE_UDID:-00008027-000939693422002E}"
TEAM_ID="${WEBSHELL_IOS_TEAM_ID:-N39GRU244C}"
BUNDLE_ID="${WEBSHELL_IOS_BUNDLE_ID:-com.groovy.CloudDownloader}"
APNS_TOPIC="${WEBSHELL_APNS_TOPIC:-$BUNDLE_ID}"
APNS_KEY_ID="${WEBSHELL_APNS_KEY_ID:-VFWK7HX6G5}"
APNS_TEAM_ID="${WEBSHELL_APNS_TEAM_ID:-$TEAM_ID}"
DATABASE_NAME="${WEBSHELL_CONTROL_PLANE_DATABASE_NAME:-webshell_control_plane}"
DATABASE_USERNAME="${WEBSHELL_CONTROL_PLANE_DATABASE_USERNAME:-yorl}"
DATABASE_PASSWORD="${WEBSHELL_CONTROL_PLANE_DATABASE_PASSWORD:-}"
PORT="${WEBSHELL_CONTROL_PLANE_PORT:-8088}"
HOST_INTERFACE="${WEBSHELL_HOST_INTERFACE:-en0}"
HOST_IP="${WEBSHELL_HOST_IP:-}"
HOST_IPV6="${WEBSHELL_HOST_IPV6:-}"
TARGET_GROUP="${WEBSHELL_DEVICE_TARGET_GROUP:-apns-slice-$(date +%s)}"
DERIVED_DATA="${WEBSHELL_IOS_DERIVED_DATA:-/tmp/WebShellClientApple-real-apns}"
RUN_DIR="${WEBSHELL_REAL_APNS_RUN_DIR:-/tmp/webshell-real-apns-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$RUN_DIR"

discover_p8_path() {
  if [[ -n "${WEBSHELL_APNS_P8_PATH:-}" ]]; then
    echo "$WEBSHELL_APNS_P8_PATH"
    return
  fi

  local candidate
  for candidate in \
    "$HOME/Downloads/GitHub-Cool/BingoBackend/Resources/AuthKey_${APNS_KEY_ID}.p8" \
    "$HOME/Downloads/GitHub-Cool/PulseQuest/Resources/AuthKey_${APNS_KEY_ID}.p8"
  do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  echo ""
}

wait_for_http() {
  local url="$1"
  local timeout="${2:-30}"
  local elapsed=0
  until curl -g -sf "$url" >/dev/null 2>&1; do
    sleep 1
    elapsed=$((elapsed + 1))
    if (( elapsed >= timeout )); then
      echo "Timed out waiting for $url" >&2
      return 1
    fi
  done
}

discover_device_tunnel_ip() {
  xcrun devicectl device info details --device "$DEVICE_UDID" 2>/dev/null | awk '/tunnelIPAddress:/ {print $3; exit}'
}

discover_host_ipv6_from_tunnel() {
  local device_tunnel_ip="$1"
  if [[ -z "$device_tunnel_ip" ]]; then
    return
  fi

  python3 - "$device_tunnel_ip" <<'PY'
import ipaddress
import re
import subprocess
import sys

device_ip = ipaddress.IPv6Address(sys.argv[1])
network = ipaddress.IPv6Interface(f"{device_ip}/64").network
text = subprocess.check_output(["ifconfig"], text=True)

for line in text.splitlines():
    match = re.search(r"inet6 ([0-9a-f:]+)(?:%[\\w.]+)? prefixlen", line, re.I)
    if not match:
        continue
    value = match.group(1)
    try:
        address = ipaddress.IPv6Address(value)
    except ipaddress.AddressValueError:
        continue
    if address.is_link_local or address == device_ip:
        continue
    if address in network:
        print(address.compressed)
        break
PY
}

wait_for_marker() {
  local marker="$1"
  local file="$2"
  local timeout="${3:-90}"
  local elapsed=0
  until rg -q "$marker" "$file" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if (( elapsed >= timeout )); then
      echo "Timed out waiting for marker $marker in $file" >&2
      return 1
    fi
  done
}

DEVICE_TUNNEL_IP="${WEBSHELL_DEVICE_TUNNEL_IP:-$(discover_device_tunnel_ip)}"
if [[ -z "$HOST_IPV6" && -n "$DEVICE_TUNNEL_IP" ]]; then
  HOST_IPV6="$(discover_host_ipv6_from_tunnel "$DEVICE_TUNNEL_IP")"
fi
if [[ -z "$HOST_IP" && -z "$HOST_IPV6" ]]; then
  HOST_IP="$(ipconfig getifaddr "$HOST_INTERFACE" 2>/dev/null || true)"
fi

P8_PATH="$(discover_p8_path)"
if [[ -z "$P8_PATH" ]]; then
  echo "Unable to find APNs auth key. Set WEBSHELL_APNS_P8_PATH." >&2
  exit 1
fi

if [[ -z "$HOST_IP" && -z "$HOST_IPV6" ]]; then
  echo "Unable to determine host IP. Set WEBSHELL_HOST_IP or WEBSHELL_HOST_IPV6." >&2
  exit 1
fi

if [[ -n "$HOST_IPV6" ]]; then
  CONTROL_PLANE_HOST="::"
  CONTROL_PLANE_BASE_URL="http://[${HOST_IPV6}]:${PORT}"
  CONTROL_PLANE_INTERNAL_BASE_URL="${WEBSHELL_CONTROL_PLANE_INTERNAL_BASE_URL:-http://[::1]:${PORT}}"
else
  CONTROL_PLANE_HOST="0.0.0.0"
  CONTROL_PLANE_BASE_URL="http://${HOST_IP}:${PORT}"
  CONTROL_PLANE_INTERNAL_BASE_URL="${WEBSHELL_CONTROL_PLANE_INTERNAL_BASE_URL:-$CONTROL_PLANE_BASE_URL}"
fi
APNS_PRIVATE_KEY_P8_BASE64="$(base64 < "$P8_PATH" | tr -d '\n')"

cat >"$RUN_DIR/connection.txt" <<EOF
control_plane_base_url=$CONTROL_PLANE_BASE_URL
control_plane_internal_base_url=$CONTROL_PLANE_INTERNAL_BASE_URL
host_ip=${HOST_IP:-}
host_ipv6=${HOST_IPV6:-}
device_tunnel_ip=${DEVICE_TUNNEL_IP:-}
host_interface=$HOST_INTERFACE
EOF

cleanup() {
  if [[ -n "${CONTROL_PID:-}" ]]; then
    kill "$CONTROL_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${LAUNCH_WRAPPER_PID:-}" ]]; then
    kill "$LAUNCH_WRAPPER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "$CONTROL_REPO"
DATABASE_USERNAME="$DATABASE_USERNAME" \
DATABASE_PASSWORD="$DATABASE_PASSWORD" \
DATABASE_NAME="$DATABASE_NAME" \
PORT="$PORT" \
swift run WebShellControlPlane migrate -y >"$RUN_DIR/migrate.log" 2>&1

APNS_ENABLED=true \
APNS_TEAM_ID="$APNS_TEAM_ID" \
APNS_KEY_ID="$APNS_KEY_ID" \
APNS_TOPIC="$APNS_TOPIC" \
APNS_PRIVATE_KEY_P8_BASE64="$APNS_PRIVATE_KEY_P8_BASE64" \
APNS_USE_SANDBOX=true \
DATABASE_USERNAME="$DATABASE_USERNAME" \
DATABASE_PASSWORD="$DATABASE_PASSWORD" \
DATABASE_NAME="$DATABASE_NAME" \
PORT="$PORT" \
swift run WebShellControlPlane serve --hostname "$CONTROL_PLANE_HOST" --port "$PORT" >"$RUN_DIR/control-plane.log" 2>&1 &
CONTROL_PID=$!

wait_for_http "$CONTROL_PLANE_INTERNAL_BASE_URL/devices" 60

cd "$CLIENT_REPO"
xcodebuild \
  -project WebShellClientApple.xcodeproj \
  -scheme WebShellClientiOS \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  >"$RUN_DIR/xcodebuild.log" 2>&1

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/WebShellClientiOS.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH" >"$RUN_DIR/install.log" 2>&1

DEVICECTL_CHILD_WEBSHELL_CONTROL_PLANE_BASE_URL="$CONTROL_PLANE_BASE_URL" \
DEVICECTL_CHILD_WEBSHELL_DEVICE_TARGET_GROUP="$TARGET_GROUP" \
DEVICECTL_CHILD_WEBSHELL_SLICE_MARKERS=1 \
DEVICECTL_CHILD_WEBSHELL_CLIENT_APP_VERSION="apns-slice" \
xcrun devicectl device process launch \
  --device "$DEVICE_UDID" \
  --terminate-existing \
  --console \
  "$BUNDLE_ID" \
  >"$RUN_DIR/device-console.log" 2>&1 &
LAUNCH_WRAPPER_PID=$!

wait_for_marker "WEBSHELL_SLICE DEVICE_REGISTERED" "$RUN_DIR/device-console.log" 120
wait_for_marker "WEBSHELL_SLICE APNS_TOKEN_LINKED" "$RUN_DIR/device-console.log" 120

cd "$PACKAGE_DIR"
swift run WebShellClientSmoke publish-default-bundle \
  --control-plane-url "$CONTROL_PLANE_INTERNAL_BASE_URL" \
  --target-group "$TARGET_GROUP" \
  --note "WebShell real APNs slice" \
  >"$RUN_DIR/publish.log" 2>&1

BUNDLE_VERSION="$(awk '/PUBLISHED_BUNDLE_VERSION/ {print $2}' "$RUN_DIR/publish.log" | tail -n 1)"
if [[ -z "$BUNDLE_VERSION" ]]; then
  echo "Failed to extract published bundle version." >&2
  exit 1
fi

curl -sf \
  -X POST \
  "$CONTROL_PLANE_INTERNAL_BASE_URL/rule-bundles/$BUNDLE_VERSION/push" \
  -H 'Content-Type: application/json' \
  -d '{"deviceIDs":[]}' \
  >"$RUN_DIR/push.json"

wait_for_marker "WEBSHELL_SLICE APNS_REFRESH_RECEIVED" "$RUN_DIR/device-console.log" 120
wait_for_marker "WEBSHELL_SLICE APNS_HEARTBEAT_SENT" "$RUN_DIR/device-console.log" 120

DEVICE_SUMMARY="$(
  curl -sf "$CONTROL_PLANE_INTERNAL_BASE_URL/devices" | python3 -c '
import json, sys
devices = json.load(sys.stdin)
target_group = sys.argv[1]
for device in devices:
    if device.get("targetGroup") == target_group:
        print(json.dumps(device, ensure_ascii=False))
        break
' "$TARGET_GROUP"
)"

echo "REAL_APNS_SLICE_OK target_group=$TARGET_GROUP bundle_version=$BUNDLE_VERSION"
echo "REAL_APNS_SLICE_DEVICE $DEVICE_SUMMARY"
echo "REAL_APNS_SLICE_RUN_DIR $RUN_DIR"
