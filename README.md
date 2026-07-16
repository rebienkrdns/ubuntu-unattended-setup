# ubuntu-unattended-setup

Automated security updates and controlled weekly reboots for Ubuntu Server — configured in one command.

---

## Quick Install (defaults: Sundays at 5:30 AM, security only)

```bash
curl -fsSL https://github.com/rebienkrdns/ubuntu-unattended-setup/raw/main/setup-auto-updates.sh | sudo bash
```

---

## Usage

### Default — Sundays at 05:30 AM, security updates only

```bash
curl -fsSL https://github.com/rebienkrdns/ubuntu-unattended-setup/raw/main/setup-auto-updates.sh | sudo bash
```

### Custom day and time

```bash
curl -fsSL https://github.com/rebienkrdns/ubuntu-unattended-setup/raw/main/setup-auto-updates.sh \
  | sudo bash -s -- --day 0 --time 05:30
```

### With email notifications

```bash
curl -fsSL https://github.com/rebienkrdns/ubuntu-unattended-setup/raw/main/setup-auto-updates.sh \
  | sudo bash -s -- --day 0 --time 05:30 --email admin@yourserver.com
```

### Include all updates (not just security)

```bash
curl -fsSL https://github.com/rebienkrdns/ubuntu-unattended-setup/raw/main/setup-auto-updates.sh \
  | sudo bash -s -- --all --time 03:00
```

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-d`, `--day` | Day of week for reboot (`0`=Sun, `1`=Mon ... `6`=Sat) | `0` |
| `-t`, `--time` | Reboot time in `HH:MM` format | `05:30` |
| `-e`, `--email` | Email address for update notifications | *(disabled)* |
| `-a`, `--all` | Include all updates, not just security patches | *(security only)* |
| `-h`, `--help` | Show usage information | — |

---

## What it does

1. **Installs** `unattended-upgrades` and related packages
2. **Configures** `/etc/apt/apt.conf.d/50unattended-upgrades` — security-only, no automatic reboots
3. **Configures** `/etc/apt/apt.conf.d/20auto-upgrades` — daily package list refresh and upgrade download
4. **Creates** `/usr/local/bin/auto-reboot-if-needed.sh` — applies pending upgrades and reboots **only if `/var/run/reboot-required` exists**
5. **Installs** a cron job at `/etc/cron.d/auto-updates-reboot` with your chosen schedule
6. **Enables** the `unattended-upgrades` systemd service
7. **Runs** a `--dry-run` to validate the configuration

> ⚠️ The server will only reboot when a kernel or critical package actually requires it — never unconditionally.

---

## Files created on the server

| Path | Description |
|------|-------------|
| `/etc/apt/apt.conf.d/50unattended-upgrades` | Main upgrade policy |
| `/etc/apt/apt.conf.d/20auto-upgrades` | APT periodic schedule |
| `/usr/local/bin/auto-reboot-if-needed.sh` | Controlled reboot script |
| `/etc/cron.d/auto-updates-reboot` | Cron job for weekly maintenance |

---

## Useful commands after setup

```bash
# Check service status
sudo systemctl status unattended-upgrades

# View upgrade logs
sudo tail -f /var/log/unattended-upgrades/unattended-upgrades.log

# View reboot logs
sudo tail -f /var/log/auto-reboot.log

# Manually trigger upgrade + reboot check
sudo /usr/local/bin/auto-reboot-if-needed.sh

# Check if a reboot is currently pending
cat /var/run/reboot-required
```

---

## Requirements

- Ubuntu 20.04 LTS or later
- `sudo` / root access

---

## License

MIT
