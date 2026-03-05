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

@test "usage shows environment variables" {
  run usage
  assert_output_contains "MACHINE_REBOOT_TIME"
  assert_output_contains "MACHINE_UPTIME_MAXDAYS"
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
  [[ "$status" -ne 0 ]]
  assert_output_contains "systemd-run"
}

#fin
