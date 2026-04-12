#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
WORKSPACE_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
CLIENT_REPO="$WORKSPACE_ROOT/WebShellClient-Apple"
CLIENT_PACKAGE_DIR="$CLIENT_REPO/Packages/WebShellClientKit"
CONTROL_REPO="$WORKSPACE_ROOT/WebShellControlPlane"
CONTROL_PLANE_BASE_URL_OVERRIDE="${WEBSHELL_LIVE_116PAN_CONTROL_PLANE_BASE_URL:-}"

DATABASE_NAME="${WEBSHELL_CONTROL_PLANE_DATABASE_NAME:-webshell_control_plane}"
DATABASE_USERNAME="${WEBSHELL_CONTROL_PLANE_DATABASE_USERNAME:-${USER:-webshell}}"
DATABASE_PASSWORD="${WEBSHELL_CONTROL_PLANE_DATABASE_PASSWORD:-}"
CONTROL_PORT="${WEBSHELL_LIVE_116PAN_CONTROL_PORT:-8091}"
if [[ -n "$CONTROL_PLANE_BASE_URL_OVERRIDE" ]]; then
  CONTROL_PLANE_BASE_URL="$CONTROL_PLANE_BASE_URL_OVERRIDE"
else
  CONTROL_PLANE_BASE_URL="http://127.0.0.1:${CONTROL_PORT}"
fi
TARGET_GROUP="${WEBSHELL_LIVE_116PAN_TARGET_GROUP:-live-116pan-ui-$(date +%s)}"
BUNDLE_VERSION="${WEBSHELL_LIVE_116PAN_BUNDLE_VERSION:-live.116pan.ui.$(date +%s)}"
RUN_DIR="${WEBSHELL_LIVE_116PAN_RUN_DIR:-/tmp/webshell-live-116pan-ui-$(date +%Y%m%d-%H%M%S)}"
APP_SUPPORT_DIR="$RUN_DIR/app-support"
DERIVED_DATA_DIR="$RUN_DIR/DerivedData"
TRACE_FILE="$RUN_DIR/client-runtime-trace.ndjson"
OSLOG_FILE="$RUN_DIR/client-oslog.log"
CAPTCHA_DEBUG_DIR="$RUN_DIR/captcha-debug"
AUTH_DEBUG_DIR="$RUN_DIR/auth-debug"
CREDENTIAL_SERVICE_NAME="${WEBSHELL_LIVE_116PAN_CREDENTIAL_SERVICE_NAME:-com.yorl.WebShellClientApple.live116pan.$(date +%s)}"
EXPECTED_MIN_BYTES="${WEBSHELL_E2E_EXPECTED_MIN_BYTES:-1048576}"
DOWNLOAD_TIMEOUT_SECONDS="${WEBSHELL_E2E_DOWNLOAD_TIMEOUT_SECONDS:-3600}"
SCHEME_FILE="$CLIENT_REPO/WebShellClientApple.xcodeproj/xcshareddata/xcschemes/WebShellClientMacLiveE2E.xcscheme"
SCHEME_BACKUP_FILE=""
WEBSHELL_E2E_116PAN_URL="${WEBSHELL_E2E_116PAN_URL:-${WEBSHELL_LIVE_116PAN_URL:-}}"
WEBSHELL_E2E_116PAN_USERNAME="${WEBSHELL_E2E_116PAN_USERNAME:-${WEBSHELL_LIVE_116PAN_USERNAME:-}}"
WEBSHELL_E2E_116PAN_PASSWORD="${WEBSHELL_E2E_116PAN_PASSWORD:-${WEBSHELL_LIVE_116PAN_PASSWORD:-}}"
WEBSHELL_E2E_116PAN_ACCOUNT_ID="${WEBSHELL_E2E_116PAN_ACCOUNT_ID:-${WEBSHELL_LIVE_116PAN_ACCOUNT_ID:-}}"
WEBSHELL_E2E_AUTOMATION_TCC_RESET="${WEBSHELL_E2E_AUTOMATION_TCC_RESET:-${E2E_AUTOMATION_TCC_RESET:-1}}"
WEBSHELL_E2E_AUTOMATION_DIAG="${WEBSHELL_E2E_AUTOMATION_DIAG:-1}"
WEBSHELL_E2E_DESTINATION="${WEBSHELL_E2E_DESTINATION:-platform=macOS,arch=arm64}"
WEBSHELL_E2E_DESTINATION_TIMEOUT="${WEBSHELL_E2E_DESTINATION_TIMEOUT:-300}"
WEBSHELL_E2E_TEST_FILTER="${WEBSHELL_E2E_TEST_FILTER:-WebShellClientMacUITests/WebShellClientMacLive116panUITests/testLive116panDownloadCompletesAndRestoresAfterRelaunch}"
WEBSHELL_E2E_TEST_TIMEOUTS_ENABLED="${WEBSHELL_E2E_TEST_TIMEOUTS_ENABLED:-YES}"
WEBSHELL_E2E_XCODEBUILD_TIMEOUT_SECONDS="${WEBSHELL_E2E_XCODEBUILD_TIMEOUT_SECONDS:-900}"
WEBSHELL_E2E_FALLBACK_DESTINATION="${WEBSHELL_E2E_FALLBACK_DESTINATION:-platform=macOS}"
WEBSHELL_E2E_FALLBACK_TEST_TIMEOUTS_ENABLED="${WEBSHELL_E2E_FALLBACK_TEST_TIMEOUTS_ENABLED:-YES}"
WEBSHELL_E2E_ALLOW_RETRY_ON_HANG="${WEBSHELL_E2E_ALLOW_RETRY_ON_HANG:-1}"
LAUNCHCTL_ENV_KEYS=()
TESTMANAGERD_STREAM_PID=""
XCODEBUILD_PID=""
AUTOMATION_BUNDLE_IDS=(
  "com.apple.dt.Xcode"
  "com.apple.dt.xcodebuild"
  "com.apple.dt.xctest"
  "com.apple.dt.IDEKitService"
  "com.yorl.WebShellClientApple.mac"
  "com.yorl.WebShellClientApple.macUITests"
)

