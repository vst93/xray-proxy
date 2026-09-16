#!/bin/bash
# install.sh - 安装 xray-proxy 到系统
set -e

echo "=== xray-proxy 安装 ==="

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo &>/dev/null; then
    SUDO="sudo"
else
    echo "⚠️  未检测到 sudo，且当前不是 root。系统级安装将回退到 ~/.local。"
    SUDO=""
    SKIP_SYSTEM=1
fi

# 检查 xray（缺失时警告但不中断，shell 函数仍会安装）
if ! command -v xray &>/dev/null; then
    echo "⚠️  未检测到 xray，尝试安装..."
    if command -v yay &>/dev/null; then
        yay -S --noconfirm xray-bin
    elif command -v pacman &>/dev/null; then
        $SUDO pacman -S --noconfirm xray
    elif command -v apt-get &>/dev/null; then
        $SUDO apt-get update -qq && $SUDO apt-get install -y xray
    elif command -v dnf &>/dev/null; then
        $SUDO dnf install -y xray
    else
        echo "⚠️  无法自动安装 xray-core，请手动安装后再运行 proxy-update:"
        echo "     https://github.com/XTLS/Xray-core/releases"
        echo "     (proxy-on / proxy-off 等 shell 函数仍会继续安装)"
    fi
fi
if command -v xray &>/dev/null; then
    echo "✅ xray $(xray version 2>/dev/null | head -1)"
fi

# 复制脚本
# 优先装到 /usr/local/bin；无 root/sudo 时回退到 ~/.local/bin（通常已在 PATH）
if [ -z "$SKIP_SYSTEM" ]; then
    echo "安装脚本到 /usr/local/bin/..."
    $SUDO cp scripts/proxy-update /usr/local/bin/
    $SUDO cp scripts/proxy-switch /usr/local/bin/
    $SUDO cp scripts/generate_config.py /usr/local/bin/
    $SUDO chmod +x /usr/local/bin/proxy-update /usr/local/bin/proxy-switch
else
    echo "安装脚本到 ~/.local/bin/..."
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    cp scripts/proxy-update "$BIN_DIR/"
    cp scripts/proxy-switch "$BIN_DIR/"
    cp scripts/generate_config.py "$BIN_DIR/"
    chmod +x "$BIN_DIR/proxy-update" "$BIN_DIR/proxy-switch"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo "⚠️  $BIN_DIR 不在 PATH 中，请将其加入 PATH" ;;
    esac
fi

# 安装 systemd 服务
echo "安装 systemd 服务..."
mkdir -p ~/.config/systemd/user
cp systemd/xray.service ~/.config/systemd/user/
if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable xray 2>/dev/null || true
fi

# 配置订阅
CONFIG_DIR="$HOME/.config/xray"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/subscription_url" ]; then
    if [ -n "$SUBSCRIPTION_URL" ]; then
        echo "$SUBSCRIPTION_URL" > "$CONFIG_DIR/subscription_url"
        echo "✅ 已从 SUBSCRIPTION_URL 环境变量写入订阅地址"
    else
        echo ""
        echo "请输入订阅地址 (留空跳过):"
        # stdin 不是终端（如 curl|bash）时 read 会失败，不能让它中止安装
        read -r sub_url || true
        if [ -n "$sub_url" ]; then
            echo "$sub_url" > "$CONFIG_DIR/subscription_url"
        fi
    fi
fi

# ---------------------------------------------------------------
# 安装 fish 函数
# ---------------------------------------------------------------
if command -v fish &>/dev/null; then
    echo "安装 fish 函数..."
    # 注意: fish 只会自动加载 ~/.config/fish/functions/<函数名>.fish。
    # proxy.fish 里定义了 proxy-on/proxy-off/... 等多个函数，
    # 放到 functions/ 目录下会因为找不到名为 proxy 的函数而被整个忽略。
    # 因此安装到 conf.d/，启动时会被 source，所有函数都能注册。
    FISH_CONF_DIR="$HOME/.config/fish/conf.d"
    mkdir -p "$FISH_CONF_DIR"
    cp fish/proxy.fish "$FISH_CONF_DIR/xray-proxy.fish"
    rm -f "$HOME/.config/fish/functions/proxy.fish"
    echo "✅ 已安装到 $FISH_CONF_DIR/xray-proxy.fish"
