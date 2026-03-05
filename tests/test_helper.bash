#
# test_helper.bash - Common test utilities for auto-reboot BATS tests
#
# Provides:
# - setup/teardown with temp dirs and mock PATH
# - source_script() to source auto-reboot functions (strips PATH lock + main)
# - run_script() to run auto-reboot as executable with mocked commands
# - Mock creators for systemctl, systemd-run, logger, date, uptime, sudo
# - Custom assertions
#

# Load BATS helper libraries
load '/usr/local/lib/bats-support/load.bash' 2>/dev/null || true
load '/usr/local/lib/bats-assert/load.bash' 2>/dev/null || true

# Test configuration
export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export SCRIPT_UNDER_TEST="${PROJECT_ROOT}/auto-reboot"

# Saved originals
declare -g ORIG_PATH="${PATH}"

# ── Setup / Teardown ─────────────────────────────────────────────

_common_setup() {
  TEST_TEMP_DIR="$(mktemp -d "/tmp/auto-reboot-test-${BATS_TEST_NUMBER:-0}-XXXXXX")"
  MOCK_BIN="${TEST_TEMP_DIR}/mock-bin"
  MOCK_LOG="${TEST_TEMP_DIR}/mock.log"
  mkdir -p "$MOCK_BIN"

  # Create mock logger (always needed — the script calls logger)
  create_mock_logger

  export TEST_TEMP_DIR MOCK_BIN MOCK_LOG
}

_common_teardown() {
  if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
  export PATH="${ORIG_PATH}"
}

# ── Source Script (for unit testing functions) ────────────────────

# source_script — sources auto-reboot with dangerous lines stripped:
#   1. declare -rx PATH=...  (would lock PATH, breaking mock injection)
#   2. main "$@"             (would auto-execute on source)
#   3. readonly declarations in main (would lock variables between tests)
#
# After sourcing, all functions (parse_day, _msg, etc.) are available
# in the current shell with mock PATH prepended.
#
source_script() {
  # Build sanitized version
  local -- sanitized="${TEST_TEMP_DIR}/auto-reboot-sanitized"
  sed \
    -e '/^declare -rx PATH=/d' \
    -e '/^main "\$@"/d' \
    -e 's/^set -euo pipefail$/set -uo pipefail/' \
    -e 's/^shopt -s inherit_errexit$//' \
    -e '/^declare -r SCRIPT_PATH=/d' \
    -e '/^declare -r SCRIPT_NAME=/d' \
    -e '/^declare -r VERSION=/d' \
    -e '/^declare -r XUSER=/d' \
    -e '/^if \[\[ -t 1/,/^fi$/d' \
    -e 's/^declare -r RED=/declare RED=/' \
    -e 's/^declare -r CYAN=/declare CYAN=/' \
    -e 's/^declare -r NC=/declare NC=/' \
    "$SCRIPT_UNDER_TEST" > "$sanitized"

  # Prepend mock bin to PATH so mocks override real commands
  export PATH="${MOCK_BIN}:${ORIG_PATH}"

  # Set script metadata as exports so `run` subshells can access them
  export SCRIPT_PATH="${SCRIPT_UNDER_TEST}"
  export SCRIPT_NAME="auto-reboot"
  export VERSION="1.1.1"
  export XUSER="${USER:-testuser}"
  export RED='' CYAN='' NC=''

  # Source the sanitized script
  # shellcheck disable=SC1090
  source "$sanitized"
}

# ── Run Script (for integration/CLI testing) ──────────────────────

