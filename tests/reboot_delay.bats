#!/usr/bin/env bats
# Tests for calculate_reboot_delay with mocked date

setup() {
  load test_helper
  _common_setup
  source_script
  ALLOWED_DAYS=()
}

teardown() {
  _common_teardown
}

# ── Basic delay (no day restrictions) ─────────────────────────────

@test "calculate_reboot_delay: time in future today" {
  # Current: 16:00, target: 22:00 → today 22:00 - now
  # day_start=1699920000, target=1699920000+22*3600=1699999200
  # delay = 1699999200 - 1700006400 = -7200... wait that's negative
  # Actually: 1699920000 + 22*3600 + 0*60 = 1699920000 + 79200 = 1699999200
  # 1699999200 - 1700006400 = -7200 (time already passed)
  # Let me recalculate: epoch=1700006400, day_start = 1700006400 - (1700006400 % 86400)
  # 1700006400 % 86400 = 1700006400 - 19675*86400 = 1700006400 - 1695600000 = 4406400
  # Hmm, let me use a simpler epoch.
  # Use epoch where 22:00 is in the future: say it's 10:00 UTC
  # 10:00 UTC = 36000 seconds into day
  pin_clock 1699956000  # day_start + 36000 = 10:00 UTC
  ALLOWED_DAYS=()

  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  # target: day_start + 22*3600 = day_start + 79200
  # delay = (day_start + 79200) - (day_start + 36000) = 43200
  [[ "$output" == "43200" ]]
}

@test "calculate_reboot_delay: time already passed schedules tomorrow" {
  # Current: 23:00, target: 04:00 → tomorrow 04:00
  # Use day_start + 23*3600 = day_start + 82800
  pin_clock 1700002800  # 1699920000 + 82800 = 23:00 UTC
  ALLOWED_DAYS=()

  run calculate_reboot_delay "04:00"
  [[ "$status" -eq 0 ]]
  # target tomorrow: day_start + 86400 + 4*3600 = day_start + 86400 + 14400 = day_start + 100800
  # delay = (day_start + 100800) - (day_start + 82800) = 18000 (5 hours)
  [[ "$output" == "18000" ]]
}

@test "calculate_reboot_delay: exact current time schedules tomorrow" {
  # If target == current, it should schedule tomorrow
  # epoch at 22:00 exactly: day_start + 79200
  pin_clock 1699999200
  ALLOWED_DAYS=()

  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  # Should be 86400 (tomorrow same time)
  [[ "$output" == "86400" ]]
}

# ── Invalid time format ──────────────────────────────────────────

@test "calculate_reboot_delay: invalid format rejected" {
  run calculate_reboot_delay "not-a-time"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid time format"
}

@test "calculate_reboot_delay: missing minutes rejected" {
  run calculate_reboot_delay "22"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid time format"
}

# ── With allowed days ────────────────────────────────────────────

@test "calculate_reboot_delay: today allowed and time in future" {
  # Tuesday (2), allowed=[2,4], time in future
  pin_clock 1699956000  # 10:00 UTC, Tuesday
  ALLOWED_DAYS=(2 4)  # Tue, Thu

  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  # Today is allowed and 22:00 is in future → same as no-restriction
  [[ "$output" == "43200" ]]
}

@test "calculate_reboot_delay: today not allowed finds next allowed day" {
  # Tuesday (2), allowed=[4] (Thursday only)
  pin_clock 1699956000  # 10:00 UTC, Tuesday
  ALLOWED_DAYS=(4)  # Thursday only

  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  # Next Thursday is 2 days ahead: day_start + 2*86400 + 79200
  # delay = (day_start + 172800 + 79200) - (day_start + 36000) = 216000
  [[ "$output" == "216000" ]]
}

@test "calculate_reboot_delay: today allowed but time passed finds next allowed" {
  # Tuesday (2) at 23:00, allowed=[2,5], target=04:00
  # Today is allowed but 04:00 already passed → skip today
  # Next Tuesday is in 7 days, but Friday (5) is in 3 days
  pin_clock 1700002800  # 23:00 UTC, Tuesday
  ALLOWED_DAYS=(2 5)  # Tue, Fri

  run calculate_reboot_delay "04:00"
  [[ "$status" -eq 0 ]]
  # days_ahead=1 → Wed(3) not in [2,5]
  # days_ahead=2 → Thu(4) not in [2,5]
  # days_ahead=3 → Fri(5) in [2,5] → +3 days 04:00
  # delay = (day_start + 3*86400 + 14400) - (day_start + 82800) = 259200 + 14400 - 82800 = 190800
  [[ "$output" == "190800" ]]
}

@test "calculate_reboot_delay: Sunday wrap-around" {
  # Saturday (6), allowed=[0] (Sunday only), time in future
  pin_clock 1700301600  # Sat 2023-11-18 10:00 UTC
  ALLOWED_DAYS=(0)  # Sunday only

  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  # Today (Sat) not allowed (is_reboot_day_allowed returns 1)
  # days_ahead=1 → (6+1)%7=0 → Sunday, match!
  # delay = (day_start + 86400 + 79200) - (day_start + 36000) = 129600
  [[ "$output" == "129600" ]]
}

# ── Clock source ─────────────────────────────────────────────────

@test "calculate_reboot_delay: leading-zero time resolves through real date -d" {
  # pinned Wed 00:00 UTC → 08:09 today is 29340s away
  run calculate_reboot_delay "08:09"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "29340" ]]
}

@test "calculate_reboot_delay: date failure returns error, never a negative delay" {
  run calculate_reboot_delay "25:00"
  [[ "$status" -ne 0 ]]
  [[ ! $output =~ (^|[[:space:]])-[0-9]+ ]]
}

@test "calculate_reboot_delay: never asks date(1) for the current time or weekday" {
  # A date that refuses +%s/+%w: only the builtin clock may answer those
  cat > "$MOCK_BIN"/date <<'MOCK'
#!/usr/bin/env bash
case $* in +%s|+%w) echo 'date asked for now' >&2; exit 1 ;; esac
exec /usr/bin/date "$@"
MOCK
  chmod +x "$MOCK_BIN"/date
  pin_clock 1700301600  # Sat 10:00 UTC
  ALLOWED_DAYS=(0)
  run calculate_reboot_delay "22:00"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "129600" ]]
}

#fin
