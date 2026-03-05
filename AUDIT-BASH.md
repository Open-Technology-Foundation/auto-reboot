# Bash Audit Report: auto-reboot

**Date**: 2026-03-05
**Auditor**: Leet (Bash 5.2+ Raw Code Audit)
**Script**: `auto-reboot` v1.1.1
**Lines**: 586 (including `#fin`)
**Functions**: 15
**BCS Tier**: Complete (symlink → `/usr/local/share/yatti/bash-coding-standard/data/BASH-CODING-STANDARD.md`)

---

## Executive Summary

**Overall Health Score: 7.5/10**

The script is well-structured with strong BCS adherence, proper `set -euo pipefail`, `shopt -s inherit_errexit`, correct variable typing, and clean function organization. However, a **critical argument-parsing bug** causes two options to silently consume the next argument. Three SC2015 violations and several minor BCS gaps round out the findings.

| Severity | Count |
|----------|-------|
| Critical | 1     |
| High     | 1     |
| Medium   | 6     |
| Low      | 3     |

### Top Critical Issue
Double-shift bug in `--reboot-time` and `--allowed-days` silently eats the following command-line argument.

### Quick Wins
- Remove the extra `shift` on lines 491 and 503
- Replace `&& ... ||:` with explicit `if/then`

### Long-term Recommendations
- Define BCS exit code constants
- Add `SCRIPT_DIR` metadata variable

---

## ShellCheck Results

```
shellcheck -x auto-reboot
```

**3 findings (all SC2015 — info level):**

| Line | Code | Description |
|------|------|-------------|
| 94   | SC2015 | `A && B \|\| C` is not if-then-else |
| 351  | SC2015 | `A && B \|\| C` is not if-then-else |
| 352  | SC2015 | `A && B \|\| C` is not if-then-else |

**Suppressed directives:**

| Line | Code | Justification | Verdict |
|------|------|---------------|---------|
| 8    | SC2155 | "realpath return checked by set -e" | Scope too broad (file-level) — should be line-local |

---

## BCS Compliance

`bcscheck` completed without violations. Manual review follows.

### BCS0101 — Script Structure ✓ (with gaps)

| Element | Status | Location |
|---------|--------|----------|
| Shebang `#!/usr/bin/env bash` | ✓ | Line 1 |
| Description comment | ✓ | Line 2 |
| `set -euo pipefail` | ✓ | Line 3 |
| `shopt -s inherit_errexit` | ✓ | Line 4 |
| `VERSION` (declare -r) | ✓ | Line 7 |
| `SCRIPT_PATH` (declare -r) | ✓ | Line 9 |
| `SCRIPT_NAME` (declare -r) | ✓ | Line 10 |
| `SCRIPT_DIR` (declare -r) | ✗ Missing | — |
| Global declarations | ✓ | Lines 12–22 |
| Color definitions | ✓ | Lines 25–29 |
| Utility functions | ✓ | Lines 32–45 |
| Business logic functions | ✓ | Lines 48–450 |
| `main()` function | ✓ | Line 452 |
| `main "$@"` invocation | ✓ | Line 585 |
| `#fin` end marker | ✓ | Line 586 |

### BCS Forbidden Patterns — All Clear

| Pattern | Found |
|---------|-------|
| Backticks | ✗ None |
| `(( i++ ))` / `(( ++i ))` | ✗ None |
| `function` keyword | ✗ None |
| `[ ]` test brackets | ✗ None |
| `eval` | ✗ None |
| `expr` | ✗ None |
| Tab indentation | ✗ None |

---

## Findings

### CRITICAL-01: Double-Shift Bug in Argument Parsing

**Severity**: Critical
**Location**: `auto-reboot:491` and `auto-reboot:503`
**BCS Code**: BCS0601

The `--reboot-time` and `--allowed-days` cases each contain an extra `shift` inside the case block. The main `while` loop already performs `shift` at line 535 after `esac`. This causes the next argument to be silently consumed.

**Affected options:**

`--reboot-time` (line 484–497):
```bash
-r|--reboot-time)
  noarg "$@"; shift        # shift 1: flag → value
  ...
      MACHINE_REBOOT_TIME=$1
      shift                # shift 2: value → next arg  ← BUG
  ...
  fi ;;
# Line 535: shift          # shift 3: eats next argument!
```

`--allowed-days` (line 498–503):
```bash
-a|--allowed-days)
  noarg "$@"; shift        # shift 1: flag → value
  ...
  shift ;;                 # shift 2: value → next arg  ← BUG
# Line 535: shift          # shift 3: eats next argument!
```

