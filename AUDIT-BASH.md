# Bash Audit Report: auto-reboot

**Date**: 2026-09-07
**Auditor**: audit-bash skill (Bash 5.2+ Raw Code Audit) + bcscheck skill; ShellCheck v0.11.0; BATS 1.11.0
**Script**: `auto-reboot` v1.2.0 (commit 3c468e3)
**Lines**: 597 (including `#fin`), 18 functions
**Supporting files**: `run_tests.sh` (62), `tests/test_helper.bash` (327), 6 BATS suites (1120), `Makefile` (50), `auto-reboot.bash_completion` (55), `auto-reboot.1` (274)
**Total project lines**: 2485
**Standard**: `/usr/local/share/yatti/BCS/data/BASH-CODING-STANDARD.md` (122 rules)
**Host**: Ubuntu 24.04.4, Bash 5.2.21, systemd 255

---

## Remediation Status (2026-09-07, same day)

All findings below were addressed in the working tree after this audit was written; the audit body that follows describes the code **as it was at commit 3c468e3**. Version bumped to **1.3.0**.

### Verification after remediation

| Check | Before | After |
|-------|--------|-------|
| `./run_tests.sh` | 133/133 | **174/174** (41 new tests, each written to fail first) |
| `shellcheck -x` script / runner / completion / helper | 0 / 2 / 0 / 2 | **0 / 0 / 0 / 0** |
| bcscheck skill `auto-reboot` | FAIL 10 ERROR / 42 WARN | **PASS 0 / 0** (two WARNs resolved after the re-audit) |
| bcscheck skill `run_tests.sh` | FAIL 4 / 20 | **PASS 0 / 0** |
| bcscheck skill `tests/test_helper.bash` | FAIL 10 / 61 | **PASS 0 / 0** (nine findings from the re-audit fixed) |
| Real-script smoke (non-root): `-V`, `-h`, dry run, `-f -r 08:09`, `--list`, `-D`, bad env, stray arg, bad option | 2 crashes, 1 silent delete | all correct, exit codes 0 / 22 / 2 as documented |

### Finding status

| ID | Finding | Status | How |
|----|---------|--------|-----|
| HIGH-01 | Leading-zero `HH:MM` crash | ✓ Fixed | `10#` in `validate_time`/`validate_days`/`calculate_reboot_delay`; 7 regression tests |
| HIGH-02 | `-D` deletes without confirmation | ✓ Fixed (option A) | dry run previews; `-N -D` prompts via `yn()`, refuses off-tty; help/README/manpage/insight aligned |
| MEDIUM-01 | `systemd-container` misattribution | ✓ Fixed | apt branch removed; `die 18`; five documents corrected |
| MEDIUM-02 | Env overrides unvalidated / dropped by sudo | ✓ Fixed | shared validators run before anything else; `elevate_to_root` forwards `-r`/`-m`; every `date -d` checked (`epoch_at`) |
| MEDIUM-03 | Exit codes vs manpage | ✓ Fixed | `die 22/13/18/2`; manpage, README, `usage` tables agree |
| MEDIUM-04 | Duplicate timers per cron run | ✓ Fixed | `existing_timers` guard in `schedule_reboot`; `$EPOCHSECONDS` unit names |
| MEDIUM-05 | PATH locked after `realpath` | ✓ Fixed | lock is the first statement after `shopt` |
| MEDIUM-06 | Test gaps and fragile harness | ✓ Fixed | `REBOOT_REQUIRED_FILE`/`PREFIX` hooks, `elevate_to_root` override, `$0` trick; sanitiser is four whole-line edits; `VERSION` derived; tautological and host-conditional tests replaced |
| MEDIUM-07 | Documentation drift | ✓ Fixed | README, manpage, CLAUDE.md rewritten from the code |
| MEDIUM-08 | `--install` leaves root's cron on a user-writable file | ✓ Fixed | `install -m 755 -o root -g root`; Makefile is the documented path; README recipe removed |
| LOW-01 | Wrong SC2155 justification | ✓ Fixed | |
| LOW-02 | `timer`/`REPLY` not local | ✓ Fixed | |
| LOW-03 | Hidden `systemctl stop` failure | ✓ Fixed | timer stop checked; service stop still `\|\|:` (unit may not exist) |
| LOW-04 | Stray positionals ignored | ✓ Fixed | `die 2` in loop and after `--` |
| LOW-05 | Style batch | ✓ Fixed | braces, `local -i`, `printf '%()T'` for display, `read`/`=~` in `list_schedules`, trailing whitespace; `date +%s`/`+%w` kept on purpose (mockable clock, commented) |
| LOW-06 | `-D` vs BCS0806 | ✓ Documented | `#bcscheck disable=BCS0806` with rationale |
| LOW-07 | `run_tests.sh` | ✓ Fixed | rewritten: `inherit_errexit`, `realpath`, stderr status, `#fin`, exit 18/3 |
| LOW-08 | `tests/test_helper.bash` | ✓ Fixed | rewritten; bats libs `\|\|:`, exports minimal, plain section comments, named heredoc delimiters, `$(<)` |
| LOW-09 | Makefile `$(srcdir)` | ✓ Fixed | anchored sources; `test` target shellchecks all four files |
| LOW-10 | `.gitignore` ignores itself | ✓ Fixed | self-ignore lines removed; file is now untracked-but-trackable (`??`) |
| LOW-11 | Positional `list-timers` parsing | ✓ Fixed | `systemctl show -p NextElapseUSecRealtime --value` |
| LOW-12 | `id -nG ""` | ✓ Fixed | `id -nG` |
| LOW-13 | `--on-active` monotonic timer | ▲ Left as is | informational; no DST on the fleet's zones; documented in CLAUDE.md as a known trade-off |
| LOW-14 | `sudo` inside install | ✓ Fixed | removed with the apt branch |
| LOW-15 | Completion SC2207 | ✓ Fixed | `mapfile -t`; no disable needed |
| INFO-01 | Installed copy stale | ▲ Not deployed | `sudo make install` on this host and `push-to-okusi` for the fleet are operator actions |

