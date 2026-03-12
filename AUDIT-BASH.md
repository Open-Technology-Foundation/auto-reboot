# Bash Audit Report: auto-reboot

**Date**: 2026-03-12
**Auditor**: Leet (Bash 5.2+ Raw Code Audit)
**Script**: `auto-reboot` v1.2.0
**Lines**: 587 (including `#fin`)
**Functions**: 15
**Supporting Files**: `run_tests.sh` (63 lines), `.bash_completion` (58 lines), `tests/test_helper.bash` (326 lines), 6 BATS test suites (1084 lines)
**Total Project Lines**: 2055
**BCS Tier**: Complete

---

## Executive Summary

**Overall Health Score: 8/10**

The script is well-architected with strong BCS fundamentals: correct `set -euo pipefail` + `shopt -s inherit_errexit`, proper typed declarations, clean function design, comprehensive quoting discipline, locked PATH, and a well-structured test suite with 127 passing tests. The critical double-shift bug from the previous audit (2026-03-05) has been resolved.

Remaining issues are concentrated in six BCS violations (function ordering, missing verbosity flags, wrong message function, verbose redirection syntax, unquoted file test variables, inconsistent indentation), one ShellCheck SC2015, and minor issues in supporting files.

| Severity | Count |
|----------|-------|
| Critical | 0     |
| High     | 2     |
| Medium   | 6     |
| Low      | 4     |

### Previous Audit Resolutions

| Previous Finding | Status |
|------------------|--------|
| CRITICAL-01: Double-shift bug in `--reboot-time`/`--allowed-days` | **Fixed** |
| HIGH-01: SC2015 at lines 94, 351, 352 (3 instances) | **Partially fixed** (2 of 3 resolved, 1 remains at line 100) |

### Quick Wins

- Fix 4x `>/dev/null 2>&1` to `&>/dev/null` (BCS0711)
- Fix 2x unquoted variables in file tests (BCS0901)
- Fix 1x indentation inconsistency (BCS1201)
- Change `info` to `error` in `install_auto_reboot()` failure path (BCS0703)

### Long-term Recommendations

- Reorder functions to BCS0107 bottom-up layering
- Add `VERBOSE`/`DEBUG` message control flags (BCS0701)
- Add `--` end-of-options separator in parse loop (BCS0801)

---

## ShellCheck Results

```
shellcheck -x auto-reboot
```

**1 finding (SC2015 — info level):**

| Line | Code   | Description |
|------|--------|-------------|
| 100  | SC2015 | `A && B \|\| C` is not if-then-else |

**Suppressed directives:**

| Line | Code   | Justification | Verdict |
|------|--------|---------------|---------|
| 10   | SC2155 | "realpath return checked by set -e" | Valid — correctly scoped to line 11 |

### ShellCheck: Supporting Files

**`run_tests.sh`** — 2 findings:

| Line | Code   | Description |
|------|--------|-------------|
| 5    | SC2155 | Declare and assign separately (`SCRIPT_DIR`) |
| 18   | SC2034 | `GREEN` appears unused |

**`.bash_completion`** — 9 findings:

| Line | Code   | Description |
|------|--------|-------------|
| 1    | SC2148 | Missing shebang/shell directive (false positive — sourced file) |
| 14,19,29,31,43,52 | SC2207 | Prefer `mapfile` to split `compgen` output (6 instances) |
| 42   | SC2155 | Declare and assign separately (`timer_ids`) |
| 42   | SC2001 | Use `${variable//search/replace}` instead of `sed` |

---

## BCS Compliance

**bcscheck result: 76% compliance (NEEDS_WORK)**

6 rules violated (11 instances), 3 suggestions.

### BCS0101 — Script Structure

| Element | Status | Location |
|---------|--------|----------|
| Shebang `#!/usr/bin/env bash` | ✓ | Line 1 |
| Description comment | ✓ | Lines 2-4 |
| `set -euo pipefail` | ✓ | Line 5 |
| `shopt -s inherit_errexit` | ✓ | Line 6 |
| `VERSION` (declare -r) | ✓ | Line 9 |
| `SCRIPT_PATH` (declare -r) | ✓ | Line 11 |
| `SCRIPT_NAME` (declare -r) | ✓ | Line 12 |
| `SCRIPT_DIR` (declare -r) | ✗ Missing | Not required for this script |
| Global declarations | ✓ | Lines 14-26 |
| Color definitions | ✓ | Lines 29-33 |
| Utility functions | ✓ | Lines 37-51 |
| Business logic functions | ✓ | Lines 54-452 |
| `main()` function | ✓ | Line 454 |
| `main "$@"` invocation | ✓ | Line 586 |
| `#fin` end marker | ✓ | Line 587 |