**Compare with correct pattern** (`--max-uptime-days`, line 477–483):
```bash
-m|--max-uptime-days)
  noarg "$@"; shift        # shift 1: flag → value
  ...
  MACHINE_UPTIME_MAXDAYS=$1
  # No inner shift         # ← Correct
  fi ;;
# Line 535: shift          # shift 2: value → next arg ✓
```

**Impact**: Running `auto-reboot --reboot-time 04:00 --allowed-days Sun -N` will silently drop `--allowed-days` (consumed by the extra shift in `--reboot-time`). Then `Sun` becomes an unknown option, causing an error.

**Fix**: Remove the extra `shift` on lines 491 and 503:

```bash
# Line 491: Remove this shift
            MACHINE_REBOOT_TIME=$1
-           shift

# Line 503: Remove this shift
        fi
-       shift ;;
+       ;;
```

---

### HIGH-01: SC2015 — `A && B || C` Anti-Pattern (3 instances)

**Severity**: High
**Location**: `auto-reboot:94`, `auto-reboot:351`, `auto-reboot:352`
**BCS Code**: BCS0801

BCS requires explicit `if/then` instead of `&& ... ||` chains because `C` can run even when `A` is true (if `B` fails).

**Line 94** — `is_reboot_day_allowed()`:
```bash
# Current:
(( current_day == allowed_day )) && return 0 ||:

# Fix:
if (( current_day == allowed_day )); then return 0; fi
```

**Lines 351–352** — `install_auto_reboot()`:
```bash
# Current:
[[ -L $localbin ]] && rm "$localbin" ||:
[[ -f $localbin ]] && rm "$localbin" ||:

# Fix:
if [[ -L $localbin ]]; then rm "$localbin"; fi
if [[ -f $localbin ]]; then rm "$localbin"; fi
```

**Impact**: If `rm` fails on line 351/352, the `||:` silently swallows the error. With `set -e`, this could mask a permissions issue.

---

### MEDIUM-01: Missing `SCRIPT_DIR` Metadata

**Severity**: Medium
**Location**: `auto-reboot:7–10`
**BCS Code**: BCS0101

BCS requires `SCRIPT_DIR` among script metadata variables. Not all scripts need it, but `install_auto_reboot()` creates a symlink to `$SCRIPT_PATH`, making the directory relevant.

**Fix**: Add after line 10:
```bash
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}
```

---

### MEDIUM-02: Raw Exit Codes Instead of Named Constants

**Severity**: Medium
**Location**: `auto-reboot:43`, `auto-reboot:45`, `auto-reboot:459`
**BCS Code**: BCS0602

The script uses raw numeric exit codes (1, 22) without defining BCS canonical constants.

| Line | Code | Should Be |
|------|------|-----------|
| 43   | `exit "${1:-0}"` | Generic (OK for die) |
| 45   | `die 22` | `ERR_INVAL` |
| 459  | `die 1` | `ERR_GENERAL` |

**Fix**: Define used constants after metadata:
```bash
declare -ri ERR_GENERAL=1
declare -ri ERR_INVAL=22
```

---

### MEDIUM-03: File-Scoped SC2155 Suppression

**Severity**: Medium
**Location**: `auto-reboot:8`
**BCS Code**: BCS1302

The `#shellcheck disable=SC2155` on line 8 is at file scope, suppressing the warning for the entire script. It should be scoped to line 9 only.

Currently no other SC2155 violations exist (all other declarations use separate `local`/`declare` and assignment), but the broad scope could mask future regressions.

**Fix**: Move the directive directly above the affected line and below the description comment:
```bash
# Intelligent system reboot scheduler with flexible timing and day-of-week restrictions
set -euo pipefail
shopt -s inherit_errexit

# Script metadata
declare -r VERSION=1.1.1
#shellcheck disable=SC2155 # realpath return checked by set -e
declare -r SCRIPT_PATH=$(realpath -- "$0")
```

Actually, the current placement (line 8) is already directly above line 9. ShellCheck applies inline directives to the next command only when placed immediately above it. **Verdict**: Current placement is correct; this is a non-issue on review. The directive applies only to line 9.

**Status**: Withdrawn — no change needed.

---

### MEDIUM-04: Line Length Violations (5 lines > 100 chars)

**Severity**: Medium
**BCS Code**: BCS1301

| Line | Chars | Content |
|------|-------|---------|
| 203  | 110   | `logger` scheduling message |
| 210  | 111   | `logger` success message |
| 231  | 113   | `systemctl list-timers` pipeline |
| 298  | 103   | `systemctl list-timers` pipeline |
| 555  | 102   | uptime reason echo |