fi

# ---------------------------------------------------------------
# 安装 bash/zsh shell 函数
#
# proxy-on / proxy-off 必须定义为 shell 函数，不能用独立可执行文件，
# 因为它们需要 export 环境变量到「当前」shell。
# 原安装脚本只在检测到 fish 时才安装这些命令，导致 bash/zsh 用户
# 出现 "proxy-on: command not found"。
# ---------------------------------------------------------------
SHELL_HELPERS="$PWD/shell/proxy.sh"
if [ -f "$SHELL_HELPERS" ]; then
    SOURCE_LINE='[ -f "$HOME/.local/share/xray-proxy/proxy.sh" ] && . "$HOME/.local/share/xray-proxy/proxy.sh"'

    # 1) 系统级：所有用户、login shell 可用
    if [ -z "$SKIP_SYSTEM" ]; then
        $SUDO mkdir -p /usr/local/share/xray-proxy
        $SUDO cp "$SHELL_HELPERS" /usr/local/share/xray-proxy/proxy.sh
        $SUDO chmod 644 /usr/local/share/xray-proxy/proxy.sh

        if [ -d /etc/profile.d ]; then
            echo '[ -f /usr/local/share/xray-proxy/proxy.sh ] && . /usr/local/share/xray-proxy/proxy.sh' \
                | $SUDO tee /etc/profile.d/xray-proxy.sh >/dev/null
            $SUDO chmod 644 /etc/profile.d/xray-proxy.sh
            echo "✅ 已安装 /etc/profile.d/xray-proxy.sh (login shell 生效)"
        fi
    fi

    # 2) 用户级：非 login 的交互式 shell（桌面终端）也能用
    HELPER_DEST="$HOME/.local/share/xray-proxy/proxy.sh"
    mkdir -p "$HOME/.local/share/xray-proxy"
    cp "$SHELL_HELPERS" "$HELPER_DEST"

    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        case "$rc" in
            *bashrc) command -v bash &>/dev/null || continue ;;
            *.zshrc) command -v zsh  &>/dev/null || continue ;;
        esac

        # 清理旧版残留的同名 alias（mihomo 等），
        # 它们优先于函数，会遮蔽 xray-proxy 提供的命令。
        if [ -f "$rc" ] && grep -qE '^[[:space:]]*alias[[:space:]]+(proxy-on|proxy-off|proxy-status)=' "$rc"; then
            cp "$rc" "${rc}.bak-xray-proxy"
            sed -i -E '/^[[:space:]]*alias[[:space:]]+(proxy-on|proxy-off|proxy-status)=/d' "$rc"
            echo "✅ 已从 $rc 移除旧的 proxy-* alias (备份: ${rc}.bak-xray-proxy)"
        fi

        # 规范化：先删除所有旧的 xray-proxy 标记/ source 行，最后统一追加一次，
        # 保证多次安装不会累加重复行。
        if [ -f "$rc" ]; then
            sed -i -e '/^# xray-proxy$/d' -e '\#xray-proxy/proxy\.sh#d' "$rc"
            printf '# xray-proxy\n%s\n' "$SOURCE_LINE" >> "$rc"
            echo "✅ $rc 已配置 xray-proxy"
        elif [ "$rc" = "$HOME/.bashrc" ]; then
            printf '# xray-proxy\n%s\n' "$SOURCE_LINE" >> "$rc"
            echo "✅ 已创建并写入 $rc"
        fi
    done
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
echo ""
echo "⚠️  proxy-on / proxy-off / proxy-status / xray-* 是 shell 函数，"
echo "    需要让当前终端重新加载配置后才会生效:"
echo "      source ~/.bashrc        # bash (zsh 用 source ~/.zshrc)"
echo "    或者直接重新打开一个终端。"