### BCS Forbidden Patterns — All Clear

| Pattern | Found |
|---------|-------|
| Backticks | None |
| `(( i++ ))` / `(( ++i ))` | None |
| `function` keyword | None |
| `[ ]` test brackets | None |
| `eval` | None |
| `expr` | None |
| Tab indentation | None |

---

## Findings

### HIGH-01: BCS0107 — Function Organization (Bottom-Up Order)

**Severity**: High
**Location**: `auto-reboot:361-452`

Two functions violate BCS0107 bottom-up ordering:

1. **`usage()`** (Layer 2 — Documentation) is defined after all business logic functions (Layer 5), including `schedule_reboot()`, `list_schedules()`, `delete_schedule()`, and `install_auto_reboot()`.

2. **`systemd_run_required()`** (Layer 4 — Validation) is defined after `schedule_reboot()` (Layer 5) which calls it.

BCS0107 mandates: Messaging -> Documentation -> Helpers -> Validation -> Business Logic -> Orchestration -> `main()`.

**Impact**: Reduces readability and maintainability. In Bash, function ordering doesn't affect execution (functions are defined before `main()` runs), but bottom-up ordering ensures readers encounter dependencies before dependents.

**Fix**: Move `usage()` to immediately after `die()`/`noarg()`. Move `systemd_run_required()` to after `is_reboot_day_allowed()` and before `check_reboot_conditions()`.

---

### HIGH-02: SC2015 — `A && B || C` Anti-Pattern

**Severity**: High
**Location**: `auto-reboot:100`
**BCS Code**: BCS0505

```bash
(( current_day == allowed_day )) && return 0 ||:
```

ShellCheck flags this as not being a true if-then-else. While `return 0` cannot fail (making the `||:` technically unreachable in this case), the pattern is prohibited by BCS as it creates a maintenance risk — future changes to the `B` position could silently fall through.

**Fix**:
```bash
if (( current_day == allowed_day )); then return 0; fi
```

---

### MEDIUM-01: BCS0701 — Missing Message Control Flags

**Severity**: Medium
**Location**: Global declarations block (line 22)

BCS0701 requires `VERBOSE` and `DEBUG` flags:
```bash
declare -i VERBOSE=1 DEBUG=0
```

Currently `info()` outputs unconditionally. BCS0703 requires `info()` to respect the `VERBOSE` flag.

**Fix**: Add to global declarations and guard `info()`:
```bash
declare -i VERBOSE=1 DEBUG=0
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
```

**Impact**: Low practical impact — the script currently has no quiet/verbose mode. However, this would be needed if `-q`/`--quiet` support is ever added.

---

### MEDIUM-02: BCS0703 — Wrong Message Function for Error Condition

**Severity**: Medium
**Location**: `auto-reboot:330-332`

```bash
sudo apt-get update --quiet --assume-yes || {
  info 'apt-get update failed'   # <-- should be error()
  return 1
}
```

A failure path must use `error()`, not `info()`. Using `info` here would suppress the message if `VERBOSE` gating is ever implemented.

**Fix**:
```bash
sudo apt-get update --quiet --assume-yes || {
  error 'apt-get update failed'
  return 1
}
```

---

### MEDIUM-03: BCS0711 — Verbose Combined Redirection (4 instances)

**Severity**: Medium
**Location**: `auto-reboot:197`, `auto-reboot:328`, `auto-reboot:339`, `auto-reboot:439`

BCS0711 requires `&>/dev/null` instead of `>/dev/null 2>&1`:

| Line | Current | Required |
|------|---------|----------|
| 197  | `systemctl is-system-running >/dev/null 2>&1` | `&>/dev/null` |
| 328  | `command -v systemd-run >/dev/null 2>&1` | `&>/dev/null` |
| 339  | `command -v systemd-run >/dev/null 2>&1` | `&>/dev/null` |
| 439  | `command -v systemd-run >/dev/null 2>&1` | `&>/dev/null` |

Note: `2>/dev/null` (stderr-only suppression) used elsewhere is correct and unaffected.

---

### MEDIUM-04: BCS0901 — Unquoted Variables in File Tests (2 instances)