**Fix**: Break with `\` continuation or use intermediate variables:
```bash
# Line 203:
logger -t "$SCRIPT_NAME" \
  "Scheduling system reboot in ${delay}s for user $XUSER (uptime: ${UPTIME_DAYS}d)"
```

---

### MEDIUM-05: Install Permissions (chmod 770)

**Severity**: Medium
**Location**: `auto-reboot:356–358`

The installed script and symlink use `chmod 770`, which denies world-read/execute. For `/usr/local/bin` executables this is unusual — typically `755` is expected so all users can invoke the script.

The `chown "$XUSER":sudo` restricts ownership to the `sudo` group, which is intentional for privilege control. However, the original script (`SCRIPT_PATH`) also gets `770`, meaning non-sudo-group users cannot read it.

**Recommendation**: Consider `750` (group-readable/executable but not writable) or document the 770 choice.

---

### MEDIUM-06: `readonly --` Convention

**Severity**: Medium
**Location**: `auto-reboot:538–540`
**BCS Code**: BCS0203

BCS recommends `readonly --` with double-dash for safety. Current code:
```bash
readonly MACHINE_REBOOT_TIME MACHINE_UPTIME_MAXDAYS
readonly DRY_RUN FORCE_REBOOT
readonly -a ALLOWED_DAYS
```

**Fix**:
```bash
readonly -- MACHINE_REBOOT_TIME MACHINE_UPTIME_MAXDAYS
readonly -- DRY_RUN FORCE_REBOOT
readonly -a ALLOWED_DAYS
```

---

### LOW-01: Missing Optional Utility Functions

**Severity**: Low
**Location**: Global scope
**BCS Code**: BCS0901

BCS recommends a standard set of utility functions. The script defines `_msg`, `info`, `error`, `die`, and `noarg`. Missing (not required):
- `warn()` — warning messages
- `vecho()` — verbose output
- `debug()` — debug messages
- `yn()` — yes/no prompts

The script uses inline `read -p` for confirmation (line 314) instead of `yn()`. This is acceptable for a single use case.

---

### LOW-02: `info()` Writes to stderr

**Severity**: Low
**Location**: `auto-reboot:42`

Both `error()` and `info()` write to stderr. While this is valid (keeps stdout clean for data), it differs from common convention where info goes to stdout. The approach is consistent and intentional.

**Impact**: None — informational only.

---

### LOW-03: Undocumented `exit` vs `return` Pattern

**Severity**: Low
**Location**: `auto-reboot:506–519`

Some case branches use `exit $?` while others use `return`. The pattern is intentional:
- `exit $?` for standalone operations (`--install`, `--list`, `--delete`, `--delete-all`, `--version`)
- `return` for argument parsing errors

This is correct but could benefit from a comment explaining the convention.

---

## Security Analysis

| Check | Status | Notes |
|-------|--------|-------|
| Command injection | ✓ Safe | No `eval`, no unvalidated input in commands |
| PATH locking | ✓ Good | `declare -rx PATH=...` on line 12 |
| SUID/SGID | ✓ None | No setuid/setgid |
| Input validation | ✓ Good | Time, day, and numeric inputs validated |
| Privilege escalation | ✓ Controlled | Sudo elevation with group check |
| Unsafe rm | ▲ See HIGH-01 | `rm` in `||:` chain masks failure |
| Symlink safety | ✓ Reasonable | `realpath` used for SCRIPT_PATH |
| Unquoted variables | ✓ Clean | All variables properly quoted |

---

## File Statistics

| Metric | Value |
|--------|-------|
| Total lines | 586 |
| Functions | 15 |
| Scripts audited | 1 (auto-reboot) + 1 (bash_completion) |
| ShellCheck findings | 3 (SC2015 info) |
| BCS forbidden patterns | 0 |
| Security issues | 0 critical |

---

## Tool Output Summary

### ShellCheck
```
3 × SC2015 (info) — A && B || C pattern
1 × SC2155 suppression (documented, correctly scoped)
```

### bcscheck
```
Completed without violations.
```

---

## Actionable Recommendations

### Immediate (Critical/High)

1. **Remove extra `shift`** on line 491 (inside `--reboot-time`) and line 503 (inside `--allowed-days`)
2. **Replace `&& ... ||:`** with explicit `if/then` on lines 94, 351, 352

### Short-term (Medium)

3. Add `SCRIPT_DIR` metadata variable
4. Define `ERR_GENERAL=1` and `ERR_INVAL=22` constants
5. Break lines > 100 characters with `\` continuation
6. Add `--` to `readonly` declarations
7. Review `chmod 770` for `/usr/local/bin` installation

### Optional (Low)

8. Add `warn()` utility function if warning messages are needed in future
9. Document `exit` vs `return` convention in argument parsing

#fin