### Behaviour changes to note before deploying 1.3.0

- `-D` no longer deletes in the default mode; use `-N -D` (interactive). Any crontab relying on unattended `-D` must change.
- Privilege elevation is lazy: dry runs, `--list`, `-h`, `-V` run unprivileged; `-N`, `-d`, `-N -D`, `-i` re-exec through `sudo` with `-r TIME -m DAYS` prepended.
- Only one `auto-reboot-*.timer` is ever pending; a second run reports it and exits 0.
- Argument errors exit 22, stray positionals 2, missing `systemd-run` 18, not-root 13.
- `--install` copies a root-owned 0755 script only; manpage and completion come from `make install`.

---

## Executive Summary

**Overall Health Score: 7/10**

Strong skeleton: strict mode, typed declarations, locked PATH, `_msg`/`error`/`die`/`noarg` house pattern, two-tier option parsing, syslog audit trail, ShellCheck-clean main script, 133/133 BATS tests passing. Ten of the twelve findings from the 2026-03-12 audit are resolved.

The score is held down by two user-facing defects that the test suite does not cover, a factual error repeated across five documents, and an environment-variable feature that is silently inert under `sudo`. None is hard to fix.

| Severity | Count |
|----------|------:|
| Critical | 0 |
| High     | 2 |
| Medium   | 8 |
| Low      | 15 |

### Top issues (fix first)

1. **HIGH-01** `-r 08:00`, `-r 09:30`, `-r 22:08` crash with `value too great for base` (leading-zero octal parse). Roughly one in nine valid `HH:MM` values is unusable.
2. **HIGH-02** `auto-reboot -D` deletes every timer with no prompt in the default (dry-run) mode, while its own help text says "(asks for confirmation)".
3. **MEDIUM-01** `systemd-run` is attributed to package `systemd-container` in five places; it ships in `systemd`. `--install` installs the wrong package.
4. **MEDIUM-02** `MACHINE_REBOOT_TIME` / `MACHINE_UPTIME_MAXDAYS` are unvalidated (negative delay with exit 0; reboot-every-run with `0`; arithmetic injection) and are stripped by `sudo env_reset` for every non-root invocation.

### Quick wins

- `hour=$((10#${BASH_REMATCH[1]}))` in two places (HIGH-01)
- Move `declare -rx PATH=` above the `realpath` metadata line (MEDIUM-05)
- `die 22` / `die 18` / `die 13` instead of `return 1` (MEDIUM-03), then the manpage EXIT STATUS becomes true
- `local -- timer REPLY` in `delete_all_schedules` (LOW-02)
- Delete 13 trailing-whitespace lines (LOW-05)
- `sudo make install` on this host: the installed copy predates the `--quiet` fix (INFO-01)

### Long-term

- Decide `-D` semantics (HIGH-02) and make the code, help text, README, manpage and insight agree
- Validate env and CLI values through the same functions; forward env values across the sudo re-exec (MEDIUM-02)
- Skip or replace an existing `auto-reboot-*.timer` instead of stacking one per cron run (MEDIUM-04)
- Make the script sourceable without `sed` surgery so tests stop depending on line-anchored patterns (MEDIUM-06)
- One install story: `make install` (root:root 755). Retire `--install`'s symlink-and-chown path (MEDIUM-08)

### Previous audit (2026-03-12) resolutions

| Previous finding | Status |
|------------------|--------|
| HIGH-01 BCS0107 function ordering | ✓ Fixed |
| HIGH-02 SC2015 `A && B \|\| C` | ✓ Fixed (ShellCheck clean) |
| MEDIUM-01 BCS0701 message control flags | ✓ Fixed (`VERBOSE`, `-v`/`-q`) |
| MEDIUM-02 `info` used for error path | ✓ Fixed |
| MEDIUM-03 BCS0711 `>/dev/null 2>&1` ×4 | ✓ Fixed |
| MEDIUM-04 BCS0901 unquoted file tests | ✓ Fixed |
| MEDIUM-05 BCS1201 indentation | ✓ Fixed |
| MEDIUM-06 `readonly --` convention | ✓ Fixed |
| LOW-01 `run_tests.sh` unused `GREEN` | ✗ Still present (LOW-07) |
| LOW-02 completion ShellCheck | ✓ Fixed |
| LOW-03 BCS0801 missing `--` | ✓ Fixed (but see LOW-04) |
| LOW-04 bcscheck suggestions | ✓ Fixed |

---

## ShellCheck Results

```
shellcheck -x auto-reboot                       # clean (0 findings)
shellcheck -x auto-reboot.bash_completion       # clean (file-level SC2207 disable, see LOW-15)
shellcheck -x run_tests.sh                      # 2 warnings
shellcheck -x -s bash tests/test_helper.bash    # 2 warnings
shellcheck -x -s bash tests/*.bats              # 8 (SC2030/SC2031/SC2034 — BATS subshell false positives)
```

