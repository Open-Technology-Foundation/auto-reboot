#!/usr/bin/env bats
# Tests for the Makefile install target's update-notifier-common check.
# /var/run/reboot-required is written by notify-reboot-required from that
# package; without it the flag never appears and only uptime triggers.

setup() {
  load test_helper
  _common_setup
  create_mock_apt_get
  export PATH="$MOCK_BIN:$ORIG_PATH"
  NOTIFIER="$TEST_TEMP_DIR"/notify-reboot-required
}

teardown() {
  _common_teardown
}

# make install into the temp prefix; REBOOT_NOTIFIER points at a controllable path
_make() {
  MOCK_LOG="$MOCK_LOG" make -s -C "$PROJECT_ROOT" "$1" \
    PREFIX="$PREFIX" COMPDIR="$PREFIX"/completion SYSCONFDIR="$PREFIX"/etc \
    REBOOT_NOTIFIER="$NOTIFIER" "${@:2}"
}
_make_install() { _make install "$@"; }

@test "install: installs update-notifier-common when notifier helper is absent" {
  run _make_install
  [[ $status -eq 0 ]]
  assert_mock_called 'apt-get install -y --no-install-recommends update-notifier-common'
}

@test "install: skips apt-get when notifier helper is present" {
  touch "$NOTIFIER"
  run _make_install
  [[ $status -eq 0 ]]
  assert_mock_not_called 'apt-get'
}

@test "install: never runs apt-get under DESTDIR (staged/packaging install)" {
  run _make_install DESTDIR="$TEST_TEMP_DIR"/stage
  [[ $status -eq 0 ]]
  assert_mock_not_called 'apt-get'
}

@test "install: ships the default config file" {
  run _make_install
  [[ $status -eq 0 ]]
  cmp -s "$PROJECT_ROOT"/auto-reboot.conf "$PREFIX"/etc/auto-reboot.conf
}

@test "install: never overwrites an existing config file" {
  mkdir -p "$PREFIX"/etc
  echo 'MACHINE_REBOOT_TIME=04:20' > "$PREFIX"/etc/auto-reboot.conf
  run _make_install
  [[ $status -eq 0 ]]
  [[ $(< "$PREFIX"/etc/auto-reboot.conf) == 'MACHINE_REBOOT_TIME=04:20' ]]
}

@test "uninstall: removes an unmodified config file" {
  _make_install
  run _make uninstall
  [[ $status -eq 0 ]]
  [[ ! -e "$PREFIX"/etc/auto-reboot.conf ]]
  [[ ! -e "$PREFIX"/bin/auto-reboot ]]
}

@test "uninstall: keeps a modified config file" {
  _make_install
  echo 'MACHINE_REBOOT_TIME=04:20' >> "$PREFIX"/etc/auto-reboot.conf
  run _make uninstall
  [[ $status -eq 0 ]]
  [[ -e "$PREFIX"/etc/auto-reboot.conf ]]
  [[ ! -e "$PREFIX"/bin/auto-reboot ]]
}

@test "install: fails when apt-get cannot install update-notifier-common" {
  create_mock_apt_get 100
  run _make_install
  [[ $status -ne 0 ]]
}