resolve_control_plane_port() {
  local base_port="$CONTROL_PORT"
  local port="$base_port"
  local max_attempts=100
  local attempts=0

  while (( attempts < max_attempts )); do
    if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      attempts=$((attempts + 1))
      port=$((port + 1))
      continue
    fi

    if (( port != base_port )); then
      echo "Control plane port ${base_port} was occupied; switched to free port ${port}."
    fi
    CONTROL_PORT="$port"
    CONTROL_PLANE_BASE_URL="http://127.0.0.1:${CONTROL_PORT}"
    return 0
  done

  echo "Unable to find free control-plane port near ${base_port} after ${max_attempts} attempts." >&2
  exit 64
}

require_env() {
  local key="$1"
  local value
  eval "value=\"\${$key:-}\""
  if [[ -z "$value" ]]; then
    echo "Missing required environment variable: $key" >&2
    exit 64
  fi
}

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
  if [[ -n "${SCHEME_BACKUP_FILE:-}" && -f "$SCHEME_BACKUP_FILE" && -f "$SCHEME_FILE" ]]; then
    cp "$SCHEME_BACKUP_FILE" "$SCHEME_FILE"
    rm -f "$SCHEME_BACKUP_FILE"
  fi
  for key in "${LAUNCHCTL_ENV_KEYS[@]:-}"; do
    launchctl unsetenv "$key" >/dev/null 2>&1 || true
  done
  if [[ -n "${XCODEBUILD_PID:-}" ]]; then
    kill "$XCODEBUILD_PID" >/dev/null 2>&1 || true
    wait "$XCODEBUILD_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${CONTROL_PID:-}" ]]; then
    kill "$CONTROL_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${LOG_STREAM_PID:-}" ]]; then
    kill "$LOG_STREAM_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${TESTMANAGERD_STREAM_PID:-}" ]]; then
    kill "$TESTMANAGERD_STREAM_PID" >/dev/null 2>&1 || true
  fi
  security delete-generic-password -s "$CREDENTIAL_SERVICE_NAME" >/dev/null 2>&1 || true
  if [[ "${WEBSHELL_LIVE_116PAN_KEEP_ARTIFACTS:-0}" != "1" ]]; then
    rm -rf "$APP_SUPPORT_DIR" "$DERIVED_DATA_DIR"
  fi
}
trap cleanup EXIT