| File | Line | Code | Message |
|------|-----:|------|---------|
| run_tests.sh | 5 | SC2155 | `declare -r SCRIPT_DIR=$(...)` masks return value |
| run_tests.sh | 18 | SC2034 | `GREEN` appears unused |
| tests/test_helper.bash | 18 | SC2155 | `export PROJECT_ROOT="$(...)"` masks return value |
| tests/test_helper.bash | 302 | SC2154 | `lines` referenced but not assigned (BATS global; needs a documented disable) |

Directive audit: `auto-reboot:10` carries `#shellcheck disable=SC2155 # realpath return checked by set -e`. The disable is the BCS0103 canonical pattern; the justification is wrong (LOW-01).

---

## BCS Compliance (bcscheck skill, per file, findings verified against source)

Severity follows the rule tier (core → ERROR, recommended/style → WARN). ERROR counts are tier-driven; practical impact is assessed in the Findings section.

| File | ERROR | WARN | Verdict |
|------|------:|-----:|---------|
| auto-reboot | 10 | 42 | **FAIL** |
| run_tests.sh | 4 | 20 | **FAIL** |
| tests/test_helper.bash | 10 | 61 | **FAIL** |

Suppressions honoured: none (`#bcscheck disable=` absent in all files).

### auto-reboot — ERROR (core tier)

| Line | Rule | Finding |
|-----:|------|---------|
| 15 | BCS1002 | PATH locked after `realpath` (line 11) already ran on the inherited PATH |
| 18 | BCS1005 | env `MACHINE_REBOOT_TIME` shape-checked only; `25:00` reaches `date -d` |
| 19 | BCS1005 | env `MACHINE_UPTIME_MAXDAYS` fed to `declare -i` unvalidated |
| 213 | BCS0604 | nested `$(uptime -s)` unchecked; `date -d ""` silently yields midnight |
| 240, 243, 250, 263 | BCS0604 | `target_epoch=$(date -d ...)` unchecked inside an `if` condition; failure yields 0 → negative delay, exit 0 (verified) |
| 388, 417 | BCS0202 | `timer` assigned without `local` in `delete_all_schedules()` |
| 409 | BCS0202 | `REPLY` from `read` not declared `local` |

### auto-reboot — WARN (distinct rules; line lists in Findings)

BCS0207 unnecessary braces ×22 · BCS1213 `$(date ...)` forks ×7 · BCS0602 exit code 1 where table says 22/18/13 ×7 · BCS0505 `local --` for arithmetic-only vars ×3 · BCS0507/BCS1205 `grep -o` + `awk` per line in `list_schedules` · BCS0605 `systemctl stop ||:` then unconditional success · BCS0705 status via `echo` in `delete_all_schedules` · BCS0806 `-D` reassigned from debug to delete-all.

Distinct rules touched: 13 of 122 → **~89 % rule-level compliance** for the main script.

### run_tests.sh — ERROR

| Line | Rule | Finding |
|-----:|------|---------|
| 3 | BCS0101 | no `shopt -s inherit_errexit` |
| 5 | BCS1206 | unsuppressed SC2155 |
| 21, 59 | BCS0702 | status banner / "Running:" line on stdout |

WARN: BCS0103 `cd/dirname/pwd` instead of `realpath`; BCS0105 colour gate checks only `-t 1` while `RED` goes to stderr; BCS0405 `GREEN` unused; BCS0109 no `#fin`; BCS0602 `exit 1` for missing `bats` (18); BCS0711 `>/dev/null 2>&1`; BCS0203 lowercase global `test_files`; BCS0301 ×2; BCS0207 ×11.

### tests/test_helper.bash — ERROR

| Line | Rule | Finding |
|-----:|------|---------|
| 18 | BCS1206 | unsuppressed SC2155 |
| 27, 30, 273 | BCS0604 | `mktemp -d` / `mkdir -p` / `touch` unchecked (BATS aborts setup anyway; low impact) |
| 283–322 | BCS0702 | assertion diagnostics via bare `echo` to stdout ×5 (BATS captures both streams; low impact) |
| 302 | BCS1206 | unsuppressed SC2154 on BATS `lines` |

WARN: BCS0605 `2>/dev/null || true` on both `load` lines (13–14); BCS1205 `$(dirname ...)`; BCS0204 exports nothing reads (18, 19, 35); BCS0201 `declare -g` at file scope (22); BCS1204 box-drawing section comments ×5; BCS0304 generic `EOF` delimiters ×6; BCS0905 `$(cat "$MOCK_LOG")` ×2; BCS1202 paraphrase comment (87); BCS0207 ×~35.

---

## Findings

### HIGH-01: Leading-zero hours/minutes crash the time parser

- **Severity**: High
- **Location**: `auto-reboot:236-237`, `auto-reboot:469,498-499`
- **BCS**: BCS0505 (arithmetic), BCS1005 (input validation)
- **Description**: `local -i hour=${BASH_REMATCH[1]}` and `hour=${BASH_REMATCH[1]}` (with `local -i hour minute`) assign strings such as `08` in arithmetic context. Bash treats a leading `0` as octal, so `08` and `09` are invalid. Reproduced:

```
$ auto-reboot -r 08:00
auto-reboot: line 498: 08: value too great for base (error token is "08")
$ auto-reboot -r 22:08
auto-reboot: line 499: 08: value too great for base (error token is "08")
$ MACHINE_REBOOT_TIME=08:00 auto-reboot
auto-reboot: line 236: local: 08: value too great for base (error token is "08")
auto-reboot: ✗ Failed to calculate reboot delay
```

  `-m 08` fails the same way (line 490) but with a readable message. Hours 00–07 happen to parse (octal 0–7 equal decimal), which is why `04:00`, `03:00`, `22:00` in every documented example work and the suite never sees the fault.
