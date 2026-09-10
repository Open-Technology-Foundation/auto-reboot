#!/usr/bin/env bats
# Tests for /etc/auto-reboot.conf loading: precedence, validation, trust checks.
# CONF_FILE is redirected to a temp path via AUTO_REBOOT_CONF; stat is mocked
# so ownership and mode are controlled by the test, not the filesystem.

setup() {
  load test_helper
  _common_setup
  create_mock_systemctl ""
  create_mock_systemd_run
  create_mock_date 1700006400 2
  create_mock_uptime "2024-11-01 10:00:00"
  create_mock_sudo
  create_mock_id
  create_mock_stat
  export PATH="$MOCK_BIN:$ORIG_PATH"
}

teardown() {
  _common_teardown
}

write_conf() { printf '%s\n' "$@" > "$AUTO_REBOOT_CONF"; }

# Delay in seconds printed by a dry run; the clock is mocked so it is stable
delay_of() {
  run_script "$@"
  [[ $status -eq 0 ]] || { >&2 echo "run_script $* failed: $output"; return 1; }
  sed -n 's/^Delay: //p' <<< "$output"
}

# ── Defaults and precedence ──────────────────────────────────────

@test "config: absent file falls back to built-in defaults" {
  run_script -f
  [[ $status -eq 0 ]]
  assert_output_contains "Delay:"
}

@test "config: MACHINE_REBOOT_TIME from the file sets the reboot time" {
  local -- from_conf from_cli
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  from_conf=$(delay_of -f)
  rm -f "$AUTO_REBOOT_CONF"
  from_cli=$(delay_of -f -r 08:00)
  [[ -n $from_conf && $from_conf == "$from_cli" ]]
}

@test "config: --reboot-time overrides the file" {
  local -- with_conf without_conf
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  with_conf=$(delay_of -f -r 09:00)
  rm -f "$AUTO_REBOOT_CONF"
  without_conf=$(delay_of -f -r 09:00)
  [[ -n $with_conf && $with_conf == "$without_conf" ]]
}

@test "config: MACHINE_UPTIME_MAXDAYS=1 triggers reboot on a 10-day uptime" {
  create_mock_uptime "$(date -d '10 days ago' +'%Y-%m-%d %H:%M:%S')"
  rm -f "$MOCK_BIN"/date
  write_conf 'MACHINE_UPTIME_MAXDAYS=1'
  run_script
  [[ $status -eq 0 ]]
  assert_output_contains "Reboot required"
}

@test "config: MACHINE_ALLOWED_DAYS restricts the reboot day" {
  local -- from_conf from_cli
  write_conf 'MACHINE_ALLOWED_DAYS=Sun'
  from_conf=$(delay_of -f)
  rm -f "$AUTO_REBOOT_CONF"
  from_cli=$(delay_of -f -a Sun)
  [[ -n $from_conf && $from_conf == "$from_cli" ]]
}

@test "config: --allowed-days '' clears the file's day restriction" {
  local -- cleared unrestricted
  write_conf 'MACHINE_ALLOWED_DAYS=Sun'
  cleared=$(delay_of -f -a '')
  rm -f "$AUTO_REBOOT_CONF"
  unrestricted=$(delay_of -f)
  [[ -n $cleared && $cleared == "$unrestricted" ]]
}

@test "config: --help names the config file" {
  run_script --help
  [[ $status -eq 0 ]]
  assert_output_contains "$AUTO_REBOOT_CONF"
}

# ── Validation ───────────────────────────────────────────────────

@test "config: invalid MACHINE_REBOOT_TIME exits 19 naming the file" {
  write_conf 'MACHINE_REBOOT_TIME=25:00'
  run_script -f
  [[ $status -eq 19 ]]
  assert_output_contains "MACHINE_REBOOT_TIME"
  assert_output_contains "$AUTO_REBOOT_CONF"
}

@test "config: invalid MACHINE_UPTIME_MAXDAYS exits 19" {
  write_conf 'MACHINE_UPTIME_MAXDAYS=0'
  run_script
  [[ $status -eq 19 ]]
  assert_output_contains "MACHINE_UPTIME_MAXDAYS"
}

@test "config: invalid MACHINE_ALLOWED_DAYS exits 19" {
  write_conf 'MACHINE_ALLOWED_DAYS=Funday'
  run_script
  [[ $status -eq 19 ]]
  assert_output_contains "MACHINE_ALLOWED_DAYS"
}

@test "config: a file that fails to source exits 19, never half-applied" {
  write_conf 'MACHINE_REBOOT_TIME=03:00' 'MACHINE_UPTIME_MAXDAYS=('
  run_script -f
  [[ $status -eq 19 ]]
  assert_output_contains "$AUTO_REBOOT_CONF"
}

@test "config: --reboot-time 25:00 on the command line still exits 22" {
  run_script -r 25:00
  [[ $status -eq 22 ]]
}

# ── Trust checks (the file is sourced as bash, as root) ──────────

@test "config: file not owned by root exits 13" {
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  create_mock_stat '1000 644'
  run_script
  [[ $status -eq 13 ]]
  assert_output_contains "owned by root"
}

@test "config: group-writable file exits 13" {
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  create_mock_stat '0 664'
  run_script
  [[ $status -eq 13 ]]
  assert_output_contains "writable"
}

@test "config: world-writable file exits 13" {
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  create_mock_stat '0 666'
  run_script
  [[ $status -eq 13 ]]
  assert_output_contains "writable"
}

@test "config: read-only root-owned file is accepted" {
  write_conf 'MACHINE_REBOOT_TIME=08:00'
  create_mock_stat '0 444'
  run_script -f
  [[ $status -eq 0 ]]
}