collect_automation_diagnostics() {
  if [[ "$WEBSHELL_E2E_AUTOMATION_DIAG" != "1" ]]; then
    return
  fi

  local diag_file="$RUN_DIR/automation-permission-diagnostics.log"
  local tm_log_tail="$RUN_DIR/testmanagerd-stream.log"

  {
    echo "===== Automation permissions diagnostics: $(date -Iseconds) ====="
    echo "Destination=$WEBSHELL_E2E_DESTINATION"
    echo "RunDir=$RUN_DIR"

    echo "----- running processes (relevant) -----"
    ps -axo pid=,ppid=,etime=,command | grep -E "xcodebuild|xctest|testmanagerd|WebShellClientMac|WebShellClientMacUITests|DTServiceHub|simctl" || true

    echo "----- canary: Accessibility + AppleEvents via AppleScript -----"
    if command -v /usr/bin/osascript >/dev/null 2>&1; then
      /usr/bin/osascript -e 'tell application "System Events" to get UI elements of process "Finder"' >/dev/null 2>&1 \
        && echo "AX_CANARY_OK=1" || echo "AX_CANARY_OK=0"
      /usr/bin/osascript -e 'tell application "System Events" to get name of first process whose name is "Finder"' >/dev/null 2>&1 \
        && echo "AEEVENTS_CANARY_OK=1" || echo "AEEVENTS_CANARY_OK=0"
    else
      echo "osascript missing; canary checks skipped"
    fi

    echo "----- TCC db snapshots for Automation / Accessibility -----"
    local tcc_paths=(
      "$HOME/Library/Application Support/com.apple.TCC/TCC.db"
      "/Library/Application Support/com.apple.TCC/TCC.db"
    )
    local db_path
    for db_path in "${tcc_paths[@]}"; do
      if [[ ! -r "$db_path" ]]; then
        echo "TCC_DB unreadable: $db_path"
        continue
      fi
      if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "sqlite3 unavailable; skip direct TCC db read"
        continue
      fi
      if ! sqlite3 "$db_path" ".schema access" >/dev/null 2>&1; then
        echo "TCC access table missing in: $db_path"
        continue
      fi
      for bundle_id in "${AUTOMATION_BUNDLE_IDS[@]}"; do
        echo "[${db_path}] client=${bundle_id}"
        sqlite3 "$db_path" "SELECT * FROM access WHERE client='${bundle_id}' AND (service='kTCCServiceAccessibility' OR service='kTCCServiceAppleEvents') ORDER BY service;" 2>/dev/null || true
      done
    done

    echo "----- recent testmanagerd events -----"
    if [[ -s "$tm_log_tail" ]]; then
      /usr/bin/log show --style compact --predicate 'process == "testmanagerd"' --last 10m > "$RUN_DIR/testmanagerd-recent.log" 2>&1 || true
      tail -n 120 "$RUN_DIR/testmanagerd-recent.log" || true
    else
      echo "testmanagerd-stream.log not ready yet"
    fi
  } | tee -a "$diag_file" >/dev/null
}

reset_automation_permissions() {
  if [[ "$WEBSHELL_E2E_AUTOMATION_TCC_RESET" != "1" ]]; then
    return
  fi

  if ! command -v tccutil >/dev/null 2>&1; then
    return
  fi

  for bundle_id in "${AUTOMATION_BUNDLE_IDS[@]}"; do
    tccutil reset Accessibility "$bundle_id" >/dev/null 2>&1 || true
    tccutil reset AppleEvents "$bundle_id" >/dev/null 2>&1 || true
  done

  pkill -f "WebShellClientMacUITests" >/dev/null 2>&1 || true
  pkill -f "WebShellClientMac.app" >/dev/null 2>&1 || true
  pkill -9 -f "testmanagerd" >/dev/null 2>&1 || true
}

automation_canary_ok() {
  if ! command -v /usr/bin/osascript >/dev/null 2>&1; then
    return 1
  fi

  /usr/bin/osascript -e 'tell application "System Events" to get UI elements of process "Finder"' >/dev/null 2>&1 || return 1
  /usr/bin/osascript -e 'tell application "System Events" to get name of first process whose name is "Finder"' >/dev/null 2>&1 || return 1
}

precheck_automation_run() {
  collect_automation_diagnostics
  if [[ "$WEBSHELL_E2E_AUTOMATION_TCC_RESET" == "1" ]] && ! automation_canary_ok; then
    reset_automation_permissions
    collect_automation_diagnostics
  else
    echo "Automation canary is healthy; skipping TCC reset." | tee -a "$RUN_DIR/automation-permission-diagnostics.log" >/dev/null
  fi
}

is_hang_failure() {
  local log_file="$1"
  grep -qiE "hung before establishing connection|listener failed to activate|operation not permitted|test runner hung before establishing connection|session .*waiting to pair|waiting to pair" "$log_file" \
    && return 0 || return 1
}