- **Impact**: Any cron entry using `08:xx`, `09:xx`, `xx:08`, `xx:09` never schedules a reboot; exit 1, cron mails the traceback nightly.
- **Recommendation**:

```bash
# calculate_reboot_delay() and main() -r branch: force base 10
local -i hour=$((10#${BASH_REMATCH[1]})) minute=$((10#${BASH_REMATCH[2]}))
# main() -m branch
if [[ $1 =~ ^[0-9]+$ ]] && (( 10#$1 > 0 )); then MACHINE_UPTIME_MAXDAYS=$((10#$1))
```

  Add tests: `-r 08:00`, `-r 09:30`, `-r 22:08`, `-m 08`, and one `calculate_reboot_delay` case that uses the real `date` (all current delay tests run against the mock).

### HIGH-02: `-D` deletes all timers without confirmation in default mode

- **Severity**: High
- **Location**: `auto-reboot:400-415`, usage text `auto-reboot:108-110`, `README.md:72,129-130`, `auto-reboot.1:90-92`
- **BCS**: BCS0806 ("DRY_RUN=1 default for destructive scripts — require `-N` to execute"), BCS1208
- **Description**: `delete_all_schedules()` prompts only when `DRY_RUN=0`. `-D` is a standalone op that runs during parsing with the default `DRY_RUN=1`, so plain `auto-reboot -D` (tty or not) stops and removes every timer immediately and exits 0. `-ND` prompts on a tty and refuses off-tty. Verified with two mocked timers: `-D </dev/null` → both deleted, rc 0. The help text says "(asks for confirmation)". Insight `architecture-001` records the inversion as intentional ("dry-run gates reboot scheduling, not timer management"), but the script's own usage line contradicts it and the semantics are the reverse of every other `-n`/`-N` tool on the fleet.
- **Impact**: An operator who types `-D` "to see what would be deleted" deletes it. Unattended `-N -D` can never work (refuses off-tty), so there is no scripted path either.
- **Recommendation** (needs an owner decision; option A is the BCS-consistent one):

```bash
# A — dry-run previews, -N executes, prompt on tty, -f skips the prompt
delete_all_schedules() {
  ...
  if ((DRY_RUN)); then
    info "[DRY RUN] Would delete $count timer(s):" "${timers[@]}"
    return 0
  fi
  if ((!FORCE_REBOOT)) && [[ -t 0 ]]; then
    yn "Delete all $count schedule(s)?" || { info 'Deletion cancelled.'; return 0; }
  fi
  ...
}
```

  Option B: keep today's behaviour but change the usage line to "Delete all timers immediately; add `-N` to be prompted" and fix README/manpage to match. Either way, add a `-D` test with timers present.

### MEDIUM-01: `systemd-run` attributed to the wrong package

- **Severity**: Medium
- **Location**: `auto-reboot:4,76,136,143,429-433`; `README.md:21`; `auto-reboot.1:100,257-261`; `CLAUDE.md` project overview
- **BCS**: BCS0408 (dependency management), BCS0602 (exit 18)
- **Description**: `dpkg -S /usr/bin/systemd-run` → `systemd`. `systemd-container` provides `systemd-nspawn`, `machinectl`, `systemd-importd`, `portablectl` — not `systemd-run`. `--install` runs `apt-get install systemd-container` when `systemd-run` is missing, which cannot fix the condition (a host without `systemd-run` has no systemd at all) and pulls in container tooling.
- **Impact**: Misleading operator guidance in five places; an unnecessary package on any host where `--install` is used to "repair" a bad PATH.
- **Recommendation**: Delete the apt branch of `install_auto_reboot()`. Replace the message with `die 18 'systemd-run not found (part of systemd); this host is not systemd-managed'`. Correct the four documents: "Requires: systemd (`systemd-run`)".

### MEDIUM-02: Environment overrides are unvalidated and are stripped by sudo

