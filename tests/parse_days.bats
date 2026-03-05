#!/usr/bin/env bats
# Tests for parse_day, parse_allowed_days, is_reboot_day_allowed

setup() {
  load test_helper
  _common_setup
  source_script
}

teardown() {
  _common_teardown
}

# ── parse_day: short names ────────────────────────────────────────

@test "parse_day: Sun -> 0" {
  run parse_day "Sun"
  [[ "$output" == "0" ]]
}

@test "parse_day: Mon -> 1" {
  run parse_day "Mon"
  [[ "$output" == "1" ]]
}

@test "parse_day: Tue -> 2" {
  run parse_day "Tue"
  [[ "$output" == "2" ]]
}

@test "parse_day: Wed -> 3" {
  run parse_day "Wed"
  [[ "$output" == "3" ]]
}

@test "parse_day: Thu -> 4" {
  run parse_day "Thu"
  [[ "$output" == "4" ]]
}

@test "parse_day: Fri -> 5" {
  run parse_day "Fri"
  [[ "$output" == "5" ]]
}

@test "parse_day: Sat -> 6" {
  run parse_day "Sat"
  [[ "$output" == "6" ]]
}

# ── parse_day: full names ────────────────────────────────────────

@test "parse_day: Sunday -> 0" {
  run parse_day "Sunday"
  [[ "$output" == "0" ]]
}

@test "parse_day: Monday -> 1" {
  run parse_day "Monday"
  [[ "$output" == "1" ]]
}

@test "parse_day: Tuesday -> 2" {
  run parse_day "Tuesday"
  [[ "$output" == "2" ]]
}

@test "parse_day: Wednesday -> 3" {
  run parse_day "Wednesday"
  [[ "$output" == "3" ]]
}

@test "parse_day: Thursday -> 4" {
  run parse_day "Thursday"
  [[ "$output" == "4" ]]
}

@test "parse_day: Friday -> 5" {
  run parse_day "Friday"
  [[ "$output" == "5" ]]
}

@test "parse_day: Saturday -> 6" {
  run parse_day "Saturday"
  [[ "$output" == "6" ]]
}

# ── parse_day: numeric ───────────────────────────────────────────

@test "parse_day: 0 -> 0" {
  run parse_day "0"
  [[ "$output" == "0" ]]
}

@test "parse_day: 3 -> 3" {
  run parse_day "3"
  [[ "$output" == "3" ]]
}

@test "parse_day: 6 -> 6" {
  run parse_day "6"
  [[ "$output" == "6" ]]
}

# ── parse_day: case insensitivity ────────────────────────────────

@test "parse_day: case insensitive - SUN" {
  run parse_day "SUN"
  [[ "$output" == "0" ]]
}

@test "parse_day: case insensitive - monday" {
  run parse_day "monday"
  [[ "$output" == "1" ]]
}

@test "parse_day: case insensitive - FRIDAY" {
  run parse_day "FRIDAY"
  [[ "$output" == "5" ]]
}

# ── parse_day: invalid input ────────────────────────────────────

@test "parse_day: invalid day name" {
  run parse_day "Funday"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid day"
}

@test "parse_day: invalid number 7" {
  run parse_day "7"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Invalid day"
}

@test "parse_day: empty string" {
  run parse_day ""
  [[ "$status" -ne 0 ]]
}

# ── parse_allowed_days ───────────────────────────────────────────

@test "parse_allowed_days: single day" {
  parse_allowed_days "Mon"
  [[ "${#ALLOWED_DAYS[@]}" -eq 1 ]]
  [[ "${ALLOWED_DAYS[0]}" == "1" ]]
}

@test "parse_allowed_days: multiple days" {
  parse_allowed_days "Mon,Wed,Fri"
  [[ "${#ALLOWED_DAYS[@]}" -eq 3 ]]
  [[ "${ALLOWED_DAYS[0]}" == "1" ]]
  [[ "${ALLOWED_DAYS[1]}" == "3" ]]
  [[ "${ALLOWED_DAYS[2]}" == "5" ]]
}

@test "parse_allowed_days: handles whitespace" {
  parse_allowed_days "Mon , Wed , Fri"
  [[ "${#ALLOWED_DAYS[@]}" -eq 3 ]]
  [[ "${ALLOWED_DAYS[0]}" == "1" ]]
  [[ "${ALLOWED_DAYS[1]}" == "3" ]]
  [[ "${ALLOWED_DAYS[2]}" == "5" ]]
}

@test "parse_allowed_days: numeric days" {
  parse_allowed_days "0,3,6"
  [[ "${#ALLOWED_DAYS[@]}" -eq 3 ]]
  [[ "${ALLOWED_DAYS[0]}" == "0" ]]
  [[ "${ALLOWED_DAYS[1]}" == "3" ]]
  [[ "${ALLOWED_DAYS[2]}" == "6" ]]
}

@test "parse_allowed_days: mixed format" {
  parse_allowed_days "Sun,Monday,5"
  [[ "${#ALLOWED_DAYS[@]}" -eq 3 ]]
  [[ "${ALLOWED_DAYS[0]}" == "0" ]]
  [[ "${ALLOWED_DAYS[1]}" == "1" ]]
  [[ "${ALLOWED_DAYS[2]}" == "5" ]]
}

@test "parse_allowed_days: invalid day in list fails" {
  run parse_allowed_days "Mon,Invalid,Fri"
  [[ "$status" -ne 0 ]]
}

@test "parse_allowed_days: resets ALLOWED_DAYS on each call" {
  parse_allowed_days "Mon,Tue"
  [[ "${#ALLOWED_DAYS[@]}" -eq 2 ]]
  parse_allowed_days "Fri"
  [[ "${#ALLOWED_DAYS[@]}" -eq 1 ]]
  [[ "${ALLOWED_DAYS[0]}" == "5" ]]
}

# ── is_reboot_day_allowed ───────────────────────────────────────

@test "is_reboot_day_allowed: empty array allows all days" {
  ALLOWED_DAYS=()
  run is_reboot_day_allowed
  [[ "$status" -eq 0 ]]
}

@test "is_reboot_day_allowed: matching day returns 0" {
  # Mock date to return Wednesday (3)
  create_mock_date 1700000000 3
  ALLOWED_DAYS=(1 3 5)  # Mon, Wed, Fri
  run is_reboot_day_allowed
  [[ "$status" -eq 0 ]]
}

@test "is_reboot_day_allowed: non-matching day returns 1" {
  # Mock date to return Tuesday (2)
  create_mock_date 1700000000 2
  ALLOWED_DAYS=(1 3 5)  # Mon, Wed, Fri
  run is_reboot_day_allowed
  [[ "$status" -eq 1 ]]
}

@test "is_reboot_day_allowed: Sunday (0) in allowed list" {
  create_mock_date 1700000000 0
  ALLOWED_DAYS=(0 6)  # Sun, Sat
  run is_reboot_day_allowed
  [[ "$status" -eq 0 ]]
}

@test "is_reboot_day_allowed: Saturday (6) not in allowed list" {
  create_mock_date 1700000000 6
  ALLOWED_DAYS=(1 2 3 4 5)  # Mon-Fri
  run is_reboot_day_allowed
  [[ "$status" -eq 1 ]]
}

#fin
