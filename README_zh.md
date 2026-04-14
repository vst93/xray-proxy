# xray-proxy

轻量级 Linux 代理管理工具，基于 [Xray-core](https://github.com/XTLS/Xray-core)，自动解析 VLESS/Hysteria2 订阅生成配置。

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

# 2. 安装脚本
sudo cp scripts/* /usr/local/bin/
sudo chmod +x /usr/local/bin/proxy-*

# 3. 安装 systemd 服务
cp systemd/xray.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable xray

# 4. 配置订阅
export PROXY_SUB_URL="https://你的订阅地址"
echo "$PROXY_SUB_URL" > ~/.config/xray/subscription_url

# 5. 更新并启动
proxy-update
```

## 使用

```bash
proxy-update      # 更新订阅，生成配置，重启 xray
proxy-on          # 设置环境变量开启代理
proxy-off         # 取消环境变量关闭代理
proxy-status      # 查看代理状态和测试连接
proxy-switch      # 列出所有节点
proxy-switch 5    # 切换到第 5 个节点

# 管理服务
xray-status       # 查看 xray 服务状态
xray-restart      # 重启 xray
xray-log          # 实时查看日志
```

## 文件结构

```
scripts/
  proxy-update    # 更新订阅（下载 → 解码 → 生成配置 → 重启服务）
  proxy-switch    # 节点切换
  generate_config.py  # 订阅解析 + Xray 配置生成

systemd/
  xray.service    # systemd 用户服务

fish/
  proxy.fish      # fish shell 函数（proxy-on/off/status, xray-*）
```

## 支持的协议

| 协议 | 传输 | 状态 |
|------|------|------|
| VLESS + REALITY | TCP | ✅ 推荐 |
| VLESS + TLS | WebSocket | ⚠️ CDN 可能拦截 |
| Hysteria2 | UDP | ✅ (需 skip-cert-verify) |

## 与 mihomo/Clash 生态的区别

| | mihomo | xray-proxy |
|---|---|---|
| 配置格式 | YAML | JSON |
| VLESS REALITY | 有 bug | 原生支持 |
| 节点切换 | Clash API | 重写配置 + 重启 |
| Web Dashboard | YACD 等 | 无（CLI only） |
| 资源占用 | ~25MB | ~15MB |

## 类似项目

- [subconverter](https://github.com/tindy2013/subconverter) — 18.8k ⭐ 订阅格式转换（支持多客户端）
- [mihomo](https://github.com/MetaCubeX/mihomo) — 22.3k ⭐ Clash.Meta 核心
- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) — GUI 客户端，自带订阅管理
