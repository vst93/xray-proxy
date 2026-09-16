# xray-proxy

Lightweight Linux proxy manager based on [Xray-core](https://github.com/XTLS/Xray-core). Parses VLESS/Hysteria2 subscription URLs and generates Xray config automatically.

[中文文档](README_zh.md)

## Why not mihomo?

mihomo (Clash.Meta) v1.19.19 compiled with Go 1.25.6 has compatibility issues with some proxy providers:

- **VLESS CDN nodes** (WS+TLS) → Cloudflare returns 403
- **VLESS REALITY nodes** → `skip-cert-verify` not effective for REALITY
- **Hysteria2 nodes** → Go 1.25.6 rejects certs with only CN (no SAN)

Xray-core 25.3.6 (Go 1.24.1) is the reference implementation for VLESS REALITY and works perfectly.

## Installation

Requirements: `python3` (3.6+), `curl`, `systemd --user`.

```bash
# 1. Install xray-core
# Arch Linux:
yay -S xray-bin
# Or manually:
curl -L -o /tmp/xray.zip https://ghfast.top/https://github.com/XTLS/Xray-core/releases/download/v25.3.6/Xray-linux-64.zip
sudo unzip /tmp/xray.zip -d /usr/local/bin/ xray geoip.dat geosite.dat

# 2. Clone and install
git clone https://github.com/vst93/xray-proxy.git
cd xray-proxy
./install.sh

# 3. Set subscription URL
echo "https://your-subscription-url" > ~/.config/xray/subscription_url

# 4. Reload your shell (so proxy-on/proxy-off become available)
source ~/.bashrc        # bash  (zsh: source ~/.zshrc)

# 5. Update and start
proxy-update
```

## Commands

| Command | Type | Description |
|---------|------|-------------|
| `proxy-update` | executable | Download subscription, generate config, restart xray |
| `proxy-on` | shell function | Set proxy env vars (http_proxy, ALL_PROXY) |
| `proxy-off` | shell function | Unset proxy env vars |
| `proxy-status` | shell function | Show proxy status and test connectivity |
| `proxy-switch` | executable | List all available nodes |
| `proxy-switch 5` | executable | Switch to node #5 |
| `xray-status` | shell function | Show xray service status |
| `xray-restart` | shell function | Restart xray service |
| `xray-log` | shell function | Tail xray logs |

> **Note:** `proxy-on` / `proxy-off` / `proxy-status` / `xray-*` are shell
> functions for bash, zsh and fish, because they must modify the *current*
> shell's environment. After running `install.sh`, reload your shell
> (`source ~/.bashrc`, or open a new terminal) before using them.

## Supported Protocols

| Protocol | Transport | Status |
|----------|-----------|--------|
| VLESS + REALITY | TCP | ✅ Recommended |
| VLESS + TLS | WebSocket | ⚠️ CDN may block |
| Hysteria2 | UDP | ✅ (skip-cert-verify) |

## File Structure

```
scripts/
  proxy-update          # Subscription updater
  proxy-switch          # Node switcher
  generate_config.py    # Subscription parser → Xray JSON

systemd/
  xray.service          # Systemd user service

shell/
  proxy.sh              # bash / zsh shell functions

fish/
  proxy.fish            # Fish shell functions
```

## Configuration

- Subscription URL: `~/.config/xray/subscription_url`
- Generated config: `~/.config/xray/config.json`
- Backups: `~/.config/xray/backups/`

## Requirements

- Python 3.6 or newer (scripts avoid 3.7+ only APIs such as
  `subprocess.run(capture_output=..., text=...)` so they work on
  CentOS 7 / older distros).
- `curl`
- `systemd` with user services (`systemctl --user`)

## Comparison with mihomo/Clash ecosystem

| | mihomo | xray-proxy |
|---|---|---|
| Config format | YAML | JSON |
| VLESS REALITY | Buggy | Native |
| Node switching | Clash API | Rewrite config + restart |
| Web Dashboard | YACD etc. | None (CLI only) |
| Memory usage | ~25MB | ~15MB |

## Related Projects

- [subconverter](https://github.com/tindy2013/subconverter) — 18.8k ⭐ Subscription format converter
- [mihomo](https://github.com/MetaCubeX/mihomo) — 22.3k ⭐ Clash.Meta core
- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) — GUI client with built-in subscription management

## License

MIT
