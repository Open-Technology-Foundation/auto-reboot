#!/usr/bin/env bash
# run_tests.sh - Test runner for auto-reboot BATS test suite
set -euo pipefail

declare -r SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
declare -r TESTS_DIR="${SCRIPT_DIR}/tests"

# Verify bats is available
if ! command -v bats >/dev/null 2>&1; then
  echo "Error: bats not found. Install with: sudo apt install bats" >&2
  exit 1
fi

# Color support
if [[ -t 1 ]]; then
  declare -r GREEN=$'\033[0;32m' RED=$'\033[0;31m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r GREEN='' RED='' CYAN='' NC=''
fi

echo "${CYAN}auto-reboot test suite${NC}"
echo "======================"
echo

# Collect test files
declare -a test_files=()
if (($#)); then
  # Run specific files or pass args through to bats
  for arg in "$@"; do
    if [[ -f "$arg" ]]; then
      test_files+=("$arg")
    elif [[ -f "${TESTS_DIR}/${arg}" ]]; then
      test_files+=("${TESTS_DIR}/${arg}")
    elif [[ -f "${TESTS_DIR}/${arg}.bats" ]]; then
      test_files+=("${TESTS_DIR}/${arg}.bats")
    else
      # Pass through as bats argument
      test_files+=("$arg")
    fi
  done
else
  # Run all test files in order
  for f in \
    "${TESTS_DIR}/utility.bats" \
    "${TESTS_DIR}/parse_days.bats" \
    "${TESTS_DIR}/reboot_delay.bats" \
    "${TESTS_DIR}/conditions.bats" \
    "${TESTS_DIR}/schedule.bats" \
    "${TESTS_DIR}/cli.bats"; do
    [[ -f "$f" ]] && test_files+=("$f")
  done
fi

if ((${#test_files[@]} == 0)); then
  echo "${RED}No test files found${NC}" >&2
  exit 1
fi

echo "Running: ${test_files[*]##*/}"
echo

bats "${test_files[@]}"
