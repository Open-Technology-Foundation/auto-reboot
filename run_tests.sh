#!/usr/bin/env bash
# run_tests.sh - Test runner for the auto-reboot BATS test suite
set -euo pipefail
shopt -s inherit_errexit

#shellcheck disable=SC2155 # BCS0103 metadata pattern
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}
declare -r TESTS_DIR="$SCRIPT_DIR"/tests

command -v bats &>/dev/null || { >&2 echo 'bats not found. Install with: sudo apt install bats'; exit 18; }

# Suites in dependency order: low-level helpers first
declare -ar SUITES=(utility parse_days reboot_delay conditions schedule cli)
declare -a TEST_FILES=()
declare -- arg suite

if (($#)); then
  # Accept a path, a file name under tests/, a suite name, or a raw bats argument
  for arg in "$@"; do
    if [[ -f $arg ]]; then
      TEST_FILES+=("$arg")
    elif [[ -f $TESTS_DIR/$arg ]]; then
      TEST_FILES+=("$TESTS_DIR/$arg")
    elif [[ -f $TESTS_DIR/$arg.bats ]]; then
      TEST_FILES+=("$TESTS_DIR/$arg.bats")
    else
      TEST_FILES+=("$arg")
    fi
  done
else
  for suite in "${SUITES[@]}"; do
    [[ -f $TESTS_DIR/$suite.bats ]] && TEST_FILES+=("$TESTS_DIR/$suite.bats") ||:
  done
fi

((${#TEST_FILES[@]})) || { >&2 echo 'No test files found'; exit 3; }

>&2 echo "auto-reboot test suite: ${TEST_FILES[*]##*/}"
bats "${TEST_FILES[@]}"
#fin
