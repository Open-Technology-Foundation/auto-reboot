#!/usr/bin/env bats
# Tests for utility functions: _msg, error, info, die, noarg, usage, systemd_run_required

setup() {
  load test_helper
  _common_setup
  source_script
}

teardown() {
  _common_teardown
}

# ── _msg ──────────────────────────────────────────────────────────

@test "_msg outputs prefix with script name" {
  run _msg "hello world"
  assert_output_contains "auto-reboot:"
  assert_output_contains "hello world"
}

@test "_msg handles multiple arguments" {
  run _msg "line one" "line two"
  assert_output_contains "line one"
  assert_output_contains "line two"
}

# ── error ─────────────────────────────────────────────────────────

@test "error outputs to stderr" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'" 2>&1 1>/dev/null; error "test error" 2>&1'
  # When captured, error output should contain the message
  [[ "$status" -eq 0 ]]
}

@test "error includes script name" {
  local -- result
  result=$(error "failure message" 2>&1)
  [[ "$result" == *"auto-reboot:"* ]]
  [[ "$result" == *"failure message"* ]]
}

# ── info ──────────────────────────────────────────────────────────

@test "info outputs to stderr" {
  local -- result
  result=$(info "info message" 2>&1)
  [[ "$result" == *"auto-reboot:"* ]]
  [[ "$result" == *"info message"* ]]
}

@test "info handles multiple messages" {
  local -- result
  result=$(info "msg1" "msg2" 2>&1)
  [[ "$result" == *"msg1"* ]]
  [[ "$result" == *"msg2"* ]]
}

# ── die ───────────────────────────────────────────────────────────

@test "die exits with specified code" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; die 42 "fatal error"'
  [[ "$status" -eq 42 ]]
}

@test "die exits with 0 when no code given" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; die'
  [[ "$status" -eq 0 ]]
}

@test "die outputs error message" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; die 1 "something broke" 2>&1'
  assert_output_contains "something broke"
}

@test "die with only exit code and no message" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; die 5'
  [[ "$status" -eq 5 ]]
}

# ── noarg ─────────────────────────────────────────────────────────

@test "noarg passes when argument provided" {
  run noarg "--option" "value"
  [[ "$status" -eq 0 ]]
}

@test "noarg fails when no argument" {
  run bash -c 'source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; noarg "--option"'
  [[ "$status" -eq 22 ]]
  assert_output_contains "requires an argument"
}

# ── usage ─────────────────────────────────────────────────────────

@test "usage exits with 0" {
  run usage
  [[ "$status" -eq 0 ]]
}

@test "usage shows script name" {
  run usage
  assert_output_contains "auto-reboot"
}

@test "usage shows version" {
  run usage
  assert_output_contains "$VERSION"
}

@test "usage shows all main options" {
  run usage
  assert_output_contains "--force-reboot"
  assert_output_contains "--dry-run"
  assert_output_contains "--not-dry-run"
  assert_output_contains "--help"
  assert_output_contains "--install"
  assert_output_contains "--version"
}

@test "usage shows schedule management options" {
  run usage
  assert_output_contains "--list"
  assert_output_contains "--delete"
  assert_output_contains "--delete-all"
}

@test "usage shows the config file and its keys" {
  run usage
  assert_output_contains "$CONF_FILE"
  assert_output_contains "MACHINE_REBOOT_TIME"
  assert_output_contains "MACHINE_UPTIME_MAXDAYS"
  assert_output_contains "MACHINE_ALLOWED_DAYS"
}

@test "usage shows allowed-days option" {
  run usage
  assert_output_contains "--allowed-days"
  assert_output_contains "Sun,Mon"
}

# ── systemd_run_required ─────────────────────────────────────────

@test "systemd_run_required succeeds when systemd-run exists" {
  create_mock_systemd_run
  run systemd_run_required
  [[ "$status" -eq 0 ]]
}

@test "systemd_run_required fails when systemd-run missing" {
  # Remove systemd-run from PATH by using a restricted PATH
  run bash -c 'export PATH="'"${TEST_TEMP_DIR}/empty-bin"'"; source "'"${TEST_TEMP_DIR}/auto-reboot-sanitized"'"; systemd_run_required 2>&1'
  [[ "$status" -eq 18 ]]
  assert_output_contains "systemd-run"
}

# ── validators ───────────────────────────────────────────────────

@test "validate_time: accepts leading-zero hour and minute" {
  validate_time 08:09
}

@test "validate_time: rejects hour 24 and minute 60" {
  ! validate_time 24:00
  ! validate_time 12:60
}

@test "validate_time: rejects non-time text" {
  ! validate_time noon
  ! validate_time 22
}

@test "validate_days: accepts positive integers including leading zero" {
  validate_days 14
  validate_days 08
}

@test "validate_days: rejects zero, negative and text" {
  ! validate_days 0
  ! validate_days -3
  ! validate_days abc
}

# ── elevate_to_root ──────────────────────────────────────────────

@test "elevate_to_root: replays the original arguments through sudo" {
  ((EUID)) || skip 'running as root'
  create_mock_sudo
  create_mock_id sudo
  # Fresh shell: source_script() replaces elevate_to_root with a no-op
  run bash -c 'source "$1"; elevate_to_root -Nf --allowed-days Sun' \
    "$SCRIPT_UNDER_TEST" "$TEST_TEMP_DIR/auto-reboot-sanitized"
  [[ "$status" -eq 0 ]]
  assert_mock_called "sudo -- .*auto-reboot -Nf --allowed-days Sun$"
}

@test "elevate_to_root: dies 13 when not in sudo group" {
  ((EUID)) || skip 'running as root'
  create_mock_sudo
  create_mock_id users
  run bash -c 'source "$1"; elevate_to_root' "$SCRIPT_UNDER_TEST" "$TEST_TEMP_DIR/auto-reboot-sanitized"
  [[ "$status" -eq 13 ]]
  assert_mock_not_called "sudo"
}

# ── install_auto_reboot ──────────────────────────────────────────

@test "install_auto_reboot: installs a root-owned 0755 copy under PREFIX" {
  create_mock_install
  run install_auto_reboot
  [[ "$status" -eq 0 ]]
  assert_mock_called "install -m 755 -o root -g root -- .*auto-reboot $PREFIX/bin/auto-reboot"
}

@test "install_auto_reboot: never runs apt, even without systemd-run on PATH" {
  create_mock_install
  create_mock_sudo
  PATH=$MOCK_BIN run install_auto_reboot
  assert_mock_not_called "apt-get"
}

#fin
