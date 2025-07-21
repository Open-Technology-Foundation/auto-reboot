# auto-reboot

Intelligent system reboot scheduler with flexible timing and day-of-week restrictions.

## Overview

`auto-reboot` schedules system reboots based on:
- System update requirements (`/var/run/reboot-required`)
- Maximum uptime threshold (default: 14 days)
- Manual force reboot requests

**Key features**: Automatic sudo elevation, systemd timer integration, dry-run safety, schedule management, and syslog audit trails.

## Quick Start

```bash
# Check if reboot needed (dry run by default)
auto-reboot

# Schedule reboot if conditions are met
auto-reboot -N

# Force reboot at 3 AM
auto-reboot --force-reboot --reboot-time 03:00 -N

# List scheduled reboots
auto-reboot --list

# Delete all scheduled reboots
auto-reboot --delete-all
```

## Installation

```bash
# Install script and dependencies
auto-reboot --install

# Manual installation
sudo cp auto-reboot /usr/local/bin/
sudo chmod 770 /usr/local/bin/auto-reboot
sudo chown root:sudo /usr/local/bin/auto-reboot
```

## Requirements

- Linux with systemd
- Bash 4.0+
- systemd-run (systemd-container package)
- Membership in sudo group or root access

## Command Reference

### Basic Options

| Option | Description |
|--------|-------------|
| `-n, --dry-run` | Test mode without executing (default) |
| `-N, --not-dry-run` | Execute the reboot schedule |
| `-f, --force-reboot` | Force reboot regardless of conditions |
| `-h, --help` | Show help message |
| `-V, --version` | Show version |
| `-i, --install` | Install to /usr/local/bin |

### Scheduling Options

| Option | Description |
|--------|-------------|
| `-m, --max-uptime-days DAYS` | Max uptime before reboot (default: 14) |
| `-r, --reboot-time HH:MM` | Schedule time (default: 22:00) |
| `-a, --allowed-days DAYS` | Restrict to specific days |

### Schedule Management

| Option | Description |
|--------|-------------|
| `-l, --list` | Show all scheduled reboots |
| `-d, --delete TIMER` | Delete specific timer |
| `-D, --delete-all` | Delete all timers (with confirmation) |

## Day Specifications

The `--allowed-days` option accepts:
- Short names: `Sun`, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`
- Full names: `Sunday`, `Monday`, etc.
- Numbers: `0` (Sunday) through `6` (Saturday)
- Multiple: `Mon,Wed,Fri` or `1,3,5`

## Examples

### Basic Usage

```bash
# Check reboot status
auto-reboot
# Output:
# Host: server01
# Uptime: up 15 days, 3 hours
# Reboot-required: present
# Status: Reboot required
#   - Reason: System updates require reboot
#   - Reason: Uptime (15 days) exceeds maximum (14 days)
# Delay: 43200
# Scheduled: 2025-07-22 22:00:00 WITA
# auto-reboot: systemd-run: [DRY RUN] Reboot scheduled in 43200 seconds
# auto-reboot: [DRY RUN] Use 'auto-reboot' with option '-N' to execute

# Actually schedule the reboot
auto-reboot -N
```

### Weekend Maintenance

```bash
# Reboot only on weekends at 3 AM
auto-reboot --allowed-days Sat,Sun --reboot-time 03:00 -N

# Reboot Sunday night/Monday morning at 1 AM
auto-reboot --allowed-days Mon --reboot-time 01:00 -N
```

### Uptime Management

```bash
# Reboot if uptime exceeds 7 days
auto-reboot --max-uptime-days 7 -N

# Weekly reboot on Sunday at 4 AM if uptime > 7 days
auto-reboot -m 7 -r 04:00 -a Sun -N
```

### Schedule Management

```bash
# List all scheduled reboots
auto-reboot --list
# Output:
# Active auto-reboot schedules:
# =============================
# 1. auto-reboot-1753063354.timer - Scheduled: Mon 2025-07-21 22:00:00 WITA
# 2. auto-reboot-1753064000.timer - Scheduled: Sun 2025-07-28 03:00:00 WITA
# =============================
# Total: 2 scheduled reboot(s)

