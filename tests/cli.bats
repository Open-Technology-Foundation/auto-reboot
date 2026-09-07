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
  export PATH="$MOCK_BIN:$ORIG_PATH"
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
  assert_output_contains "auto-reboot $VERSION"
}

@test "cli: --version shows version" {
  run_script --version
  [[ "$status" -eq 0 ]]
  assert_output_contains "$VERSION"
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

# ── Verbose / Quiet ──────────────────────────────────────────────

@test "cli: -v sets verbose (default)" {
  run_script -v
  [[ "$status" -eq 0 ]]
}

@test "cli: --verbose is accepted" {
  run_script --verbose
  [[ "$status" -eq 0 ]]
}

@test "cli: -q sets quiet" {
  run_script -q
  [[ "$status" -eq 0 ]]
}

@test "cli: --quiet suppresses info messages" {
  run_script --quiet -f
  [[ "$status" -eq 0 ]]
  assert_output_not_contains "DRY RUN"
}

@test "cli: -q still shows status output" {
  run_script -q -f
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
}

@test "cli: bundled -Nqf works" {
  run_script -Nqf
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
  assert_output_not_contains "DRY RUN"
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

@test "cli: -m with non-numeric value exits 22" {
  run_script -m abc
  [[ "$status" -eq 22 ]]
  assert_output_contains "positive integer"
}

@test "cli: -m 0 exits 22" {
  run_script -m 0
  [[ "$status" -eq 22 ]]
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

@test "cli: -r with invalid format exits 22" {
  run_script -r "noon"
  [[ "$status" -eq 22 ]]
  assert_output_contains "HH:MM"
}

@test "cli: -r 25:00 exits 22 (out of range)" {
  run_script -r 25:00
  [[ "$status" -eq 22 ]]
  assert_output_contains "valid time"
}

@test "cli: -r 12:60 exits 22 (out of range minutes)" {
  run_script -r 12:60
  [[ "$status" -eq 22 ]]
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

@test "cli: -a with invalid day exits 22" {
  run_script -a "Funday"
  [[ "$status" -eq 22 ]]
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

# ── Invalid option ────────────────────────────────────────────────

@test "cli: unknown option exits 22" {
  run_script --nonexistent
  [[ "$status" -eq 22 ]]
  assert_output_contains "Invalid option"
}

@test "cli: unknown short option exits 22" {
  run_script -z
  [[ "$status" -eq 22 ]]
  assert_output_contains "Invalid option"
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

# ── Leading-zero times (octal regression) ────────────────────────

@test "cli: -r 08:00 is accepted" {
  run_script -f -r 08:00
  [[ "$status" -eq 0 ]]
  assert_output_contains "Delay:"
}

@test "cli: -r 09:30 is accepted" {
  run_script -f -r 09:30
  [[ "$status" -eq 0 ]]
  assert_output_contains "Delay:"
}

@test "cli: -r 22:08 is accepted" {
  run_script -f -r 22:08
  [[ "$status" -eq 0 ]]
  assert_output_contains "Delay:"
}

@test "cli: -m 08 is accepted as 8" {
  run_script -m 08 -f
  [[ "$status" -eq 0 ]]
}

# ── Positional arguments ─────────────────────────────────────────

@test "cli: bare positional argument exits 2" {
  run_script stray
  [[ "$status" -eq 2 ]]
  assert_output_contains "Unexpected argument"
}

@test "cli: positional argument after -- exits 2" {
  run_script -- stray
  [[ "$status" -eq 2 ]]
  assert_output_contains "Unexpected argument"
}

# ── Environment overrides ────────────────────────────────────────

@test "cli: MACHINE_REBOOT_TIME=25:00 exits 22" {
  MACHINE_REBOOT_TIME=25:00 run_script -f
  [[ "$status" -eq 22 ]]
  assert_output_contains "MACHINE_REBOOT_TIME"
}

@test "cli: MACHINE_REBOOT_TIME=08:00 is accepted" {
  MACHINE_REBOOT_TIME=08:00 run_script -f
  [[ "$status" -eq 0 ]]
  assert_output_contains "Delay:"
}

@test "cli: MACHINE_UPTIME_MAXDAYS=0 exits 22" {
  MACHINE_UPTIME_MAXDAYS=0 run_script
  [[ "$status" -eq 22 ]]
  assert_output_contains "MACHINE_UPTIME_MAXDAYS"
}

@test "cli: MACHINE_UPTIME_MAXDAYS=abc exits 22" {
  MACHINE_UPTIME_MAXDAYS=abc run_script
  [[ "$status" -eq 22 ]]
  assert_output_contains "MACHINE_UPTIME_MAXDAYS"
}

@test "cli: MACHINE_UPTIME_MAXDAYS=1 triggers reboot on a 10-day uptime" {
  create_mock_uptime "$(date -d '10 days ago' +'%Y-%m-%d %H:%M:%S')"
  rm -f "$MOCK_BIN"/date
  MACHINE_UPTIME_MAXDAYS=1 run_script
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
}

# ── Delete-all through the CLI ───────────────────────────────────

@test "cli: -D with timers previews in default dry-run mode" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run_script -D
  [[ "$status" -eq 0 ]]
  assert_output_contains "DRY RUN"
  assert_mock_not_called "systemctl stop"
}

@test "cli: -ND without a terminal refuses" {
  local -- timer_line="Thu 2024-11-14 22:00:00 UTC  auto-reboot-1700006400.timer  auto-reboot-1700006400.service"
  create_mock_systemctl "$timer_line"
  run_script -ND </dev/null
  [[ "$status" -eq 1 ]]
  assert_output_contains "non-interactive"
  assert_mock_not_called "systemctl stop"
}

# ── Reboot-required file via CLI ─────────────────────────────────

@test "cli: reboot-required file present is reported as reason" {
  create_mock_reboot_required
  run_script
  [[ "$status" -eq 0 ]]
  assert_output_contains "System updates require reboot"
}

@test "cli: reboot-required absent and low uptime reports not required" {
  create_mock_uptime "$(date -d '1 hour ago' +'%Y-%m-%d %H:%M:%S')"
  rm -f "$MOCK_BIN"/date
  run_script
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot not required"
  assert_output_contains "Reboot-required: absent"
}

# ── Privilege elevation ──────────────────────────────────────────

# These bypass run_script's no-op override: mock sudo only logs, never runs

@test "cli: dry run as non-root does not elevate" {
  ((EUID)) || skip 'running as root'
  run bash -c 'source "$1"; main -f' "$SCRIPT_UNDER_TEST" "$(_sanitize_script)"
  [[ "$status" -eq 0 ]]
  assert_output_contains "Reboot required"
  assert_mock_not_called "sudo"
}

@test "cli: --list as non-root does not elevate" {
  ((EUID)) || skip 'running as root'
  run bash -c 'source "$1"; main --list' "$SCRIPT_UNDER_TEST" "$(_sanitize_script)"
  [[ "$status" -eq 0 ]]
  assert_mock_not_called "sudo"
}

@test "cli: -N as non-root elevates with the original arguments" {
  ((EUID)) || skip 'running as root'
  run bash -c 'source "$1"; main -Nf -r 03:00' "$SCRIPT_UNDER_TEST" "$(_sanitize_script)"
  [[ "$status" -eq 0 ]]
  # Forwarded -r/-m carry the parsed values; the original arguments follow verbatim
  assert_mock_called "sudo -- .*auto-reboot -r 03:00 -m 14 -Nf -r 03:00"
}

@test "cli: -D in dry run as non-root does not elevate" {
  ((EUID)) || skip 'running as root'
  run bash -c 'source "$1"; main -D' "$SCRIPT_UNDER_TEST" "$(_sanitize_script)"
  [[ "$status" -eq 0 ]]
  assert_mock_not_called "sudo"
}

#fin
