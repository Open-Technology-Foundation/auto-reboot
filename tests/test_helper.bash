#
# test_helper.bash - Common test utilities for auto-reboot BATS tests
#
# Provides:
# - _common_setup/_common_teardown with temp dirs and mock PATH
# - source_script() to source auto-reboot for unit testing individual functions
# - run_script() to run main() in a subshell for CLI/integration testing
# - Mock creators for systemctl, systemd-run, logger, date, uptime, sudo, id,
#   install, and the reboot-required file
# - Custom assertions
#
# Test hooks used by the script itself (no source mutation needed):
#   REBOOT_REQUIRED_FILE  path checked instead of /var/run/reboot-required
#   PREFIX                install target for --install
#   elevate_to_root()     overridden with a no-op after sourcing
#

# Load BATS helper libraries
load '/usr/local/lib/bats-support/load.bash' 2>/dev/null ||:
load '/usr/local/lib/bats-assert/load.bash' 2>/dev/null ||:

# Test configuration (plain assignments: this file is loaded from inside
# setup(), where declare would create function-local variables)
BATS_TEST_DIRNAME=${BATS_TEST_DIRNAME:-${BASH_SOURCE[0]%/*}}
PROJECT_ROOT=$(realpath -- "$BATS_TEST_DIRNAME"/..)
SCRIPT_UNDER_TEST="$PROJECT_ROOT"/auto-reboot
ORIG_PATH=$PATH

# Version comes from the script; there is no second copy to keep in sync
VERSION=$(sed -n 's/^declare -r VERSION=//p' "$SCRIPT_UNDER_TEST")
export VERSION

# Mock creators

create_mock_logger() {
  cat > "$MOCK_BIN"/logger <<'MOCK'
#!/usr/bin/env bash
echo "logger $*" >> "${MOCK_LOG:-/dev/null}"
MOCK
  chmod +x "$MOCK_BIN"/logger
}

# create_mock_systemctl [TIMER_LINES] [STOP_RC]
#   TIMER_LINES  printed by `systemctl list-timers` whatever the unit argument
#                (default: none); real lines read NEXT LEFT LAST PASSED UNIT ACTIVATES
#   STOP_RC      exit status of `systemctl stop` (default: 0)
create_mock_systemctl() {
  local -- timer_output=${1:-}
  local -i stop_rc=${2:-0}
  cat > "$MOCK_BIN"/systemctl <<MOCK
#!/usr/bin/env bash
echo "systemctl \$*" >> "\${MOCK_LOG:-/dev/null}"
case \$1 in
  is-system-running) echo running; exit 0 ;;
  list-timers) printf '%s\n' "${timer_output}" ;;
  stop) exit ${stop_rc} ;;
  *) exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_BIN"/systemctl
}

create_mock_systemd_run() {
  cat > "$MOCK_BIN"/systemd-run <<'MOCK'
#!/usr/bin/env bash
echo "systemd-run $*" >> "${MOCK_LOG:-/dev/null}"
exit 0
MOCK
  chmod +x "$MOCK_BIN"/systemd-run
}

# create_mock_date [EPOCH] [WEEKDAY] — a date mock with a fixed clock.
#
#   date +%s                    → EPOCH (default 1700000000)
#   date +%w                    → WEEKDAY (default 3 = Wednesday)
#   date -d "today H:M" +%s     → midnight-UTC-of-EPOCH + H:M
#   date -d "tomorrow H:M" +%s  → + 86400
#   date -d "+N days H:M" +%s   → + N*86400
#   anything else               → real date (display formatting, uptime parse)
create_mock_date() {
  local -i fixed_epoch=${1:-1700000000}
  local -i fixed_weekday=${2:-3}
  cat > "$MOCK_BIN"/date <<MOCK
#!/usr/bin/env bash
FIXED_EPOCH=${fixed_epoch}
FIXED_WEEKDAY=${fixed_weekday}
DAY_START=\$(( FIXED_EPOCH - (FIXED_EPOCH % 86400) ))

parse_hm() {
  # H:M with 1-2 digits each; 10# guards against octal (08, 09)
  local args="\$*"
  local day_offset=0 h=0 m=0
  if [[ "\$args" =~ today\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=0; h=\${BASH_REMATCH[1]}; m=\${BASH_REMATCH[2]}
  elif [[ "\$args" =~ tomorrow\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=1; h=\${BASH_REMATCH[1]}; m=\${BASH_REMATCH[2]}
  elif [[ "\$args" =~ \+([0-9]+)\ +days?\ +([0-9]{1,2}):([0-9]{1,2}) ]]; then
    day_offset=\${BASH_REMATCH[1]}; h=\${BASH_REMATCH[2]}; m=\${BASH_REMATCH[3]}
  else
    return 1
  fi
  echo \$(( DAY_START + day_offset * 86400 + 10#\$h * 3600 + 10#\$m * 60 ))
}

case "\$*" in
  +%s|"+%s "*) echo "\$FIXED_EPOCH"; exit 0 ;;
  +%w)         echo "\$FIXED_WEEKDAY"; exit 0 ;;
esac

if [[ "\$1" == -d && "\${*: -1}" == +%s ]]; then
  if result=\$(parse_hm "\$2"); then
    echo "\$result"
    exit 0
  fi
fi
exec /usr/bin/date "\$@"
MOCK
  chmod +x "$MOCK_BIN"/date
}

create_mock_uptime() {
  local -- boot_time=${1:-2024-11-01 10:00:00}
  cat > "$MOCK_BIN"/uptime <<MOCK
#!/usr/bin/env bash
echo "uptime \$*" >> "\${MOCK_LOG:-/dev/null}"
case \$1 in
  -s) echo "${boot_time}" ;;
  -p) echo 'up 10 days, 5 hours' ;;
  *)  echo ' 10:00:00 up 10 days,  5:00,  1 user,  load average: 0.00, 0.00, 0.00' ;;
esac
MOCK
  chmod +x "$MOCK_BIN"/uptime
}

# Logs the sudo command line and stops; never runs the target
create_mock_sudo() {
  cat > "$MOCK_BIN"/sudo <<'MOCK'
#!/usr/bin/env bash
echo "sudo $*" >> "${MOCK_LOG:-/dev/null}"
exit 0
MOCK
  chmod +x "$MOCK_BIN"/sudo
}

# create_mock_id [GROUPS] — `id -nG` output (default: member of sudo)
create_mock_id() {
  local -- groups=${1:-sudo}
  cat > "$MOCK_BIN"/id <<MOCK
#!/usr/bin/env bash
echo '${groups}'
MOCK
  chmod +x "$MOCK_BIN"/id
}

# Logs the install command line and stops; never writes to the system
create_mock_install() {
  cat > "$MOCK_BIN"/install <<'MOCK'
#!/usr/bin/env bash
echo "install $*" >> "${MOCK_LOG:-/dev/null}"
exit 0
MOCK
  chmod +x "$MOCK_BIN"/install
}

# Creates the file the script checks via REBOOT_REQUIRED_FILE
create_mock_reboot_required() {
  mkdir -p "${REBOOT_REQUIRED_FILE%/*}"
  touch "$REBOOT_REQUIRED_FILE"
}

# Setup and teardown

_common_setup() {
  TEST_TEMP_DIR=$(mktemp -d /tmp/auto-reboot-test-"${BATS_TEST_NUMBER:-0}"-XXXXXX) \
    || { echo 'mktemp failed' >&2; return 1; }
  MOCK_BIN="$TEST_TEMP_DIR"/mock-bin
  MOCK_LOG="$TEST_TEMP_DIR"/mock.log
  mkdir -p "$MOCK_BIN" || return 1

  # Absent by default: every test starts from "no reboot-required"
  REBOOT_REQUIRED_FILE="$TEST_TEMP_DIR"/var/run/reboot-required
  PREFIX="$TEST_TEMP_DIR"/prefix

  # Always needed: the script calls logger on every state change
  create_mock_logger

  # MOCK_LOG reaches the mock binaries; the rest reach functions sourced
  # inside setup() (declare there is function-local, see source_script)
  export TEST_TEMP_DIR MOCK_BIN MOCK_LOG REBOOT_REQUIRED_FILE PREFIX
}

_common_teardown() {
  if [[ -n ${TEST_TEMP_DIR:-} && -d $TEST_TEMP_DIR ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
  export PATH=$ORIG_PATH
}

# Sanitised script copy

# _sanitize_script — writes a copy of auto-reboot with four whole-line edits:
#   1. declare -rx PATH=...       removed (mock binaries must win PATH lookup)
#   2. set -euo pipefail          -e dropped so BATS reports failures itself
#   3. shopt -s inherit_errexit   removed (meaningless without -e)
#   4. main "$@"                  removed (sourcing must not run the script)
# Every other line is the real script. Prints the copy's path.
_sanitize_script() {
  local -- sanitized="$TEST_TEMP_DIR"/auto-reboot-sanitized
  sed \
    -e '/^declare -rx PATH=/d' \
    -e 's/^set -euo pipefail$/set -uo pipefail/' \
    -e '/^shopt -s inherit_errexit$/d' \
    -e '/^main "\$@"$/d' \
    "$SCRIPT_UNDER_TEST" > "$sanitized" || return 1
  echo "$sanitized"
}

# source_script — sources the sanitised script into the current shell so
# individual functions can be unit-tested with mocks on PATH.
#
# Sourcing happens inside setup(), so the script's own `declare` lines create
# function-local variables that vanish when setup() returns. The values the
# functions need afterwards are exported here so they persist as globals.
source_script() {
  local -- sanitized
  sanitized=$(_sanitize_script)

  export PATH="$MOCK_BIN:$ORIG_PATH"
  export SCRIPT_PATH=$SCRIPT_UNDER_TEST
  export SCRIPT_NAME=auto-reboot
  export XUSER=${USER:-testuser}
  export RED='' CYAN='' YELLOW='' NC=''
  export VERBOSE=1

  # shellcheck disable=SC1090 # path is built at runtime
  source "$sanitized"

  # Never attempt sudo from inside the test suite
  # shellcheck disable=SC2329 # overrides the script function; invoked by main()
  elevate_to_root() { :; }
}

# run_script — runs main() with arguments in a clean subshell and sets the
# BATS $status/$output variables. $0 is the real script path so the script's
# own metadata (SCRIPT_PATH, SCRIPT_NAME, VERSION, XUSER) resolves unchanged.
run_script() {
  local -- sanitized
  sanitized=$(_sanitize_script)

  run bash -c '
    export PATH="$1"
    source "$2"
    elevate_to_root() { :; }
    shift 2
    main "$@"
  ' "$SCRIPT_UNDER_TEST" "$MOCK_BIN:$ORIG_PATH" "$sanitized" "$@"
}

# Assertions

# Diagnostics go to stderr; BATS shows both streams when a test fails

assert_output_contains() {
  local -- substring=$1
  local -- haystack=${output:-}
  if [[ $haystack != *"$substring"* ]]; then
    >&2 echo "Expected output to contain: $substring"
    >&2 echo "Actual output: $haystack"
    return 1
  fi
}

assert_output_not_contains() {
  local -- substring=$1
  local -- haystack=${output:-}
  if [[ $haystack == *"$substring"* ]]; then
    >&2 echo "Expected output NOT to contain: $substring"
    >&2 echo "Actual output: $haystack"
    return 1
  fi
}

# assert_mock_called PATTERN — PATTERN is a grep regex against the mock log
assert_mock_called() {
  local -- cmd=$1 log='(empty)'
  if [[ ! -f $MOCK_LOG ]] || ! grep -q -- "$cmd" "$MOCK_LOG"; then
    [[ ! -f $MOCK_LOG ]] || log=$(< "$MOCK_LOG")
    >&2 echo "Expected mock to be called with: $cmd"
    >&2 echo "Mock log: $log"
    return 1
  fi
}

assert_mock_not_called() {
  local -- cmd=$1
  if [[ -f $MOCK_LOG ]] && grep -q -- "$cmd" "$MOCK_LOG"; then
    >&2 echo "Expected mock NOT to be called with: $cmd"
    >&2 echo "Mock log: $(< "$MOCK_LOG")"
    return 1
  fi
}

#fin
