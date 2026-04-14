#!/usr/bin/env python3
"""
Xray 配置生成器
用法: generate_config.py [decoded_nodes.txt]

从 VLESS/Hysteria2 节点列表生成 Xray JSON 配置。
支持协议: VLESS+REALITY, VLESS+WS+TLS, Hysteria2
"""
import json, os, sys
from urllib.parse import unquote, parse_qs

CONFIG_DIR = os.path.expanduser("~/.config/xray")
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")


def parse_nodes(text):
    """解析节点链接列表"""
    nodes = []
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        proto = line.split('://')[0]
        try:
            name = unquote(line.split('#', 1)[-1])
        except Exception:
            name = "unnamed"

        if proto == 'vless':
            p = line.replace('vless://', '').split('#')[0]
            if '@' not in p:
                continue
            auth, rest = p.split('@', 1)
            sp, qs = (rest.split('?', 1) + [''])[:2]
            server, port = (sp.rsplit(':', 1) + ['443'])[:2] if ':' in sp else (sp, '443')
            port = port.split('/')[0]
            pm = {k: v[0] for k, v in parse_qs(qs).items()}
            nodes.append(dict(
                name=name, type='vless', server=server, port=int(port),
                uuid=auth, sec=pm.get('security', 'tls'),
                net=pm.get('type', 'tcp'), sni=pm.get('sni', ''),
                fp=pm.get('fp', 'chrome'), pbk=pm.get('pbk', ''),
                sid=pm.get('sid', ''), flow=pm.get('flow', ''),
                path=unquote(pm.get('path', '')),
                host=pm.get('host', ''),
            ))

        elif proto == 'hysteria2':
            p = line.replace('hysteria2://', '').split('#')[0]
            if '@' not in p:
                continue
            auth, rest = p.split('@', 1)
            sp = rest.split('?')[0].split('/')[0]
            server, port = (sp.rsplit(':', 1) + ['443'])[:2] if ':' in sp else (sp, '443')
            qs = rest.split('?', 1)[1] if '?' in rest else ''
            pm = {k: v[0] for k, v in parse_qs(qs).items()}
            nodes.append(dict(
                name=name, type='hysteria2', server=server,
                port=int(port), pwd=auth, sni=pm.get('sni', ''),
            ))

    return nodes


def build_config(nodes):
    """生成 Xray 配置"""
    outbounds = [
        {"tag": "direct", "protocol": "freedom"},
        {"tag": "block", "protocol": "blackhole"},
    ]

    for n in nodes:
        if n['type'] == 'vless' and n['sec'] == 'reality':
            outbounds.append({
                "tag": n['name'], "protocol": "vless",
                "settings": {"vnext": [{
                    "address": n['server'], "port": n['port'],
                    "users": [{"id": n['uuid'], "encryption": "none",
                               "flow": n['flow']}]
                }]},
                "streamSettings": {
                    "network": "tcp", "security": "reality",
                    "realitySettings": {
                        "fingerprint": n['fp'] or "chrome",
                        "serverName": n['sni'],
                        "publicKey": n['pbk'],
                        "shortId": n['sid'],
                    }
                }
            })

        elif n['type'] == 'vless' and n['sec'] == 'tls':
            ws = {"path": n['path']}
            if n['host']:
                ws["host"] = n['host']
            outbounds.append({
                "tag": n['name'], "protocol": "vless",
                "settings": {"vnext": [{
                    "address": n['server'], "port": n['port'],
                    "users": [{"id": n['uuid'], "encryption": "none"}]
                }]},
                "streamSettings": {
                    "network": "ws", "security": "tls",
                    "tlsSettings": {
                        "fingerprint": n['fp'] or "chrome",
                        "allowInsecure": True,
                    },
                    "wsSettings": ws,
                }
            })

    # 默认使用第一个 REALITY 节点作为 proxy 出口
    reality = [o for o in outbounds
               if o.get('streamSettings', {}).get('security') == 'reality']
    if reality:
        reality[0]['tag'] = 'proxy'
    elif len(outbounds) > 2:
        outbounds[2]['tag'] = 'proxy'

    return {
        "log": {"loglevel": "warning"},
        "inbounds": [
            {"tag": "http", "port": 7890, "listen": "127.0.0.1",
             "protocol": "http"},
            {"tag": "socks", "port": 7891, "listen": "127.0.0.1",
             "protocol": "socks", "settings": {"udp": True}},
        ],
        "outbounds": outbounds,
        "routing": {
            "domainStrategy": "AsIs",
            "rules": [
                {"type": "field", "outboundTag": "direct",
                 "ip": ["geoip:private", "geoip:cn"]},
                {"type": "field", "outboundTag": "direct",
                 "domain": ["geosite:cn"]},
                {"type": "field", "outboundTag": "proxy",
                 "network": "tcp,udp"},
            ],
        },
    }


def main():
    decoded_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/decoded_nodes.txt"

    with open(decoded_file, encoding="utf-8") as f:
        text = f.read()

    nodes = parse_nodes(text)
    config = build_config(nodes)

    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

    count = len([n for n in nodes if n['type'] == 'vless'])
    print(f"OK: {count} proxy nodes -> {CONFIG_PATH}")


if __name__ == "__main__":
    main()