run_xcodebuild_test() {
  local destination="$1"
  local test_timeouts_enabled="$2"
  local log_file="$3"
  local result_bundle_path="${4:-$RUN_DIR/xctest.xcresult}"
  local timeout_seconds="$WEBSHELL_E2E_XCODEBUILD_TIMEOUT_SECONDS"
  local elapsed=0
  rm -rf "$result_bundle_path"

  (
  WEBSHELL_E2E_116PAN_URL="$WEBSHELL_E2E_116PAN_URL" \
  WEBSHELL_E2E_116PAN_USERNAME="$WEBSHELL_E2E_116PAN_USERNAME" \
  WEBSHELL_E2E_116PAN_PASSWORD="$WEBSHELL_E2E_116PAN_PASSWORD" \
  WEBSHELL_E2E_116PAN_ACCOUNT_ID="$E2E_ACCOUNT_ID" \
  WEBSHELL_E2E_EXPECTED_MIN_BYTES="$EXPECTED_MIN_BYTES" \
  WEBSHELL_E2E_DOWNLOAD_TIMEOUT_SECONDS="$DOWNLOAD_TIMEOUT_SECONDS" \
  WEBSHELL_CONTROL_PLANE_BASE_URL="$CONTROL_PLANE_BASE_URL" \
  WEBSHELL_DEVICE_TARGET_GROUP="$TARGET_GROUP" \
  WEBSHELL_CLIENT_APP_VERSION="live-116pan-ui-e2e" \
  WEBSHELL_CLIENT_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
  WEBSHELL_CLIENT_CREDENTIAL_SERVICE_NAME="$CREDENTIAL_SERVICE_NAME" \
  WEBSHELL_CLIENT_TRACE_FILE="$TRACE_FILE" \
  WEBSHELL_CAPTCHA_DEBUG_DIR="$CAPTCHA_DEBUG_DIR" \
  WEBSHELL_AUTH_DEBUG_DIR="$AUTH_DEBUG_DIR" \
  xcodebuild test \
    -project "$CLIENT_REPO/WebShellClientApple.xcodeproj" \
    -scheme WebShellClientMacLiveE2E \
    -destination "$destination" \
    -destination-timeout "$WEBSHELL_E2E_DESTINATION_TIMEOUT" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -resultBundlePath "$result_bundle_path" \
    -parallel-testing-enabled NO \
    -maximum-parallel-testing-workers 1 \
    -test-timeouts-enabled "$test_timeouts_enabled" \
    -configuration Debug \
    -only-testing:"$WEBSHELL_E2E_TEST_FILTER" \
    -skipPackagePluginValidation \
    -onlyUsePackageVersionsFromResolvedFile \
    -skipPackageUpdates \
    CODE_SIGN_STYLE=Automatic \
    > "$log_file" 2>&1
  ) &
  XCODEBUILD_PID=$!
  while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if ((elapsed >= timeout_seconds)); then
      echo "xcodebuild timed out after ${timeout_seconds}s, terminating process group." >> "$log_file"
      pkill -P "$XCODEBUILD_PID" >/dev/null 2>&1 || true
      kill -SIGTERM "$XCODEBUILD_PID" >/dev/null 2>&1 || true
      sleep 2
      kill -9 "$XCODEBUILD_PID" >/dev/null 2>&1 || true
      wait "$XCODEBUILD_PID" >/dev/null 2>&1 || true
      XCODEBUILD_PID=""
      return 124
    fi
  done
  wait "$XCODEBUILD_PID"
  local exit_code=$?
  XCODEBUILD_PID=""
  return "$exit_code"
}

start_testmanagerd_log_stream() {
  /usr/bin/log stream --style compact --predicate 'process == "testmanagerd" || process == "xcodebuild" || process == "xctest" || process == "WebShellClientMacUITests-Runner" || process == "WebShellClientMac.app" || process == "com.apple.dt.xctest"' \
    >"$RUN_DIR/testmanagerd-stream.log" 2>&1 &
  TESTMANAGERD_STREAM_PID=$!
}

