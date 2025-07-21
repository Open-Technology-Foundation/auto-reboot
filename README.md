# auto-reboot

A bash script for intelligent system reboots with flexible scheduling and day-of-week restrictions.

**Version:** 1.0.422

## Overview

`auto-reboot` automatically reboots systems when:
- `/var/run/reboot-required` exists (indicating pending updates)
- System uptime exceeds a configurable maximum (default: 14 days)
- Force reboot is requested

The script uses systemd-run for reliable scheduling and supports flexible time and day-of-week restrictions.

## Features

- **Intelligent Scheduling**: Uses systemd timers for precise, reliable reboot scheduling
- **Day-of-Week Restrictions**: Limit reboots to specific days (e.g., only weekends)
- **Flexible Time Configuration**: Schedule reboots at any time in HH:MM format
- **Multiple Trigger Conditions**: Reboot on system updates, uptime threshold, or force
- **Dry Run Mode**: Safe testing mode enabled by default
- **Comprehensive Validation**: Input validation for all parameters
- **Self-Installation**: Built-in installation capability with dependency management
- **Version Information**: Track script version with `-V` option

## Requirements

- Linux system with systemd (required for scheduling)
- Bash 4.0+
- Root privileges for actual reboots
- `systemd-run` command (provided by systemd-container package)
- systemd must be running

## Installation

```bash
# Quick install with automatic dependency resolution
sudo auto-reboot --install

# Or manual installation
sudo cp auto-reboot /usr/local/bin/
sudo chmod +x /usr/local/bin/auto-reboot
```

## Usage

```bash
# Basic usage - dry run mode (default)
auto-reboot

# Execute reboot if conditions are met
auto-reboot -N

# Force reboot regardless of conditions
auto-reboot --force-reboot -N

# Schedule reboot only on weekends at 4 AM, max uptime 7 days
auto-reboot --max-uptime-days 7 --reboot-time 04:00 --allowed-days Sat,Sun -N

# Multiple allowed days using different formats
auto-reboot --allowed-days Mon,Wed,Fri -N       # Short names
auto-reboot --allowed-days 0,6 -N               # Numeric (0=Sunday)
auto-reboot --allowed-days Sunday,Saturday -N   # Full names

# Check version
auto-reboot --version
```

## Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--dry-run` | `-n` | Dry run only (default) |
| `--not-dry-run` | `-N` | Execute the reboot |
| `--force-reboot` | `-f` | Unconditional reboot |
| `--max-uptime-days DAYS` | `-m` | Maximum uptime before forced reboot (default: 14) |
| `--reboot-time HH:MM` | `-r` | Time to schedule reboot (default: 22:00) |
| `--allowed-days DAYS` | `-a` | Restrict reboots to specific weekdays |
| `--install` | `-i` | Install script and dependencies |
| `--version` | `-V` | Show version information |

### Day Formats

The `--allowed-days` option accepts multiple formats:

- **Short names**: `Sun`, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`
- **Full names**: `Sunday`, `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Friday`, `Saturday`
- **Numeric**: `0` (Sunday) through `6` (Saturday)
- **Multiple days**: Comma-separated list (e.g., `Mon,Wed,Fri` or `0,6`)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MACHINE_REBOOT_TIME` | Default reboot time in HH:MM format | `22:00` |
| `MACHINE_UPTIME_MAXDAYS` | Default maximum uptime in days | `14` |

Command line options override environment variables when specified.

## Scheduling Logic

1. **No day restrictions**: Schedule for today at specified time, or tomorrow if time has passed
2. **With day restrictions**: Find the next occurrence of an allowed day at the specified time
3. **Multiple allowed days**: Choose the earliest upcoming allowed day

## Examples

### Cron Integration
```bash
# Check daily at 23:15, reboot only on Sundays at 04:05 if uptime > 14 days
15 23 * * * root /usr/local/bin/auto-reboot --max-uptime-days 14 --reboot-time 04:05 --allowed-days Sun -N
```

### Weekly Maintenance Windows
```bash
# Allow reboots only during weekend maintenance windows
auto-reboot --allowed-days Sat,Sun --reboot-time 02:00 -N
```

### Emergency Updates
```bash
# Force immediate reboot (scheduled for next occurrence of allowed time)
auto-reboot --force-reboot --reboot-time 23:00 --allowed-days Mon,Tue,Wed,Thu,Fri -N
```

## Cron Configuration

For automated checks, add to root's crontab:

```bash
# Check daily at 23:15
15 23 * * * /usr/local/bin/auto-reboot -N
```

## Safety Features

- **Dry run by default**: Always test with dry run before execution
- **Clear scheduling output**: Shows exactly when reboot will occur
- **Systemd integration**: Uses reliable systemd timers instead of fragile background processes
- **Input validation**: Validates all time formats and day specifications
- **Error handling**: Clear error messages for invalid inputs

## Output Examples

```bash
$ auto-reboot --version
auto-reboot 1.0.422

$ auto-reboot --max-uptime-days 7 --allowed-days Sun --dry-run
Reboot required for [hostname]
  Reason: Uptime (8 days) exceeds maximum (7 days)
  Scheduled for: 2024-12-22 22:00:00 UTC
auto-reboot: systemd-run: [DRY RUN] Reboot scheduled in 234567 seconds
auto-reboot: [DRY RUN] Use 'auto-reboot -N' to execute
```

## License

GPL-3. See [LICENSE](LICENSE).