**Severity**: Medium
**Location**: `auto-reboot:347-348`

```bash
[[ ! -L $localbin ]] || rm "$localbin"   # unquoted in test
[[ ! -f $localbin ]] || rm "$localbin"   # unquoted in test
```

BCS0901 states: "Always quote variables in file tests."

**Fix**:
```bash
[[ ! -L "$localbin" ]] || rm "$localbin"
[[ ! -f "$localbin" ]] || rm "$localbin"
```

---

### MEDIUM-05: BCS1201 — Inconsistent Indentation

**Severity**: Medium
**Location**: `auto-reboot:199-201`

```bash
  if (( sys_rc > 1 )); then
      error 'systemd is not running...'    # 6-space indent (4 relative)
      return 1                             # 6-space indent
  fi
```

All other `if` blocks use 2-space relative indentation. BCS1201 mandates 2 spaces throughout.

**Fix**:
```bash
  if (( sys_rc > 1 )); then
    error 'systemd is not running. This script requires systemd for reliable scheduling.'
    return 1
  fi
```

---

### MEDIUM-06: `readonly --` Convention

**Severity**: Medium
**Location**: `auto-reboot:541-543`
**BCS Code**: BCS0205

BCS recommends `readonly --` with double-dash for safety:

```bash
# Current:
readonly MACHINE_REBOOT_TIME MACHINE_UPTIME_MAXDAYS
readonly DRY_RUN FORCE_REBOOT

# Fix:
readonly -- MACHINE_REBOOT_TIME MACHINE_UPTIME_MAXDAYS
readonly -- DRY_RUN FORCE_REBOOT
```

---

### LOW-01: `run_tests.sh` — Unused Variable

**Severity**: Low
**Location**: `run_tests.sh:16-18`

`GREEN` is declared in the color block but never referenced. `CYAN` (line 21) and `RED` (line 55) are used; `GREEN` is dead code.

**Fix**: Remove `GREEN` from the declaration:
```bash
declare -r RED=$'\033[0;31m' CYAN=$'\033[0;36m' NC=$'\033[0m'
```

---

### LOW-02: `.bash_completion` — ShellCheck Compliance

**Severity**: Low
**Location**: `.bash_completion:1,14,19,29,31,42,43,52`

9 ShellCheck findings including missing shell directive, `COMPREPLY` assignment pattern, and declare+assign. The SC2207 warnings about `COMPREPLY=( $(compgen ...) )` are the standard bash-completion pattern; suppress with a file-level directive:

```bash
# shellcheck shell=bash
# shellcheck disable=SC2207
```

The SC2001 on line 42 (`sed 's/auto-reboot-//'`) can use parameter expansion:
```bash
local timer_ids="${timers//auto-reboot-/}"
```

---

### LOW-03: BCS0801 — Missing `--` End-of-Options

**Severity**: Low
**Location**: `auto-reboot:467-538`

The argument parsing loop does not handle `--` to terminate option processing:

```bash
--) shift; break ;;
```

Low risk since the script accepts no positional file-path arguments.

---

### LOW-04: BCS Suggestions (3 from bcscheck)

**Severity**: Low

1. **BCS0706 — Incomplete Color Set**: Only `RED`, `CYAN`, `NC` defined. `GREEN` and `YELLOW` are absent because no `warn()`/`success()` functions exist. Current set is defensible given the script's needs.

2. **BCS0606 — Verbose flag-setting conditionals**: `check_reboot_conditions()` uses 3 `if` blocks to set `REBOOT_NEEDED=1`. BCS prefers inverted `||` form:
   ```bash
   [[ ! -f /var/run/reboot-required ]] || REBOOT_NEEDED=1
   ((UPTIME_DAYS < MACHINE_UPTIME_MAXDAYS)) || REBOOT_NEEDED=1
   ((!FORCE_REBOOT)) || REBOOT_NEEDED=1
   ```

3. **BCS0801 — `--` end-of-options**: See LOW-03 above.

---

## Security Analysis

