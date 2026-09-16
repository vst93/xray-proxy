#!/bin/bash
# install.sh - 安装 xray-proxy 到系统
set -e

echo "=== xray-proxy 安装 ==="

# 检查 xray
if ! command -v xray &>/dev/null; then
    echo "xray 未安装，尝试安装..."
    if command -v yay &>/dev/null; then
        yay -S --noconfirm xray-bin
    else
        echo "请手动安装 xray-core:"
        echo "  https://github.com/XTLS/Xray-core/releases"
        exit 1
    fi
fi
echo "✅ xray $(xray version | head -1)"

# 复制脚本
echo "安装脚本到 /usr/local/bin/..."
sudo cp scripts/proxy-update /usr/local/bin/
sudo cp scripts/proxy-switch /usr/local/bin/
sudo cp scripts/generate_config.py /usr/local/bin/
sudo chmod +x /usr/local/bin/proxy-{update,switch}

# 安装 systemd 服务
echo "安装 systemd 服务..."
mkdir -p ~/.config/systemd/user
cp systemd/xray.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable xray

# 配置订阅
CONFIG_DIR=~/.config/xray
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/subscription_url" ]; then
    echo ""
    echo "请输入订阅地址 (留空跳过):"
    read -r sub_url
    if [ -n "$sub_url" ]; then
        echo "$sub_url" > "$CONFIG_DIR/subscription_url"
    fi
fi

# 安装 fish 函数
if command -v fish &>/dev/null; then
    echo "安装 fish 函数..."
    # 注意: fish 只会自动加载 ~/.config/fish/functions/<函数名>.fish。
    # proxy.fish 里定义了 proxy-on/proxy-off/... 等多个函数，
    # 放到 functions/ 目录下会因为找不到名为 proxy 的函数而被整个忽略。
    # 因此安装到 conf.d/，启动时会被 source，所有函数都能注册。
    FISH_CONF_DIR=~/.config/fish/conf.d
    mkdir -p "$FISH_CONF_DIR"
    cp fish/proxy.fish "$FISH_CONF_DIR/xray-proxy.fish"
    # 清理旧版本误装的位置
    rm -f ~/.config/fish/functions/proxy.fish
    echo "✅ 已安装到 $FISH_CONF_DIR/xray-proxy.fish"
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "使用方法:"
echo "  proxy-update    # 更新订阅"
echo "  proxy-on        # 开启代理"
echo "  proxy-off       # 关闭代理"
echo "  proxy-switch    # 切换节点"
echo "  proxy-status    # 查看状态"
echo ""
if [ -f "$CONFIG_DIR/subscription_url" ]; then
    echo "运行 'proxy-update' 开始使用"
else
    echo "请先配置订阅: echo '订阅URL' > $CONFIG_DIR/subscription_url"
fi