tail_artifacts() {
  local xcodebuild_log="${XCODEBUILD_LOG_PATH:-$RUN_DIR/xcodebuild-ui.log}"
  echo "---- xcodebuild-ui.log tail ----" >&2
  tail -n 160 "$xcodebuild_log" >&2 || true
  echo "---- client-runtime-trace.ndjson tail ----" >&2
  tail -n 80 "$TRACE_FILE" >&2 || true
  echo "---- client-oslog.log tail ----" >&2
  tail -n 120 "$OSLOG_FILE" >&2 || true
  echo "---- captcha-debug files ----" >&2
  find "$CAPTCHA_DEBUG_DIR" -maxdepth 1 -type f -print >&2 || true
  echo "---- auth-debug files ----" >&2
  find "$AUTH_DEBUG_DIR" -maxdepth 1 -type f -print >&2 || true
  echo "---- auth-debug tail ----" >&2
  find "$AUTH_DEBUG_DIR" -maxdepth 1 -type f -name '*.ndjson' -exec tail -n 80 {} \; >&2 || true
  echo "---- testmanagerd recent logs ----" >&2
  if [[ -f "$RUN_DIR/testmanagerd-stream.log" ]]; then
    tail -n 120 "$RUN_DIR/testmanagerd-stream.log" >&2 || true
  fi
  if [[ -f "$RUN_DIR/testmanagerd-recent.log" ]]; then
    tail -n 120 "$RUN_DIR/testmanagerd-recent.log" >&2 || true
  fi
}

configure_live_116pan_scheme() {
  SCHEME_BACKUP_FILE="$RUN_DIR/WebShellClientMacLiveE2E.xcscheme.bak"
  cp "$SCHEME_FILE" "$SCHEME_BACKUP_FILE"

  local -a env_pairs=(
    "WEBSHELL_E2E_116PAN_URL=$WEBSHELL_E2E_116PAN_URL"
    "WEBSHELL_E2E_116PAN_USERNAME=$WEBSHELL_E2E_116PAN_USERNAME"
    "WEBSHELL_E2E_116PAN_PASSWORD=$WEBSHELL_E2E_116PAN_PASSWORD"
    "WEBSHELL_E2E_116PAN_ACCOUNT_ID=${WEBSHELL_E2E_116PAN_ACCOUNT_ID:-$E2E_ACCOUNT_ID}"
    "WEBSHELL_CONTROL_PLANE_BASE_URL=$CONTROL_PLANE_BASE_URL"
    "WEBSHELL_DEVICE_TARGET_GROUP=$TARGET_GROUP"
    "WEBSHELL_CLIENT_APP_VERSION=live-116pan-ui-e2e"
    "WEBSHELL_CLIENT_APP_SUPPORT_DIR=$APP_SUPPORT_DIR"
    "WEBSHELL_CLIENT_CREDENTIAL_SERVICE_NAME=$CREDENTIAL_SERVICE_NAME"
    "WEBSHELL_CLIENT_TRACE_FILE=$TRACE_FILE"
    "WEBSHELL_CAPTCHA_DEBUG_DIR=$CAPTCHA_DEBUG_DIR"
    "WEBSHELL_AUTH_DEBUG_DIR=$AUTH_DEBUG_DIR"
    "WEBSHELL_E2E_EXPECTED_MIN_BYTES=$EXPECTED_MIN_BYTES"
    "WEBSHELL_E2E_DOWNLOAD_TIMEOUT_SECONDS=$DOWNLOAD_TIMEOUT_SECONDS"
  )

  local -a python_args=( "$SCHEME_FILE" )
  local pair
  for pair in "${env_pairs[@]}"; do
    python_args+=( "$pair" )
  done

  python3 - "${python_args[@]}" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
values = {}
for item in sys.argv[2:]:
  if "=" not in item:
    continue
  key, value = item.split("=", 1)
  values[key] = value

tree = ET.parse(path)
root = tree.getroot()

def tag_name(node):
  return node.tag.split("}")[-1]

test_action = next((node for node in list(root) if tag_name(node) == "TestAction"), None)
if test_action is None:
  raise SystemExit("Missing TestAction in scheme.")

env_node = next((node for node in list(test_action) if tag_name(node) == "EnvironmentVariables"), None)
if env_node is None:
  env_node = ET.SubElement(test_action, "EnvironmentVariables")

existing = {
  node.get("key"): node
  for node in list(env_node)
  if tag_name(node) == "EnvironmentVariable" and node.get("key")
}
for key, value in values.items():
  if key in existing:
    existing[key].set("value", value)
    existing[key].set("isEnabled", "YES")
  else:
    ET.SubElement(
      env_node,
      "EnvironmentVariable",
      {"key": key, "value": value, "isEnabled": "YES"},
    )

ET.indent(root, space="    ")
tree.write(path, encoding="utf-8", xml_declaration=True)
PY
}