# Delete specific timer (using ID)
auto-reboot --delete 1753063354

# Delete all scheduled reboots
auto-reboot -D
# Output:
# Found 2 auto-reboot schedule(s):
# auto-reboot-1753063354.timer
# auto-reboot-1753064000.timer
# 
# Delete all schedules? [y/N] y
# auto-reboot: Deleting auto-reboot-1753063354.timer...
# auto-reboot: Successfully deleted auto-reboot-1753063354.timer
# auto-reboot: Deleting auto-reboot-1753064000.timer...
# auto-reboot: Successfully deleted auto-reboot-1753064000.timer
# auto-reboot: Deleted 2 auto-reboot schedule(s).
```

### Cron Integration

```bash
# Add to root's crontab
# Daily check at 11 PM, reboot on Sunday at 4 AM if needed
0 23 * * * /usr/local/bin/auto-reboot -m 14 -r 04:00 -a Sun -N

# Check every 6 hours, reboot anytime if uptime > 30 days
0 */6 * * * /usr/local/bin/auto-reboot -m 30 -N

# Weekly forced reboot on Sunday at 3 AM
0 2 * * 0 /usr/local/bin/auto-reboot -f -r 03:00 -N
```

### Emergency Scenarios

```bash
# Force immediate reboot (at next scheduled time)
auto-reboot --force-reboot -N

# Force reboot in 5 minutes (using custom time)
auto-reboot -f -r $(date -d "+5 minutes" +%H:%M) -N

# Cancel all pending reboots
auto-reboot --delete-all
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MACHINE_REBOOT_TIME` | Default reboot time | `22:00` |
| `MACHINE_UPTIME_MAXDAYS` | Default max uptime | `14` |

```bash
# Set defaults via environment
export MACHINE_REBOOT_TIME="03:00"
export MACHINE_UPTIME_MAXDAYS="7"
auto-reboot -N
```

## Scheduling Logic

1. **No day restrictions**: Schedules for today at specified time, or tomorrow if time has passed
2. **With day restrictions**: Finds next allowed day within 7 days
3. **Force reboot**: Ignores all conditions except time/day restrictions

## Logging

All reboot schedules and deletions are logged to syslog:

```bash
# View logs
sudo journalctl -t auto-reboot

# Example log entries:
# Jul 21 09:28:22 server01 auto-reboot: Scheduling system reboot in 46898s for user admin (uptime: 15d)
# Jul 21 09:28:34 server01 auto-reboot: Successfully scheduled reboot for 2025-07-21 22:30:12
# Jul 21 09:46:48 server01 auto-reboot: Deleted scheduled reboot timer: auto-reboot-1753061346.timer by user admin
```

## Safety Features

- **Dry run by default**: Prevents accidental reboots
- **Automatic sudo**: Elevates privileges when needed
- **Confirmation prompts**: For delete-all operations
- **Audit trail**: Syslog entries for all operations
- **Validation**: Comprehensive input checking
- **Timer persistence**: Survives system restarts

## Troubleshooting

```bash
# Verify systemd-run is available
which systemd-run || auto-reboot --install

# Check systemd status
systemctl is-system-running

# List all system timers (including auto-reboot)
systemctl list-timers --all | grep auto-reboot

# Check timer details
systemctl status auto-reboot-XXXXXX.timer

# View recent logs
journalctl -t auto-reboot --since "1 hour ago"
```

## Security

- Restricted to root and sudo group members
- File permissions: 770 (owner: root, group: sudo)
- All operations logged with username
- No sensitive data in logs

## License

GPL-3.0 - See [LICENSE](LICENSE) for details.

## Version

Current version: 1.0.422