| Check | Status | Notes |
|-------|--------|-------|
| Command injection | ✓ Safe | No `eval`, no unvalidated input in commands |
| PATH locking | ✓ Good | `declare -rx PATH=...` on line 15 |
| SUID/SGID | ✓ None | No setuid/setgid permissions |
| Input validation | ✓ Good | Time (HH:MM range), day (enum), uptime (positive int) all validated |
| Privilege escalation | ✓ Controlled | Sudo elevation gated by group membership check |
| Unsafe rm | ✓ Safe | `rm` only on validated `$localbin` path in `install_auto_reboot()` |
| Symlink safety | ✓ Good | `realpath` resolves `$0` before use |
| Unquoted variables | ▲ Minor | 2 unquoted in `[[ ]]` file tests (safe in `[[ ]]` but violates BCS) |
| Audit trail | ✓ Good | All schedule/delete ops logged via `logger -t` with user identity |
| Non-interactive safety | ✓ Good | `delete_all_schedules` checks `[[ -t 0 ]]` before prompting |

---

## Test Suite Analysis

**Results**: 127/127 tests passing

| Suite | Tests | Coverage |
|-------|-------|----------|
| `utility.bats` | 21 | `_msg`, `error`, `info`, `die`, `noarg`, `usage`, `systemd_run_required` |
| `parse_days.bats` | 35 | `parse_day` (all formats), `parse_allowed_days`, `is_reboot_day_allowed` |
| `reboot_delay.bats` | 10 | `calculate_reboot_delay` with/without day restrictions, wrap-around |
| `conditions.bats` | 8 | `check_reboot_conditions` with uptime, force, combined |
| `schedule.bats` | 18 | `schedule_reboot`, `list_schedules`, `delete_schedule`, `delete_all_schedules` |
| `cli.bats` | 35 | Argument parsing, bundled options, error handling |

**Test Infrastructure Quality**: High

- `source_script()` / `run_script()` properly sanitize test-incompatible constructs
- Comprehensive mock infrastructure (date, systemctl, systemd-run, logger, uptime, sudo, id)
- Mock date handles time arithmetic with proper epoch calculations
- Custom assertions supplement bats-assert library
- Tests properly isolated with temp dirs and teardown cleanup

**Coverage Gaps** (minor):

- `install_auto_reboot()` not tested (requires root/apt interaction)
- `delete_all_schedules()` with actual timers + confirmation flow not tested (requires interactive terminal)
- `MACHINE_REBOOT_TIME` / `MACHINE_UPTIME_MAXDAYS` environment variable override paths not explicitly tested

---

## File Statistics

| Metric | Value |
|--------|-------|
| Total project lines | 2055 |
| Main script lines | 587 |
| Test lines | 1410 (68.6% of project) |
| Functions | 15 |
| Test cases | 127 |
| Scripts audited | 3 (`auto-reboot`, `run_tests.sh`, `.bash_completion`) |
| ShellCheck findings | 1 (auto-reboot) + 2 (run_tests.sh) + 9 (.bash_completion) |
| BCS violations | 6 rules (11 instances) |
| BCS compliance | 76% |
| Security issues | 0 critical |
| Test pass rate | 100% |

---

## Tool Output Summary

### ShellCheck

```
auto-reboot:     1 finding  (SC2015 info)
run_tests.sh:    2 findings (SC2155 warning, SC2034 warning)
.bash_completion: 9 findings (SC2148 error, 6x SC2207 warning, SC2155 warning, SC2001 style)
```

### bcscheck

```
Compliance: 76% — NEEDS_WORK
Violations: 6 rules (BCS0107, BCS0701, BCS0703, BCS0711, BCS0901, BCS1201)
Suggestions: 3 (BCS0706, BCS0606, BCS0801)
```

### Test Suite

```
127/127 passing (100%)
```

---

## Actionable Recommendations

### Immediate (High)

1. **Reorder functions** to BCS0107 bottom-up layering: move `usage()` after messaging functions, move `systemd_run_required()` before business logic
2. **Replace `&&...||:`** with `if/then` on line 100

### Short-term (Medium)

3. **Replace `>/dev/null 2>&1`** with `&>/dev/null` (4 instances)
4. **Quote variables** in file tests: lines 347-348
5. **Fix indentation** in `schedule_reboot()`: lines 199-201
6. **Change `info` to `error`** in `install_auto_reboot()` failure path: line 331
7. **Add `readonly --`** double-dash to freeze declarations: lines 541-542
8. **Add `VERBOSE`/`DEBUG` flags** if quiet mode is desired

### Optional (Low)

9. Fix `run_tests.sh` unused `GREEN` variable
10. Add ShellCheck directives to `.bash_completion`
11. Add `--` end-of-options case in parse loop
12. Consider BCS0606 inverted `||` form for flag-setting conditionals

#fin
