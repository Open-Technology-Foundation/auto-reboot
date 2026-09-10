#!/usr/bin/env bats
# Tests for check_reboot_conditions with mocked uptime and reboot-required file

setup() {
  load test_helper
  _common_setup
  # Real date: uptime arithmetic must agree with the boot times generated below
  create_mock_uptime "$(boot_ago 1 hour)"
  source_script
  REBOOT_NEEDED=0
  FORCE_REBOOT=0
  UPTIME_DAYS=0
  MACHINE_UPTIME_MAXDAYS=14
}

teardown() {
  _common_teardown
}

# ── reboot-required file ─────────────────────────────────────────

@test "check_reboot_conditions: reboot-required file present sets REBOOT_NEEDED" {
  create_mock_reboot_required
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 1 ]]
}

@test "check_reboot_conditions: reboot-required file absent leaves REBOOT_NEEDED=0" {
  [[ ! -e $REBOOT_REQUIRED_FILE ]]
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 0 ]]
}

# ── Uptime threshold ─────────────────────────────────────────────

@test "check_reboot_conditions: sets UPTIME_DAYS from uptime" {
  create_mock_uptime "$(boot_ago 5 days)"
  check_reboot_conditions
  [[ "$UPTIME_DAYS" -eq 5 ]]
}

@test "check_reboot_conditions: high uptime exceeds threshold" {
  create_mock_uptime '2023-01-01 00:00:00'
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 1 ]]
}

@test "check_reboot_conditions: low uptime below threshold" {
  create_mock_uptime "$(boot_ago 2 days)"
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 0 ]]
}

@test "check_reboot_conditions: uptime equal to threshold triggers reboot" {
  create_mock_uptime "$(boot_ago 14 days)"
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 1 ]]
}

# ── Force reboot ─────────────────────────────────────────────────

@test "check_reboot_conditions: force reboot sets REBOOT_NEEDED" {
  FORCE_REBOOT=1
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 1 ]]
}

@test "check_reboot_conditions: force reboot overrides low uptime" {
  FORCE_REBOOT=1
  MACHINE_UPTIME_MAXDAYS=999
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 1 ]]
}

# ── Combined conditions ──────────────────────────────────────────

@test "check_reboot_conditions: no conditions met leaves REBOOT_NEEDED=0" {
  MACHINE_UPTIME_MAXDAYS=999
  check_reboot_conditions
  [[ "$REBOOT_NEEDED" -eq 0 ]]
}

@test "check_reboot_conditions: UPTIME_DAYS calculated correctly" {
  create_mock_uptime "$(boot_ago 10 days)"
  check_reboot_conditions
  [[ "$UPTIME_DAYS" -eq 10 ]]
}

@test "check_reboot_conditions: uptime failure aborts instead of guessing" {
  cat > "$MOCK_BIN"/uptime <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "$MOCK_BIN"/uptime
  run check_reboot_conditions
  [[ "$status" -ne 0 ]]
  assert_output_contains "uptime"
}

#fin
