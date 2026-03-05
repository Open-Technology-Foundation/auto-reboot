#!/usr/bin/env bats
# Tests for schedule_reboot, list_schedules, delete_schedule, delete_all_schedules

setup() {
  load test_helper
  _common_setup
  create_mock_systemctl ""
  create_mock_systemd_run
  create_mock_date 1700006400 2
  source_script
  DRY_RUN=1
  UPTIME_DAYS=10
}

teardown() {
  _common_teardown
}

# ── schedule_reboot ───────────────────────────────────────────────

@test "schedule_reboot: dry run outputs message" {
  DRY_RUN=1
  run schedule_reboot 3600
  [[ "$status" -eq 0 ]]
  assert_output_contains "DRY RUN"
  assert_output_contains "3600"
}

@test "schedule_reboot: actual run calls systemd-run" {
  DRY_RUN=0
  run schedule_reboot 3600
  [[ "$status" -eq 0 ]]
  assert_mock_called "systemd-run"
  assert_mock_called "logger"
}

@test "schedule_reboot: actual run logs to syslog" {
  DRY_RUN=0
  schedule_reboot 7200
  assert_mock_called "logger"
}

@test "schedule_reboot: dry run does not call systemd-run" {
  DRY_RUN=1
  schedule_reboot 3600 2>/dev/null
  assert_mock_not_called "systemd-run"
}

@test "schedule_reboot: handles systemd not running" {
  # Override systemctl to report failure
  cat > "${MOCK_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  is-system-running) echo "offline"; exit 2 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/systemctl"

  run schedule_reboot 3600
  [[ "$status" -ne 0 ]]
  assert_output_contains "systemd is not running"
}

@test "schedule_reboot: handles systemd degraded state" {
  cat > "${MOCK_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  is-system-running) echo "degraded"; exit 1 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/systemctl"

  DRY_RUN=1
  run schedule_reboot 3600
  # Degraded (exit 1) should be allowed
  [[ "$status" -eq 0 ]]
}

# ── list_schedules ────────────────────────────────────────────────

@test "list_schedules: no timers" {
  create_mock_systemctl ""
  run list_schedules
  [[ "$status" -eq 0 ]]
  assert_output_contains "No active"
}

@test "list_schedules: shows header" {
  create_mock_systemctl ""
  run list_schedules
  assert_output_contains "Active auto-reboot schedules:"
  assert_output_contains "============================="
}

@test "list_schedules: shows timers when present" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run list_schedules
  [[ "$status" -eq 0 ]]
  assert_output_contains "auto-reboot-1700006400.timer"
  assert_output_contains "Total: 1"
}

@test "list_schedules: shows multiple timers" {
  local -- timer_lines
  timer_lines="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service
Fri 2024-11-15 04:00:00 UTC  auto-reboot-1700028000.timer  auto-reboot-1700028000.service"
  create_mock_systemctl "$timer_lines"
  run list_schedules
  [[ "$status" -eq 0 ]]
  assert_output_contains "Total: 2"
}

# ── delete_schedule ───────────────────────────────────────────────

@test "delete_schedule: full timer name" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run delete_schedule "auto-reboot-1700006400.timer"
  [[ "$status" -eq 0 ]]
  assert_output_contains "Successfully deleted"
}

@test "delete_schedule: numeric ID only" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run delete_schedule "1700006400"
  [[ "$status" -eq 0 ]]
  assert_output_contains "Successfully deleted"
}

@test "delete_schedule: partial name (no .timer suffix)" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run delete_schedule "auto-reboot-1700006400"
  [[ "$status" -eq 0 ]]
  assert_output_contains "Successfully deleted"
}

@test "delete_schedule: timer not found" {
  create_mock_systemctl ""
  run delete_schedule "auto-reboot-9999999999.timer"
  [[ "$status" -ne 0 ]]
  assert_output_contains "not found"
}

@test "delete_schedule: invalid format" {
  run delete_schedule "invalid-name"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid timer name"
}

@test "delete_schedule: stops both timer and service" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  delete_schedule "1700006400"
  assert_mock_called "systemctl stop auto-reboot-1700006400.timer"
  assert_mock_called "systemctl stop auto-reboot-1700006400.service"
}

@test "delete_schedule: logs deletion" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  delete_schedule "1700006400"
  assert_mock_called "logger"
}

# ── delete_all_schedules ─────────────────────────────────────────

@test "delete_all_schedules: no timers to delete" {
  create_mock_systemctl ""
  run delete_all_schedules
  [[ "$status" -eq 0 ]]
  assert_output_contains "No auto-reboot schedules found"
}

@test "delete_all_schedules: dry run deletes without confirmation" {
  local -- timer_lines
  timer_lines="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_lines"
  DRY_RUN=1
  # DRY_RUN mode still goes through delete path (no confirmation needed)
  # But delete_schedule calls systemctl which checks for timer existence
  run delete_all_schedules
  [[ "$status" -eq 0 ]]
}

#fin