- **Severity**: Medium
- **Location**: `auto-reboot:18-19`, `auto-reboot:461-465`, `auto-reboot:240-263`
- **BCS**: BCS1005 (core), BCS0604 (core), BCS1208
- **Description** (all verified):
  - `MACHINE_UPTIME_MAXDAYS=abc` → `line 19: abc: unbound variable` (set -u) — cryptic crash.
  - `MACHINE_UPTIME_MAXDAYS=0` → `UPTIME_DAYS >= 0` is always true → reboot scheduled on every run.
  - `MACHINE_UPTIME_MAXDAYS='x[$(cmd)]'` → `declare -i` evaluates the subscript, `cmd` runs (arithmetic injection; caller already controls the environment, so exposure is limited to root's own crontab).
  - `MACHINE_REBOOT_TIME=25:00` → `date` fails twice inside the `if delay=$(...)` condition where errexit is suspended, `target_epoch` stays 0, output is `Delay: -1788746949`, `Scheduled: 1970-01-01`, exit 0; with `-N` the script calls `systemd-run --on-active=-1788746949s`.
  - `sudo` default `env_reset` (confirmed: `secure_path`, no `env_keep` for `MACHINE_*`) drops both variables when a sudo-group user invokes the script, so the documented feature only works when already root.
- **Impact**: The README/manpage ENVIRONMENT section is wrong for interactive use; bad values from root's crontab produce nonsense without a non-zero exit.
- **Recommendation**:

```bash
# one validator, used by env defaults and by -r / -m
validate_time() { [[ $1 =~ ^([0-9]{1,2}):([0-9]{2})$ ]] && ((10#${BASH_REMATCH[1]} < 24 && 10#${BASH_REMATCH[2]} < 60)); }
validate_days() { [[ $1 =~ ^[0-9]+$ ]] && ((10#$1 > 0)); }

declare -- MACHINE_REBOOT_TIME=${MACHINE_REBOOT_TIME:-22:00}
declare -- MACHINE_UPTIME_MAXDAYS=${MACHINE_UPTIME_MAXDAYS:-14}   # string until validated
...
validate_time "$MACHINE_REBOOT_TIME"    || die 22 "MACHINE_REBOOT_TIME ${MACHINE_REBOOT_TIME@Q} is not HH:MM"
validate_days "$MACHINE_UPTIME_MAXDAYS" || die 22 "MACHINE_UPTIME_MAXDAYS ${MACHINE_UPTIME_MAXDAYS@Q} is not a positive integer"

# sudo re-exec: forward as options so validation and sudo env_reset are both satisfied
sudo "$0" -r "$MACHINE_REBOOT_TIME" -m "$MACHINE_UPTIME_MAXDAYS" "$@"
```

  Also check every `date -d` result: `target_epoch=$(date -d "today $hour:$minute" +'%s') || return 1`.

### MEDIUM-03: Exit codes do not match the manpage or BCS0602

- **Severity**: Medium
- **Location**: `auto-reboot:466,493,503,506,511,544,555`; `auto-reboot.1:161-170`
- **BCS**: BCS0602 (recommended), BCS0801
- **Description**: Every argument error path does `error '...'; return 1`, so `-r noon`, `-r 25:00`, `-m abc`, `-a Funday`, `--nonexistent` all exit 1. Only `noarg()` exits 22. The manpage EXIT STATUS claims 22 for "bad time format, invalid day". Not-root exits 1 (table: 13); missing `systemd-run` exits 1 (table: 18).
- **Impact**: Callers and the manpage disagree with the binary; cron wrappers cannot distinguish usage errors from runtime failures.
- **Recommendation**: `die 22 "..."` in the parse loop (this also removes the `usage` dump to stdout on an unknown option), `die 13 'Requires root or sudo group membership'`, `die 18` for the dependency. Update the manpage table.

### MEDIUM-04: Repeated runs stack duplicate timers

- **Severity**: Medium
- **Location**: `auto-reboot:305-308`
- **BCS**: BCS1208 (dry-run pattern), BCS1213
- **Description**: `schedule_reboot()` never checks for an existing `auto-reboot-*.timer`. The documented cron pattern runs nightly; while `/var/run/reboot-required` persists or uptime stays over the threshold, each run creates another transient timer for the same wall-clock target. Commit 3c468e3 ("cron mails every night in the week before a reboot") documents exactly this pattern in production. Two runs in the same second reuse `--unit=auto-reboot-$(date +%s)` and the second `systemd-run` fails.
- **Impact**: `--list` shows N identical entries; N `shutdown -r now` invocations race at the target time; syslog carries N "Successfully scheduled" lines for one reboot.
- **Recommendation**:

```bash
# in schedule_reboot(), before systemd-run
local -- existing
existing=$(systemctl list-units --type=timer --all --plain --no-legend "$SCRIPT_NAME-*.timer" | awk 'NR==1{print $1}')
if [[ -n $existing ]]; then
  info "Reboot already scheduled by $existing; nothing to do"
  return 0
fi
--unit="$SCRIPT_NAME-$EPOCHSECONDS"
```

  (Or stop the old one and replace it when the new target is earlier.)

### MEDIUM-05: PATH locked after the first external command

- **Severity**: Medium (core tier; practical exposure low because sudo `secure_path` and cron's minimal PATH apply)
- **Location**: `auto-reboot:11` vs `auto-reboot:15`
- **BCS**: BCS1002 (core)
- **Description**: `realpath` at line 11 resolves through the caller's PATH; the lock at line 15 comes afterwards. BCS1002: "Place PATH setting early, before any commands that depend on it."
- **Recommendation**: Move `declare -rx PATH=...` to directly after `shopt`, before the metadata block.

### MEDIUM-06: Test suite gaps and fragility

- **Severity**: Medium
- **Location**: `tests/conditions.bats:23-32,54-69,97-109`; `tests/test_helper.bash:58-128,272-275`; `tests/reboot_delay.bats`
- **BCS**: BCS1209 (testing support), BCS0106/BCS0406 (dual-purpose scripts)
- **Description**:
  - `conditions.bats` test 1 asserts `REBOOT_NEEDED == 0 || == 1` — a tautology. Three further tests are wrapped in `if [[ ! -f /var/run/reboot-required ]]`, so they pass vacuously on any host that needs a reboot.
  - `create_mock_reboot_required()` writes to `$TEST_TEMP_DIR/var/run`, but the script hard-codes `/var/run/reboot-required`; the helper is dead and the reboot-required branch is untested.
  - Every `calculate_reboot_delay` test uses the `date` mock, which accepts 1–2 digit hours; the real-`date` path (and HIGH-01) is uncovered. No tests for env overrides, `-ND` prompting, `-D` with timers present, `-- stray args`, `--install`, or the sudo block (stripped by `sed`).
  - `source_script()` and `run_script()` duplicate a 12-expression `sed` sanitiser keyed to exact source lines (`/^  if ((EUID)); then/,/^  fi$/d`). Any refactor of `main()` silently changes what the harness executes (insight `bash-001`).
  - `VERSION="1.2.0"` hard-coded in two helper locations; `CLAUDE.md` documents a three-way manual sync and cites the wrong line numbers (79/116; actual 82/121).
- **Recommendation**: Give the script a source fence (`[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0` before `set -euo pipefail`/`main "$@"`, per BCS0406) plus `REBOOT_REQUIRED_FILE` and PATH-lock guards keyed on a `AUTO_REBOOT_TEST=1` variable, so tests source the real file. Factor one `_sanitize_script()` in the meantime. Derive `VERSION` with `sed -n 's/^declare -r VERSION=//p' "$SCRIPT_UNDER_TEST"`. Replace the tautology and host-conditional tests with mocked-file assertions.

### MEDIUM-07: Documentation drift

- **Severity**: Medium
- **Location**: `README.md:55,170-177,49-52`; `auto-reboot.1:161-170,253-261`; `CLAUDE.md`
- **Description**:
  - README installs `.bash_completion`; the file is `auto-reboot.bash_completion`. File Structure lists `.bash_completion` and omits `Makefile`, `auto-reboot.1`, `auto-reboot.bash_completion`.
  - Three conflicting install stories: README manual (`chmod 770`, `chown $USER:sudo`), `--install` (symlink to the checkout, `770 user:sudo`), Makefile (`install -m 755`, root-owned). The host runs the Makefile variant.
  - Manpage EXIT STATUS (MEDIUM-03) and DEPENDENCIES (MEDIUM-01) are wrong.
  - `CLAUDE.md`: `.bash_completion` name, helper line numbers, `systemd-container`.
- **Recommendation**: Make the Makefile the single install path and document only it; regenerate File Structure from `git ls-files`.

### MEDIUM-08: `--install` and README install leave root's cron running a user-writable file

- **Severity**: Medium (security)
- **Location**: `auto-reboot:444-453`; `README.md:49-52`
- **BCS**: BCS1001 (adjacent), BCS1005
- **Description**: `--install` symlinks `/usr/local/bin/auto-reboot` to `$SCRIPT_PATH` (wherever the checkout lives), then `chown $XUSER:sudo` and `chmod 770` both. The README manual path does the same on a copy. Root's crontab then executes a file writable by one user and the whole `sudo` group. A user in that group who has lost their password (stolen SSH key, unattended session) cannot `sudo`, but can edit this file and obtain root at the next cron run.
- **Impact**: Passwordless privilege escalation for any compromised sudo-group account on hosts installed via `--install` or the README recipe. The Makefile path (`root:root 0755`) is not affected.
- **Recommendation**: Remove the `chown`/`chmod`/symlink block; have `--install` copy with `install -m 755 -o root -g root`, or delete `--install` and point at `make install`. Fix README lines 49–52.

### LOW-01: SC2155 justification is factually wrong

- **Location**: `auto-reboot:10`
- **BCS**: BCS1206, BCS0103
- **Description**: "realpath return checked by set -e" — `declare -r X=$(cmd)` returns declare's status, so `set -e` never sees a `realpath` failure. The disable itself is the BCS0103 canonical form.
- **Recommendation**: `#shellcheck disable=SC2155 # BCS0103 metadata pattern; realpath failure is not recoverable here`.

### LOW-02: Undeclared function-scope variables

- **Location**: `auto-reboot:388,417` (`timer`), `auto-reboot:409` (`REPLY`)
- **BCS**: BCS0202 (core)
- **Recommendation**: `local -- timer REPLY` at the top of `delete_all_schedules()`.

### LOW-03: `systemctl stop` failures are hidden, then success is logged

- **Location**: `auto-reboot:374-379`
- **BCS**: BCS0605
- **Description**: Both `systemctl stop ... ||:` lines suppress errors; the function then writes "Deleted ... by user" to syslog and prints "Successfully deleted" regardless.
- **Recommendation**: `systemctl stop "$timer_name" || { error "Failed to stop ${timer_name@Q}"; return 1; }`; keep `||:` only for the `.service` unit, which often does not exist.

### LOW-04: Positional arguments after `--` are silently ignored

- **Location**: `auto-reboot:536-548`
- **BCS**: BCS0803 (core: "Validate required arguments after parsing")
- **Description**: `auto-reboot -- stray positional` runs normally (verified). The script takes no positionals, so any are a user error.
- **Recommendation**: after the loop, `(($#)) && die 2 "Unexpected argument ${1@Q}" ||:`.

### LOW-05: Style findings in `auto-reboot` (batch)

- **BCS0207** unnecessary braces (22): lines 41, 42, 106, 107, 240, 243, 250, 263, 306, 309, 310, 316, 329, 339, 353, 357, 360, 393, 567, 575 — `${hour}:${minute}` → `$hour:$minute`, `${SCRIPT_NAME}-` → `"$SCRIPT_NAME"-`, `${delay} seconds` → `$delay seconds`.
- **BCS1213** `$(date +'%s')`/`$(date +'%w')` forks (194, 214, 233, 247, 306, 309, 575) → `$EPOCHSECONDS`, `printf -v current_day '%(%w)T' -1`, `printf '%(%F %T %Z)T' "$((EPOCHSECONDS + delay))"`.
- **BCS0505** `local --` for arithmetic-only variables (193, 212, 258) → `local -i`.
- **BCS0507/BCS1205** `list_schedules` forks `grep -o` and `awk` per line (339–340) → `[[ $line =~ ($SCRIPT_NAME-[0-9]+\.timer) ]]` and `read -r d1 d2 d3 d4 _ <<< "$line"`.
- **BCS0705** `echo` status lines inside `delete_all_schedules` (406, 408, 410) → `info`/`>&2`.
- **Trailing whitespace** on 13 lines: 330, 335, 343, 351, 364, 370, 372, 376, 378, 394, 399, 416, 420.
- **Lines over 100** (BCS1201 allows 120; audit template asks for 100): 301, 309, 329, 393, 567.
- `parse_day` error prefixes `${FUNCNAME[1]}` (161), leaking `parse_allowed_days:` to the user.

### LOW-06: `-D` conflicts with the BCS0806 standard letter

- **Location**: `auto-reboot:528`
- **Description**: BCS0806 reserves `-D` for `--debug`. The letter is a public interface used in cron lines and completion; changing it is a breaking change.
- **Recommendation**: Keep it, and document the deviation: `#bcscheck disable=BCS0806 # -D is --delete-all here (public interface since 1.0)`.

### LOW-07: `run_tests.sh`

- No `shopt -s inherit_errexit` (BCS0101); SC2155 unsuppressed (BCS1206); `GREEN` declared, never used (BCS0405 — carried over from the March audit); banner and "Running:" on stdout (BCS0702); colour gate checks only `-t 1` while `RED` goes to stderr (BCS0105); no `#fin` (BCS0109); `exit 1` for missing `bats` (BCS0602: 18); `>/dev/null 2>&1` (BCS0711); lowercase global `test_files` (BCS0203); braces ×11 (BCS0207); double-quoted literals ×2 (BCS0301).

### LOW-08: `tests/test_helper.bash`

- `load ... 2>/dev/null || true` ×2 (BCS0605; both libraries are installed and the fallback hides a real breakage; use `||:` if kept); SC2155 (18) and SC2154 (302, BATS `lines`) unsuppressed (BCS1206); `$(dirname "${BASH_SOURCE[0]}")` (BCS1205); exports nothing reads (BCS0204: 18, 19, 35 — only `MOCK_LOG` reaches the mocks); `declare -g` at file scope (BCS0201); box-drawing section comments ×5 (BCS1204); generic `EOF` delimiters ×6 (BCS0304); `$(cat "$MOCK_LOG")` ×2 (BCS0905); paraphrase comment (87, BCS1202); braces ×~35 (BCS0207).

### LOW-09: Makefile

- Sources are not anchored with `$(srcdir)` (BCS1212 "Source Path Anchoring"), so `sudo make -f /path/Makefile install` from another directory fails. Install mode 755 disagrees with README/`--install` 770 (MEDIUM-07). `test` target could also run `bcscheck`.

### LOW-10: `.gitignore` ignores itself

- `.gitignore` lists `.gitignore`, `.git*`; `git ls-files` confirms it is untracked. A fresh clone of the public GitHub remote has no ignore rules, so `CLAUDE.md`/`.claude/` (never to be committed, per enterprise policy) are unprotected for any other contributor.
- **Recommendation**: remove the self-ignore lines and track `.gitignore`.

### LOW-11: `list_schedules` parses `list-timers` columns positionally

- `awk '{print $1,$2,$3,$4}'` assumes NEXT is exactly four fields; column layout differs across systemd versions and `LC_TIME`. Prefer `systemctl show -p NextElapseUSecRealtime --value "$timer"`.

### LOW-12: `id -nG "${USER:-}"` when `USER` is unset

- `auto-reboot:137,462`. `id -nG ""` → `id: '': no such user` (verified). Use `id -nG` with no argument.

### LOW-13: `--on-active` is monotonic time

- `auto-reboot:305`. Delay in seconds drifts across a DST change or suspend; `--on-calendar="$(date -d "@$target_epoch" '+%F %T')"` pins wall-clock time. Informational for WIB/WITA/WIT hosts (no DST).

### LOW-14: `install_auto_reboot` uses `sudo` while already root

- `auto-reboot:429,433`. `main()` has already re-executed as root; the inner `sudo` is redundant and fails under `env -i`. Moot if MEDIUM-01's apt branch is removed.

### LOW-15: Completion file

- File-level `# shellcheck disable=SC2207` without justification (BCS1206). `mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")` removes the need. Missing the `--dryrun`/`--notdryrun` aliases the script accepts (undocumented anywhere; consider dropping them from the script instead).

### INFO-01: Installed copy is stale

- `/usr/local/bin/auto-reboot` (2026-09-05, root:root 755) lacks commit 3c468e3 (`systemd-run --quiet`). The fix that stops nightly cron mail is not deployed on this host. `sudo make install`, then `push-to-okusi` as appropriate.

---

## Security Analysis

| Check | Result |
|-------|--------|
| SUID/SGID on scripts (BCS1001) | ✓ None (`-rwxrwx--x`; directory setgid is the documented dev-box convention) |
| PATH lock (BCS1002) | ▲ Present, but after `realpath` (MEDIUM-05) |
| `eval` / indirect expansion (BCS1004) | ✓ None |
| Input validation (BCS1005) | ▲ CLI values validated; env values not (MEDIUM-02); positionals unchecked (LOW-04) |
| Temp files (BCS1006) | ✓ None used by the script; tests use `mktemp -d` with guarded `rm -rf` |
| Privilege flow | ▲ Any sudo-group member auto-elevates to root — acceptable for this tool; `--install`'s `770 user:sudo` symlink creates a passwordless escalation path (MEDIUM-08) |
| Command construction | ✓ `systemd-run ... bash -c "$reboot_cmd"` contains only `$SCRIPT_NAME` (from `realpath`); the `bash -c` wrapper is unnecessary — pass `/sbin/shutdown -r now "Scheduled reboot by $SCRIPT_NAME"` directly |
| Secrets / internal hosts in tracked files | ✓ None (`git ls-files` reviewed; remote is public GitHub) |
| Audit trail | ✓ `logger -t auto-reboot` with `$XUSER` on schedule and delete; ▲ "Deleted" logged even when `systemctl stop` failed (LOW-03) |

---

## Test Suite Analysis

- **Result**: 133/133 pass (`./run_tests.sh`), 6 suites, BATS 1.11.0, bats-support/bats-assert present but unused (custom assertions only).
- **Coverage by function**: `parse_day` 23 tests (thorough); `parse_allowed_days` 7; `is_reboot_day_allowed` 5; `calculate_reboot_delay` 9 (mock `date` only); `check_reboot_conditions` 8 (4 host-dependent, 1 tautological); `schedule_reboot` 6; `list_schedules` 4; `delete_schedule` 7; `delete_all_schedules` 2 (no timers-present + prompt case); CLI 41.
- **Uncovered**: HIGH-01 inputs, env overrides, `-D` with timers, `-ND` prompt/refusal, `--` positionals, `--install`, sudo elevation, reboot-required file branch, real-`date` delay path.
- **Isolation**: ✓ per-test `mktemp -d`, PATH restored in teardown, `rm -rf` guarded by `-n`/`-d`.
- **Fragility**: line-anchored `sed` sanitiser duplicated in two helpers (MEDIUM-06).

---

## Performance Notes

Per run the script forks `date` up to 7 times, `uptime` twice, plus `grep`/`awk` per listed timer. All replaceable with `$EPOCHSECONDS`, `printf '%()T'`, `read`, and `[[ =~ ]]` (BCS1213, BCS1205). Uptime can be read without any fork:

```bash
local -- up _
read -r up _ < /proc/uptime
UPTIME_DAYS=$(( ${up%.*} / 86400 ))
```

None of this matters at one run per night; listed for completeness.

---

## File Statistics

| File | Lines | Notes |
|------|------:|-------|
| auto-reboot | 597 | 18 functions, `main()` 136 lines |
| tests/cli.bats | 282 | 41 tests |
| tests/parse_days.bats | 232 | 35 tests |
| tests/schedule.bats | 190 | 19 tests |
| tests/utility.bats | 155 | 21 tests |
| tests/reboot_delay.bats | 139 | 9 tests |
| tests/conditions.bats | 122 | 8 tests |
| tests/test_helper.bash | 327 | 18 functions |
| run_tests.sh | 62 | |
| Makefile | 50 | BCS1212 tier 2 |
| auto-reboot.bash_completion | 55 | |
| auto-reboot.1 | 274 | |

---

## Tool Output Summary

| Tool | Result |
|------|--------|
| `bash -n auto-reboot` | ✓ OK |
| `shellcheck -x auto-reboot` | ✓ 0 findings |
| `shellcheck` supporting files | ▲ 4 warnings (SC2155 ×2, SC2034, SC2154) |
| bcscheck skill (auto-reboot) | ✗ FAIL — 10 ERROR / 42 WARN (tier-driven) |
| bcscheck skill (run_tests.sh) | ✗ FAIL — 4 ERROR / 20 WARN |
| bcscheck skill (test_helper.bash) | ✗ FAIL — 10 ERROR / 61 WARN |
| `./run_tests.sh` | ✓ 133/133 |
| Empirical probes | ✗ `-r 08:00` crash; ✗ `-D` silent delete; ✗ env `25:00` negative delay exit 0; ✗ sudo drops `MACHINE_*`; ✓ real `date` accepts `H:M` |

---

## Actionable Recommendations

### Immediate

1. Base-10 the `BASH_REMATCH` assignments and `-m` check; add the four failing-input tests (HIGH-01).
2. Decide `-D` semantics; align code, `usage`, README, manpage, insight (HIGH-02).
3. Correct `systemd-container` → `systemd` in five places; drop the apt branch (MEDIUM-01).
4. Redeploy the `--quiet` build (INFO-01).

### Short-term

5. Shared validators for env and CLI; forward env values through the sudo re-exec; check every `date -d` (MEDIUM-02).
6. `die 22/13/18` exit codes; positional-argument guard; manpage EXIT STATUS (MEDIUM-03, LOW-04).
7. Existing-timer check before `systemd-run`; `$EPOCHSECONDS` unit names (MEDIUM-04).
8. PATH lock before metadata (MEDIUM-05). `local -- timer REPLY` (LOW-02). Check `systemctl stop` (LOW-03).
9. One install path, root-owned 0755; remove `chown user:sudo` from script and README (MEDIUM-08, MEDIUM-07).

### Optional

10. Source fence + test hooks so the suite sources the real script; dedupe the sanitiser; derive `VERSION` (MEDIUM-06).
11. Style batch: braces, `local -i`, `printf '%()T'`, trailing whitespace, `run_tests.sh`/helper findings (LOW-05, LOW-07, LOW-08).
12. Track `.gitignore` (LOW-10); `$(srcdir)` in Makefile (LOW-09); `#bcscheck disable=BCS0806` note (LOW-06).

#fin
