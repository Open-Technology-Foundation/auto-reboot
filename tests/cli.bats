#!/usr/bin/env bats
# Tests for main() argument parsing via run_script

setup() {
  load test_helper
  _common_setup
  create_mock_systemctl ""
  create_mock_systemd_run
  create_mock_date 1700006400 2
  create_mock_uptime "2024-11-01 10:00:00"
  create_mock_sudo
  create_mock_id
}

teardown() {
  _common_teardown
}

# ── Help ──────────────────────────────────────────────────────────

@test "cli: -h shows usage" {
  run_script -h
  [[ "$status" -eq 0 ]]
  assert_output_contains "auto-reboot"
  assert_output_contains "USAGE"
}

@test "cli: --help shows usage" {
  run_script --help
  [[ "$status" -eq 0 ]]
  assert_output_contains "OPTIONS"
}

# ── Version ───────────────────────────────────────────────────────

@test "cli: -V shows version" {
  run_script -V
  [[ "$status" -eq 0 ]]
  assert_output_contains "auto-reboot"
  assert_output_contains "1.1.1"
}

@test "cli: --version shows version" {
  run_script --version
  [[ "$status" -eq 0 ]]
  assert_output_contains "1.1.1"
}

# ── Dry run flags ─────────────────────────────────────────────────

@test "cli: -n sets dry run (default)" {
  run_script -n
  [[ "$status" -eq 0 ]]
}

@test "cli: --dry-run is accepted" {
  run_script --dry-run
  [[ "$status" -eq 0 ]]
}

@test "cli: -N sets not-dry-run" {
  run_script -N
  [[ "$status" -eq 0 ]]
}

@test "cli: --not-dry-run is accepted" {
  run_script --not-dry-run
  [[ "$status" -eq 0 ]]
}

# ── Force reboot ──────────────────────────────────────────────────

@test "cli: -f sets force reboot" {
  run_script -f
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
}

@test "cli: --force-reboot sets force" {
  run_script --force-reboot
  [[ "$status" -eq 0 ]]
  assert_output_contains "Force reboot"
}

# ── Max uptime days ───────────────────────────────────────────────

@test "cli: -m sets max uptime days" {
  run_script -m 7
  [[ "$status" -eq 0 ]]
}

@test "cli: --max-uptime-days accepts positive integer" {
  run_script --max-uptime-days 30
  [[ "$status" -eq 0 ]]
}

@test "cli: -m without value fails" {
  run_script -m
  [[ "$status" -ne 0 ]]
  assert_output_contains "requires an argument"
}

@test "cli: -m with non-numeric value fails" {
  run_script -m abc
  [[ "$status" -ne 0 ]]
  assert_output_contains "positive integer"
}

@test "cli: -m 0 fails" {
  run_script -m 0
  [[ "$status" -ne 0 ]]
  assert_output_contains "positive integer"
}

# ── Reboot time ───────────────────────────────────────────────────

@test "cli: -r sets reboot time" {
  run_script -r 04:00
  [[ "$status" -eq 0 ]]
}

@test "cli: --reboot-time accepts HH:MM" {
  run_script --reboot-time 23:59
  [[ "$status" -eq 0 ]]
}

@test "cli: -r without value fails" {
  run_script -r
  [[ "$status" -ne 0 ]]
  assert_output_contains "requires an argument"
}

@test "cli: -r with invalid format fails" {
  run_script -r "noon"
  [[ "$status" -ne 0 ]]
  assert_output_contains "HH:MM"
}

@test "cli: -r 25:00 fails (out of range)" {
  run_script -r 25:00
  [[ "$status" -ne 0 ]]
  assert_output_contains "valid time"
}

@test "cli: -r 12:60 fails (out of range minutes)" {
  run_script -r 12:60
  [[ "$status" -ne 0 ]]
  assert_output_contains "valid time"
}

# ── Allowed days ──────────────────────────────────────────────────

@test "cli: -a sets allowed days" {
  run_script -a Sun
  [[ "$status" -eq 0 ]]
}

@test "cli: --allowed-days accepts comma list" {
  run_script --allowed-days Mon,Wed,Fri
  [[ "$status" -eq 0 ]]
}

@test "cli: -a without value fails" {
  run_script -a
  [[ "$status" -ne 0 ]]
  assert_output_contains "requires an argument"
}

@test "cli: -a with invalid day fails" {
  run_script -a "Funday"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid day"
}

# ── List ──────────────────────────────────────────────────────────

@test "cli: -l lists schedules" {
  run_script -l
  [[ "$status" -eq 0 ]]
  assert_output_contains "Active auto-reboot"
}

@test "cli: --list lists schedules" {
  run_script --list
  [[ "$status" -eq 0 ]]
  assert_output_contains "Active auto-reboot"
}

# ── Delete ────────────────────────────────────────────────────────

@test "cli: -d without value fails" {
  run_script -d
  [[ "$status" -ne 0 ]]
  assert_output_contains "requires an argument"
}

@test "cli: --delete with nonexistent timer fails" {
  run_script --delete 9999999999
  [[ "$status" -ne 0 ]]
  assert_output_contains "not found"
}

# ── Delete all ────────────────────────────────────────────────────

@test "cli: -D delete-all with no timers" {
  run_script -D
  [[ "$status" -eq 0 ]]
  assert_output_contains "No auto-reboot schedules"
}

# ── Unknown option ────────────────────────────────────────────────

@test "cli: unknown option fails" {
  run_script --nonexistent
  [[ "$status" -ne 0 ]]
  assert_output_contains "Unknown option"
}

@test "cli: unknown short option fails" {
  run_script -z
  [[ "$status" -ne 0 ]]
  assert_output_contains "Unknown option"
}

# ── Bundled short options ─────────────────────────────────────────

@test "cli: bundled -Nf works" {
  run_script -Nf
  [[ "$status" -eq 0 ]]
  assert_output_contains "Force reboot"
}

# ── Combined options ──────────────────────────────────────────────

@test "cli: --reboot-time and --allowed-days together" {
  run_script --reboot-time 04:00 --allowed-days Sun
  [[ "$status" -eq 0 ]]
}

@test "cli: multiple options with force reboot" {
  run_script --force-reboot --reboot-time 03:00 --max-uptime-days 7
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
}

#fin
