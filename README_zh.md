# xray-proxy

轻量级 Linux 代理管理工具，基于 [Xray-core](https://github.com/XTLS/Xray-core)，自动解析 VLESS/Hysteria2 订阅生成配置。

[English](README.md)

## 为什么不用 mihomo？

mihomo (Clash.Meta) v1.19.19 用 Go 1.25.6 编译，对部分机场协议有兼容问题：
- VLESS CDN 节点 (WS+TLS) → Cloudflare CDN 返回 403
- VLESS REALITY 节点 → `skip-cert-verify` 对 REALITY 不生效
- Hysteria2 节点 → Go 1.25.6 拒绝只有 CN 没有 SAN 的旧证书

Xray-core 25.3.6 (Go 1.24.1) 是 VLESS REALITY 的原生实现，完美兼容。

## 安装

```bash
# 1. 安装 xray-core
# Arch Linux:
yay -S xray-bin
# 或手动下载:
curl -L -o /tmp/xray.zip https://ghfast.top/https://github.com/XTLS/Xray-core/releases/download/v25.3.6/Xray-linux-64.zip
sudo unzip /tmp/xray.zip -d /usr/local/bin/ xray geoip.dat geosite.dat

# 2. 克隆并安装
git clone https://github.com/vst93/xray-proxy.git
cd xray-proxy
./install.sh

# 3. 配置订阅地址
echo "https://你的订阅地址" > ~/.config/xray/subscription_url

# 4. 重新加载 shell（让 proxy-on/proxy-off 生效）
source ~/.bashrc        # bash  （zsh 用 source ~/.zshrc）

# 5. 更新并启动
proxy-update
```

## 命令

| 命令 | 类型 | 说明 |
|------|------|------|
| `proxy-update` | 可执行文件 | 更新订阅，生成配置，重启 xray |
| `proxy-on` | shell 函数 | 设置代理环境变量 |
| `proxy-off` | shell 函数 | 取消代理环境变量 |
| `proxy-status` | shell 函数 | 查看代理状态和测试连接 |
| `proxy-switch` | 可执行文件 | 列出所有节点 |
| `proxy-switch 5` | 可执行文件 | 切换到第 5 个节点 |
| `xray-status` | shell 函数 | 查看 xray 服务状态 |
| `xray-restart` | shell 函数 | 重启 xray 服务 |
| `xray-log` | shell 函数 | 实时查看日志 |

> **注意：** `proxy-on` / `proxy-off` / `proxy-status` / `xray-*` 是
> bash / zsh / fish 的 shell 函数（需要修改「当前」shell 的环境变量）。
> 运行 `install.sh` 后需重新加载配置（`source ~/.bashrc` 或重开终端）才能使用。

## 支持的协议

| 协议 | 传输 | 状态 |
|------|------|------|
| VLESS + REALITY | TCP | ✅ 推荐 |
| VLESS + TLS | WebSocket | ⚠️ CDN 可能拦截 |
| Hysteria2 | UDP | ✅ (需 skip-cert-verify) |

## 文件结构

```
scripts/
  proxy-update          # 更新订阅
  proxy-switch          # 节点切换
  generate_config.py    # 订阅解析 → Xray JSON

systemd/
  xray.service          # systemd 用户服务

shell/
  proxy.sh              # bash / zsh shell 函数

fish/
  proxy.fish            # fish shell 函数
```

## 配置文件

- 订阅地址：`~/.config/xray/subscription_url`
- 生成配置：`~/.config/xray/config.json`
- 备份目录：`~/.config/xray/backups/`

## 与 mihomo/Clash 生态的区别

| | mihomo | xray-proxy |
|---|---|---|
| 配置格式 | YAML | JSON |
| VLESS REALITY | 有 bug | 原生支持 |
| 节点切换 | Clash API | 重写配置 + 重启 |
| Web Dashboard | YACD 等 | 无（CLI only） |
| 资源占用 | ~25MB | ~15MB |

## 类似项目

- [subconverter](https://github.com/tindy2013/subconverter) — 18.8k ⭐ 订阅格式转换
- [mihomo](https://github.com/MetaCubeX/mihomo) — 22.3k ⭐ Clash.Meta 核心
- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) — GUI 客户端，自带订阅管理

## License

MIT
