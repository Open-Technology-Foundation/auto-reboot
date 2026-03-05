# auto-reboot

Intelligent system reboot scheduler with flexible timing and day-of-week restrictions.

**Version:** 1.1.1
**License:** GPL-3.0

## Overview

`auto-reboot` schedules system reboots via systemd transient timers based on:
- System update requirements (`/var/run/reboot-required`)
- Maximum uptime threshold (default: 14 days)
- Manual force reboot requests

Dry-run by default. Requires explicit `-N` to execute.

## Requirements

- Linux with systemd
- Bash 4.0+ (5.0+ recommended)
- `systemd-run` (systemd-container package)
- Root or sudo group membership

## Quick Start

```bash
# Check if reboot needed (dry run)
auto-reboot

# Schedule reboot if conditions met
auto-reboot -N

# Force reboot at 3 AM
auto-reboot -f -r 03:00 -N

# List scheduled reboots
auto-reboot -l

# Delete all scheduled reboots
auto-reboot -D
```

## Installation

```bash
# Auto-install script and dependencies
auto-reboot --install

# Manual installation
sudo cp auto-reboot /usr/local/bin/
sudo chmod 770 /usr/local/bin/auto-reboot
sudo chown root:sudo /usr/local/bin/auto-reboot

# Bash completion (optional)
sudo cp .bash_completion /etc/bash_completion.d/auto-reboot
```

## Options

| Option | Description |
|--------|-------------|
| `-n, --dry-run` | Test mode, no execution (default) |
| `-N, --not-dry-run` | Execute for real |
| `-f, --force-reboot` | Force reboot regardless of conditions |
| `-m, --max-uptime-days DAYS` | Max uptime before reboot (default: 14) |
| `-r, --reboot-time HH:MM` | Scheduled reboot time (default: 22:00) |
| `-a, --allowed-days DAYS` | Restrict to specific days (see below) |
| `-l, --list` | List all scheduled reboots |
| `-d, --delete TIMER` | Delete specific timer (ID or full name) |
| `-D, --delete-all` | Delete all timers (with confirmation) |
| `-i, --install` | Install to /usr/local/bin with dependencies |
| `-V, --version` | Show version |
| `-h, --help` | Show help |

Short options can be bundled: `-Nf` is equivalent to `-N -f`.

## Day Specifications

The `--allowed-days` option accepts comma-separated values in any of these formats:

| Format | Example |
|--------|---------|
| Short names | `Sun`, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat` |
| Full names | `Sunday`, `Monday`, ..., `Saturday` |
| Numbers | `0` (Sunday) through `6` (Saturday) |
| Mixed | `Mon,Wed,5` |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MACHINE_REBOOT_TIME` | `22:00` | Default reboot time (HH:MM) |
| `MACHINE_UPTIME_MAXDAYS` | `14` | Default max uptime in days |

CLI options override environment variables.

## Scheduling Logic

1. **No day restrictions**: Schedules for today at the specified time, or tomorrow if that time has passed.
2. **With day restrictions**: Finds the next allowed day within 7 days.
3. **Force reboot**: Bypasses reboot-required and uptime checks; time/day restrictions still apply.

## Examples

### Cron Integration

```bash
# Daily check at 11 PM, reboot Sunday at 4 AM if needed
0 23 * * * /usr/local/bin/auto-reboot -m 14 -r 04:00 -a Sun -N

# Check every 6 hours, reboot anytime if uptime > 30 days
0 */6 * * * /usr/local/bin/auto-reboot -m 30 -N

# Weekly forced reboot Sunday at 3 AM
0 2 * * 0 /usr/local/bin/auto-reboot -f -r 03:00 -N
```

### Schedule Management

```bash
# List active timers
auto-reboot --list

# Delete by timestamp ID
auto-reboot --delete 1753063354

# Delete all (prompts for confirmation)
auto-reboot -D
```

## Logging

All operations are logged to syslog via `logger -t auto-reboot`:

```bash
# View logs
sudo journalctl -t auto-reboot
```

## Safety Features

- **Dry run by default** -- prevents accidental reboots
- **Automatic sudo elevation** -- seamless privilege escalation
- **Confirmation prompts** -- for destructive operations (delete-all)
- **Input validation** -- time format, day specs, numeric ranges
- **Readonly state** -- critical variables frozen after argument parsing
- **Syslog audit trail** -- all operations logged with username

## Troubleshooting

```bash
# Verify systemd-run is available
command -v systemd-run || auto-reboot --install

# Check systemd health
systemctl is-system-running

# List auto-reboot timers
systemctl list-timers --all | grep auto-reboot

# View recent logs
journalctl -t auto-reboot --since "1 hour ago"
```

## File Structure

```
auto-reboot          # Main script
.bash_completion     # Tab completion for bash
LICENSE              # GPL-3.0
README.md            # This file
```