set_launchctl_env() {
  local key="$1"
  local value="$2"
  if ! launchctl setenv "$key" "$value" >/dev/null 2>&1; then
    echo "Failed to export $key to launchctl environment." >&2
    exit 1
  fi
  LAUNCHCTL_ENV_KEYS+=("$key")
}

set_launchctl_environment_for_run() {
  set_launchctl_env WEBSHELL_E2E_116PAN_URL "$WEBSHELL_E2E_116PAN_URL"
  set_launchctl_env WEBSHELL_E2E_116PAN_USERNAME "$WEBSHELL_E2E_116PAN_USERNAME"
  set_launchctl_env WEBSHELL_E2E_116PAN_PASSWORD "$WEBSHELL_E2E_116PAN_PASSWORD"
  set_launchctl_env WEBSHELL_E2E_116PAN_ACCOUNT_ID "$E2E_ACCOUNT_ID"
  set_launchctl_env WEBSHELL_CONTROL_PLANE_BASE_URL "$CONTROL_PLANE_BASE_URL"
  set_launchctl_env WEBSHELL_DEVICE_TARGET_GROUP "$TARGET_GROUP"
  set_launchctl_env WEBSHELL_CLIENT_APP_VERSION "live-116pan-ui-e2e"
  set_launchctl_env WEBSHELL_CLIENT_APP_SUPPORT_DIR "$APP_SUPPORT_DIR"
  set_launchctl_env WEBSHELL_CLIENT_CREDENTIAL_SERVICE_NAME "$CREDENTIAL_SERVICE_NAME"
  set_launchctl_env WEBSHELL_CLIENT_TRACE_FILE "$TRACE_FILE"
  set_launchctl_env WEBSHELL_CAPTCHA_DEBUG_DIR "$CAPTCHA_DEBUG_DIR"
  set_launchctl_env WEBSHELL_AUTH_DEBUG_DIR "$AUTH_DEBUG_DIR"
}

refresh_launchctl_env() {
  set_launchctl_environment_for_run
}

require_env WEBSHELL_E2E_116PAN_URL
require_env WEBSHELL_E2E_116PAN_USERNAME
require_env WEBSHELL_E2E_116PAN_PASSWORD
if [[ -z "$CONTROL_PLANE_BASE_URL_OVERRIDE" ]]; then
  resolve_control_plane_port
fi

mkdir -p "$RUN_DIR" "$APP_SUPPORT_DIR" "$CAPTCHA_DEBUG_DIR" "$AUTH_DEBUG_DIR"

cat >"$RUN_DIR/context.txt" <<EOF
control_plane_base_url=$CONTROL_PLANE_BASE_URL
target_group=$TARGET_GROUP
bundle_version=$BUNDLE_VERSION
database_name=$DATABASE_NAME
app_support_dir=$APP_SUPPORT_DIR
credential_service_name=$CREDENTIAL_SERVICE_NAME
trace_file=$TRACE_FILE
oslog_file=$OSLOG_FILE
captcha_debug_dir=$CAPTCHA_DEBUG_DIR
auth_debug_dir=$AUTH_DEBUG_DIR
expected_min_bytes=$EXPECTED_MIN_BYTES
download_timeout_seconds=$DOWNLOAD_TIMEOUT_SECONDS
EOF

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

cd "$CLIENT_PACKAGE_DIR"
swift run WebShellClientSmoke publish-default-bundle \
  --control-plane-url "$CONTROL_PLANE_BASE_URL" \
  --target-group "$TARGET_GROUP" \
  --note "WebShell live 116pan macOS UI E2E" \
  --bundle-version "$BUNDLE_VERSION" \
  >"$RUN_DIR/publish-default-bundle.log" 2>&1

PUBLISHED_VERSION="$(awk '/PUBLISHED_BUNDLE_VERSION/ {print $2}' "$RUN_DIR/publish-default-bundle.log" | tail -n 1)"
if [[ "$PUBLISHED_VERSION" != "$BUNDLE_VERSION" ]]; then
  echo "Expected published bundle $BUNDLE_VERSION, got ${PUBLISHED_VERSION:-<missing>}." >&2
  tail -n 80 "$RUN_DIR/publish-default-bundle.log" >&2 || true
  exit 1
fi