# run_script — runs main() with arguments in a clean subshell.
# Uses source_script's sanitized file and strips the sudo/EUID check.
# Sets BATS $status and $output variables.
#
run_script() {
  local -- sanitized="${TEST_TEMP_DIR}/auto-reboot-cli"
  sed \
    -e '/^declare -rx PATH=/d' \
    -e '/^main "\$@"/d' \
    -e 's/^set -euo pipefail$/set -uo pipefail/' \
    -e 's/^shopt -s inherit_errexit$//' \
    -e '/^declare -r SCRIPT_PATH=/d' \
    -e '/^declare -r SCRIPT_NAME=/d' \
    -e '/^declare -r VERSION=/d' \
    -e '/^declare -r XUSER=/d' \
    -e '/^if \[\[ -t 1/,/^fi$/d' \
    -e 's/^declare -r RED=/declare RED=/' \
    -e 's/^declare -r CYAN=/declare CYAN=/' \
    -e 's/^declare -r NC=/declare NC=/' \
    -e '/^  if ((EUID)); then/,/^  fi$/d' \
    "$SCRIPT_UNDER_TEST" > "$sanitized"

  run bash -c '
    export PATH="'"${MOCK_BIN}:${ORIG_PATH}"'"
    export SCRIPT_PATH="'"${SCRIPT_UNDER_TEST}"'"
    export SCRIPT_NAME="auto-reboot"
    export VERSION="1.1.1"
    export XUSER="${USER:-testuser}"
    export RED="" CYAN="" NC=""
    export MOCK_LOG="'"${MOCK_LOG}"'"
    source "'"${sanitized}"'"
    main "$@"
  ' _ "$@"
}

# ── Mock Creators ─────────────────────────────────────────────────

create_mock_logger() {
  cat > "${MOCK_BIN}/logger" <<'EOF'
#!/usr/bin/env bash
echo "logger $*" >> "${MOCK_LOG:-/dev/null}"
EOF
  chmod +x "${MOCK_BIN}/logger"
}

create_mock_systemctl() {
  local -- timer_output="${1:-}"
  cat > "${MOCK_BIN}/systemctl" <<EOF
#!/usr/bin/env bash
echo "systemctl \$*" >> "\${MOCK_LOG:-/dev/null}"
case "\$1" in
  is-system-running) echo "running"; exit 0 ;;
  list-timers) echo "${timer_output}" ;;
  stop) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/systemctl"
}

create_mock_systemd_run() {
  cat > "${MOCK_BIN}/systemd-run" <<'EOF'
#!/usr/bin/env bash
echo "systemd-run $*" >> "${MOCK_LOG:-/dev/null}"
exit 0
EOF
  chmod +x "${MOCK_BIN}/systemd-run"
}

