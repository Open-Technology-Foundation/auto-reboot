# auto-reboot

Conditional system reboot scheduler with flexible timing and day-of-week restrictions.

**Version:** 1.4.1
**License:** GPL-3.0

## Overview

`auto-reboot` schedules a system reboot via a systemd transient timer when any of these holds:
- System updates require a reboot (`/var/run/reboot-required` exists)
- Uptime has reached the maximum threshold (default: 14 days)
- A reboot is forced with `-f`

Dry-run by default. Requires explicit `-N` to execute.

Site defaults live in `/etc/auto-reboot.conf`; command-line options override them.

Only one reboot is pending at a time. When an `auto-reboot` timer already exists, a new run reports it and schedules nothing, so a nightly cron entry never stacks timers.

## Requirements

- Linux with systemd (`systemd-run` and `systemctl`, both in the `systemd` package)
- Bash 5.2+
- `update-notifier-common`: its `notify-reboot-required` hook is what writes `/var/run/reboot-required` after kernel or library updates. Without it only the uptime threshold can trigger a reboot. `make install` installs the package when the hook is missing.
- Root, or membership of the `sudo` group, to execute (`-N`), delete timers, or install. Dry runs and `--list` work for any user.

When invoked by a `sudo` group member, the script re-executes itself through `sudo` and forwards its settings as options.

## Quick Start

```bash
# Check whether a reboot is needed (dry run, no root required)
auto-reboot

# Schedule the reboot if conditions are met
auto-reboot -N

# Force a reboot at 03:00
auto-reboot -f -r 03:00 -N

# List scheduled reboots
auto-reboot -l

# Preview, then delete all scheduled reboots
auto-reboot -D
auto-reboot -N -D
```

## Installation

```bash
sudo make install      # script (root-owned 0755), manpage, bash completion, /etc/auto-reboot.conf
sudo make check        # verify the install, including the config and the reboot-required hook
sudo make uninstall    # keeps /etc/auto-reboot.conf if it was edited
```

`/etc/auto-reboot.conf` is installed once, with default values, and never overwritten. `make install` also runs `apt-get install update-notifier-common` when `/usr/share/update-notifier/notify-reboot-required` is absent. Set `DESTDIR` for a staged install; the package step is skipped.

`auto-reboot --install` copies only the script, root-owned, to `$PREFIX/bin` (default `/usr/local`).

Root's cron runs this script. Never install it group-writable or as a symlink into a user's checkout.

## Options

| Option | Description |
|--------|-------------|
| `-n, --dry-run` | Test mode, no execution (default) |
| `-N, --not-dry-run` | Execute for real |
| `-f, --force-reboot` | Force reboot regardless of conditions |
| `-v, --verbose` | Verbose output (default) |
| `-q, --quiet` | Suppress informational messages |
| `-m, --max-uptime-days DAYS` | Max uptime before reboot (default: 14) |
| `-r, --reboot-time HH:MM` | Scheduled reboot time (default: 22:00) |
| `-a, --allowed-days DAYS` | Restrict to specific days (see below) |
| `-l, --list` | List all scheduled reboots |
| `-d, --delete TIMER` | Delete one timer immediately (ID or full name) |
| `-D, --delete-all` | Dry run lists what would be deleted; `-N -D` confirms, then deletes |
| `-i, --install` | Install a root-owned copy to `$PREFIX/bin` |
| `-V, --version` | Show version |
| `-h, --help` | Show help |

Short options can be bundled: `-Nf` is equivalent to `-N -f`. Standalone operations (`-l`, `-d`, `-D`, `-i`, `-V`, `-h`) run as soon as they are parsed, so `-N` must come before `-D`.

## Day Specifications

The `--allowed-days` option accepts comma-separated values in any of these formats:

| Format | Example |
|--------|---------|
| Short names | `Sun`, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat` |
| Full names | `Sunday`, `Monday`, ..., `Saturday` |
| Numbers | `0` (Sunday) through `6` (Saturday) |
| Mixed | `Mon,Wed,5` |

Case insensitive. Whitespace around commas is ignored.

## Configuration File

`/etc/auto-reboot.conf` holds the site defaults. It is sourced as bash, so it must be owned by root, must not be group- or world-writable, and should contain only these assignments:

| Key | Default | Description | Overridden by |
|-----|---------|-------------|---------------|
| `MACHINE_REBOOT_TIME` | `22:00` | Reboot time (HH:MM, 00:00 to 23:59) | `--reboot-time` |
| `MACHINE_UPTIME_MAXDAYS` | `14` | Max uptime in days (positive integer) | `--max-uptime-days` |
| `MACHINE_ALLOWED_DAYS` | empty (any day) | Day list, same formats as `--allowed-days` | `--allowed-days` (`''` clears) |

Values are validated at startup (exit 19 on a bad value or a file that fails to load, 13 on a file root cannot trust). No other path is searched, and there is no per-user config: the script runs as root. A typical fleet file:

```bash
MACHINE_REBOOT_TIME=04:20
MACHINE_UPTIME_MAXDAYS=14
MACHINE_ALLOWED_DAYS=Sun
```

The only environment variable is `PREFIX` (default `/usr/local`), the installation prefix for `--install`.

## Scheduling Logic

1. **No day restrictions**: today at the given time, or tomorrow if that time has passed.
2. **With day restrictions**: the next allowed day within 7 days.
3. **Force reboot**: bypasses the reboot-required and uptime checks; time and day restrictions still apply.
4. **One pending reboot**: an existing `auto-reboot-*.timer` is reported and left alone.

Timers are transient systemd units named `auto-reboot-EPOCH.timer`, created with
`systemd-run --on-calendar` and `AccuracySec=1s`. The target is an absolute wall-clock
timestamp, so a clock adjustment between scheduling and firing cannot move the reboot
off its intended slot.

## Exit Status

| Code | Meaning |
|-----:|---------|
| 0 | Success |
| 1 | Runtime failure (systemd not running, scheduling failed, cannot prompt) |
| 2 | Unexpected positional argument |
| 13 | Not root and not in the `sudo` group; or config file not root-owned or writable by others |
| 18 | `systemd-run` not found |
| 19 | Config file failed to load, or holds an invalid value |
| 22 | Invalid option or option value |

## Examples

### Cron Integration

```bash
# Nightly check using the settings in /etc/auto-reboot.conf
15 23 * * * /usr/local/bin/auto-reboot -q -N

# Same, overriding the file: reboot Sunday 04:00 once uptime reaches 14 days
0 23 * * * /usr/local/bin/auto-reboot -q -m 14 -r 04:00 -a Sun -N

# Check every 6 hours, reboot at 22:00 once uptime reaches 30 days
0 */6 * * * /usr/local/bin/auto-reboot -q -m 30 -N

# Weekly forced reboot Sunday at 03:00
0 2 * * 0 /usr/local/bin/auto-reboot -qf -r 03:00 -N
```

Use `-q` under cron: only errors reach the mail spool.

### Schedule Management

```bash
# List active timers (no root needed)
auto-reboot --list

# Delete one timer by timestamp ID
auto-reboot --delete 1753063354

# Preview a delete-all, then run it with confirmation
auto-reboot -D
auto-reboot -N -D
```

## Logging

Schedule and delete operations are logged to syslog via `logger -t auto-reboot`:

```bash
sudo journalctl -t auto-reboot
```

## Safety Features

- **Dry run by default**, for scheduling and for `--delete-all`
- **Lazy privilege elevation**: only `-N`, delete, and install go through `sudo`
- **Trusted config only**: `/etc/auto-reboot.conf` is refused unless root-owned and not writable by others
- **Confirmation prompt** before `-N -D` deletes anything; refuses without a terminal
- **Input validation** of times, day lists, integers, and config values before anything runs
- **One pending reboot** per host
- **Readonly state** frozen after argument parsing
- **Syslog audit trail** with the invoking user's name

## Testing

```bash
./run_tests.sh              # full BATS suite
./run_tests.sh cli          # one suite
make test                   # suite plus shellcheck
```

The suite pins the clock (one epoch, UTC) and mocks `uptime`, `systemctl`, `systemd-run`, `logger`, `sudo`, `id`, `install`, `stat`, and `apt-get`; it never touches the real system.

## Troubleshooting

```bash
# Verify systemd-run is available
command -v systemd-run

# Check systemd health (degraded is tolerated, offline is not)
systemctl is-system-running

# Inspect timers directly
systemctl list-timers --all | grep auto-reboot

# Recent log lines
journalctl -t auto-reboot --since "1 hour ago"
```

## File Structure

```
auto-reboot                  # Main script
auto-reboot.1                # Manpage
auto-reboot.bash_completion  # Tab completion for bash
auto-reboot.conf             # Default /etc/auto-reboot.conf
Makefile                     # install / uninstall / check / test
run_tests.sh                 # BATS test runner
tests/                       # BATS test suite (8 files + test_helper.bash)
AUDIT-BASH.md                # Code audit report
LICENSE                      # GPL-3.0
README.md                    # This file
```