curl -sf "$CONTROL_PLANE_BASE_URL/rule-bundles/active" >"$RUN_DIR/active-bundle.json"
python3 - "$BUNDLE_VERSION" "$RUN_DIR/active-bundle.json" <<'PY'
import json
import sys

expected_version = sys.argv[1]
path = sys.argv[2]

with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

bundle = payload.get("bundle") or payload
if payload.get("bundleVersion") != expected_version or bundle.get("bundleVersion") != expected_version:
    raise SystemExit(f"Active bundle version mismatch: expected {expected_version}, got payload={payload.get('bundleVersion')} bundle={bundle.get('bundleVersion')}")

provider = next(
    (
        item
        for item in bundle.get("providers", [])
        if item.get("providerFamily") == "116pan-vip" or item.get("id") == "116pan-vip"
    ),
    None,
)
if not provider:
    raise SystemExit("Active bundle does not contain provider 116pan-vip.")
if provider.get("authWorkflowID") != "116pan.vip.captcha.auth":
    raise SystemExit(f"116pan-vip authWorkflowID mismatch: {provider.get('authWorkflowID')}")
print("ACTIVE_BUNDLE_READY provider=116pan-vip authWorkflowID=116pan.vip.captcha.auth")
PY

cd "$CLIENT_REPO"
xcodegen generate >"$RUN_DIR/xcodegen.log" 2>&1

E2E_ACCOUNT_ID="${WEBSHELL_E2E_116PAN_ACCOUNT_ID:-e2e-116pan}"
configure_live_116pan_scheme
/usr/bin/log stream --style compact --predicate 'subsystem == "com.yorl.WebShellClientApple"' >"$OSLOG_FILE" 2>&1 &
LOG_STREAM_PID=$!

start_testmanagerd_log_stream

precheck_automation_run
refresh_launchctl_env
XCODEBUILD_LOG_PATH="$RUN_DIR/xcodebuild-ui.log"
XCODEBUILD_RESULT_BUNDLE_PATH="$RUN_DIR/xctest-primary.xcresult"
if run_xcodebuild_test \
  "$WEBSHELL_E2E_DESTINATION" \
  "$WEBSHELL_E2E_TEST_TIMEOUTS_ENABLED" \
  "$XCODEBUILD_LOG_PATH" \
  "$XCODEBUILD_RESULT_BUNDLE_PATH"
then
  xcodebuild_exit_code=0
else
  xcodebuild_exit_code=$?
fi
if (( xcodebuild_exit_code != 0 )); then
  collect_automation_diagnostics
  primary_is_hang=0
  if is_hang_failure "$XCODEBUILD_LOG_PATH"; then
    primary_is_hang=1
  fi
  if [[ "$WEBSHELL_E2E_ALLOW_RETRY_ON_HANG" == "1" ]] && (( xcodebuild_exit_code == 124 || primary_is_hang == 1 )); then
    echo "Primary xcodebuild run hit connection-hang pattern. Retrying with fallback destination/timeouts." >&2
    cp "$XCODEBUILD_LOG_PATH" "$RUN_DIR/xcodebuild-ui-hang.log"
    precheck_automation_run
    configure_live_116pan_scheme
    refresh_launchctl_env
    XCODEBUILD_LOG_PATH="$RUN_DIR/xcodebuild-ui-retry.log"
    XCODEBUILD_RESULT_BUNDLE_PATH="$RUN_DIR/xctest-retry.xcresult"
    run_xcodebuild_test \
      "$WEBSHELL_E2E_FALLBACK_DESTINATION" \
      "$WEBSHELL_E2E_FALLBACK_TEST_TIMEOUTS_ENABLED" \
      "$XCODEBUILD_LOG_PATH" \
      "$XCODEBUILD_RESULT_BUNDLE_PATH" || {
      collect_automation_diagnostics
      echo "WebShellClientMac live 116pan UI E2E failed after retry. Run dir: $RUN_DIR" >&2
      tail_artifacts
      if [[ -f "$XCODEBUILD_LOG_PATH" ]] && grep -Eiq "automation mode|timed out|timeout|requesting automation mode|unauthorized|hung before establishing connection|Operation not permitted" "$XCODEBUILD_LOG_PATH"; then
        echo "Failure pattern suggests automation/permission timeout path; rerun reset+diagnostics and check TCC/Accessibility/AppleEvents" >&2
      fi
      echo "Hint: rerun with WEBSHELL_E2E_AUTOMATION_TCC_RESET=1 and WEBSHELL_E2E_AUTOMATION_DIAG=1" >&2
      exit 1
    }
  else
    echo "WebShellClientMac live 116pan UI E2E failed. Run dir: $RUN_DIR" >&2
    tail_artifacts
    if [[ -f "$XCODEBUILD_LOG_PATH" ]] && grep -Eiq "automation mode|timed out|timeout|requesting automation mode|unauthorized|hung before establishing connection|Operation not permitted" "$XCODEBUILD_LOG_PATH"; then
      echo "Failure pattern suggests automation/permission timeout path; rerun reset+diagnostics and check TCC/Accessibility/AppleEvents" >&2
    fi
    echo "Hint: rerun with WEBSHELL_E2E_AUTOMATION_TCC_RESET=1 and WEBSHELL_E2E_AUTOMATION_DIAG=1" >&2
    exit 1
  fi