# create_mock_date — creates a date mock that returns fixed values.
#
# Args:
#   $1 — fixed epoch for 'date +%s' (default: 1700000000)
#   $2 — fixed weekday number for 'date +%w' (default: 3 = Wednesday)
#
# The mock handles common date invocations:
#   date +%s              → returns fixed epoch
#   date +%w              → returns fixed weekday
#   date -d "today H:M" +%s → computes epoch from hour:minute on the fixed day
#   date -d "tomorrow H:M" +%s → today + 86400
#   date -d "+N days H:M" +%s → today + N*86400
#   date -d "..." +format → passes to real date (for display formatting)
#
create_mock_date() {
  local -i fixed_epoch=${1:-1700000000}
  local -i fixed_weekday=${2:-3}
  cat > "${MOCK_BIN}/date" <<MOCKEOF
#!/usr/bin/env bash
FIXED_EPOCH=${fixed_epoch}
FIXED_WEEKDAY=${fixed_weekday}

# Compute day start (midnight UTC) from fixed epoch
DAY_START=\$(( FIXED_EPOCH - (FIXED_EPOCH % 86400) ))

parse_hm() {
  # Extract HH:MM from arguments, return epoch for that time on given day offset
  # Note: bash integer variables drop leading zeros (00 -> 0), so accept 1-2 digits
  local args="\$*"
  local day_offset=0 h=0 m=0

  if [[ "\$args" =~ today\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=0
    h=\${BASH_REMATCH[1]}; m=\${BASH_REMATCH[2]}
  elif [[ "\$args" =~ tomorrow\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=1
    h=\${BASH_REMATCH[1]}; m=\${BASH_REMATCH[2]}
  elif [[ "\$args" =~ \+([0-9]+)\ +days?\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=\${BASH_REMATCH[1]}
    h=\${BASH_REMATCH[2]}; m=\${BASH_REMATCH[3]}
  else
    return 1
  fi
  echo \$(( DAY_START + day_offset * 86400 + 10#\$h * 3600 + 10#\$m * 60 ))
}

# Simple format-only calls (no -d)
case "\$*" in
  +%s) echo "\$FIXED_EPOCH"; exit 0 ;;
  +%w) echo "\$FIXED_WEEKDAY"; exit 0 ;;
  "+%s "*)  echo "\$FIXED_EPOCH"; exit 0 ;;
esac

# date -d "..." +%s — time calculation
if [[ "\$1" == "-d" && "\${*: -1}" == "+%s" ]]; then
  # Try our parser for today/tomorrow/+N days patterns
  if result=\$(parse_hm "\$2"); then
    echo "\$result"
    exit 0
  fi
  # Fallback to real date for other -d patterns (e.g. uptime -s parsing)
  exec /usr/bin/date "\$@"
fi

# date -d "..." +format (non-%s) — display formatting
if [[ "\$1" == "-d" ]]; then
  exec /usr/bin/date "\$@"
fi

# All other calls — use real date
exec /usr/bin/date "\$@"
MOCKEOF
  chmod +x "${MOCK_BIN}/date"
}

create_mock_uptime() {
  local -- boot_time="${1:-2024-11-01 10:00:00}"
  cat > "${MOCK_BIN}/uptime" <<EOF
#!/usr/bin/env bash
echo "uptime \$*" >> "\${MOCK_LOG:-/dev/null}"
case "\$1" in
  -s) echo "${boot_time}" ;;
  -p) echo "up 10 days, 5 hours" ;;
  *)  echo " 10:00:00 up 10 days,  5:00,  1 user,  load average: 0.00, 0.00, 0.00" ;;
esac
EOF
  chmod +x "${MOCK_BIN}/uptime"
}

create_mock_sudo() {
  cat > "${MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "${MOCK_LOG:-/dev/null}"
# Execute the command without privilege elevation
"$@"
EOF
  chmod +x "${MOCK_BIN}/sudo"
}

create_mock_id() {
  cat > "${MOCK_BIN}/id" <<'EOF'
#!/usr/bin/env bash
echo "sudo"
EOF
  chmod +x "${MOCK_BIN}/id"
}

# create_mock_reboot_required — creates /var/run/reboot-required in test temp
create_mock_reboot_required() {
  mkdir -p "${TEST_TEMP_DIR}/var/run"
  touch "${TEST_TEMP_DIR}/var/run/reboot-required"
}

# ── Assertions ────────────────────────────────────────────────────

assert_output_contains() {
  local -- substring="$1"
  local -- haystack="${output:-}"
  if [[ "$haystack" != *"$substring"* ]]; then
    echo "Expected output to contain: ${substring}"
    echo "Actual output: ${haystack}"
    return 1
  fi
}

assert_output_not_contains() {
  local -- substring="$1"
  local -- haystack="${output:-}"
  if [[ "$haystack" == *"$substring"* ]]; then
    echo "Expected output NOT to contain: ${substring}"
    echo "Actual output: ${haystack}"
    return 1
  fi
}

assert_line_contains() {
  local -i line_num=$1
  local -- substring="$2"
  if [[ "${lines[$line_num]}" != *"$substring"* ]]; then
    echo "Expected line ${line_num} to contain: ${substring}"
    echo "Actual line: ${lines[$line_num]}"
    return 1
  fi
}

assert_mock_called() {
  local -- cmd="$1"
  if [[ ! -f "$MOCK_LOG" ]] || ! grep -q "$cmd" "$MOCK_LOG"; then
    echo "Expected mock to be called with: ${cmd}"
    echo "Mock log: $(cat "$MOCK_LOG" 2>/dev/null || echo '(empty)')"
    return 1
  fi
}

assert_mock_not_called() {
  local -- cmd="$1"
  if [[ -f "$MOCK_LOG" ]] && grep -q "$cmd" "$MOCK_LOG"; then
    echo "Expected mock NOT to be called with: ${cmd}"
    echo "Mock log: $(cat "$MOCK_LOG")"
    return 1
  fi
}

#fin