fi

if grep -Eq "Test skipped|with [0-9]+ test skipped" "$XCODEBUILD_LOG_PATH"; then
  echo "WebShellClientMac live 116pan UI E2E skipped. Run dir: $RUN_DIR" >&2
  grep -En "Test skipped|with [0-9]+ test skipped" "$XCODEBUILD_LOG_PATH" >&2 || true
  exit 78
fi

if ! python3 - "$APP_SUPPORT_DIR/file-index.json" "$WEBSHELL_E2E_116PAN_URL" "$EXPECTED_MIN_BYTES" "${WEBSHELL_E2E_EXPECTED_BYTES:-}" "$TRACE_FILE" <<'PY'
import json
import os
import sys

index_path = sys.argv[1]
source_url = sys.argv[2]
expected_min_bytes = int(sys.argv[3])
expected_bytes = int(sys.argv[4]) if sys.argv[4] else None
trace_path = sys.argv[5]

if not os.path.exists(index_path):
    raise SystemExit(f"Missing file index: {index_path}")

with open(index_path, "r", encoding="utf-8") as handle:
    records = json.load(handle)

record = next((item for item in records if item.get("sourceURL") == source_url), None)
if not record:
    raise SystemExit(f"Missing downloaded record for source URL: {source_url}")

local_url = record.get("localURL") or ""
if not os.path.exists(local_url):
    raise SystemExit(f"Downloaded file does not exist: {local_url}")

disk_size = os.path.getsize(local_url)
if disk_size < expected_min_bytes:
    raise SystemExit(f"Downloaded file is too small: {local_url} bytes={disk_size} expected_min={expected_min_bytes}")
if expected_bytes is not None and disk_size != expected_bytes:
    raise SystemExit(f"Downloaded file size mismatch: {local_url} bytes={disk_size} expected={expected_bytes}")

if expected_bytes is None and os.path.exists(trace_path):
    with open(trace_path, "r", encoding="utf-8") as handle:
        entries = [json.loads(line) for line in handle if line.strip()]
    matching_lengths = [
        int(entry.get("fields", {}).get("content_length", "0"))
        for entry in entries
        if entry.get("event") == "download_response_received"
        and entry.get("fields", {}).get("source_url") == source_url
        and entry.get("fields", {}).get("content_length", "").isdigit()
        and int(entry.get("fields", {}).get("content_length", "0")) > 0
    ]
    if matching_lengths and disk_size != matching_lengths[-1]:
        raise SystemExit(f"Downloaded file size does not match response Content-Length: {local_url} bytes={disk_size} content_length={matching_lengths[-1]}")

with open(local_url, "rb") as handle:
    prefix = handle.read(512).lower().lstrip()
if prefix.startswith(b"<!doctype") or prefix.startswith(b"<html"):
    raise SystemExit(f"Downloaded file looks like an HTML fallback page: {local_url} bytes={disk_size}")

print(f"DOWNLOADED_FILE_READY filename={record.get('filename', '')} bytes={disk_size} path={local_url}")
PY
then
  echo "WebShellClientMac live 116pan artifact validation failed. Run dir: $RUN_DIR" >&2
  tail_artifacts
  exit 1
fi

echo "LIVE_116PAN_UI_E2E_OK target_group=$TARGET_GROUP bundle_version=$BUNDLE_VERSION"
echo "LIVE_116PAN_UI_E2E_TRACE_FILE $TRACE_FILE"
echo "LIVE_116PAN_UI_E2E_OSLOG_FILE $OSLOG_FILE"
echo "LIVE_116PAN_UI_E2E_RUN_DIR $RUN_DIR"
