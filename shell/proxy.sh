# xray-proxy shell functions for bash / zsh
# Sourced from ~/.bashrc, ~/.zshrc or /etc/profile.d/xray-proxy.sh
#
# proxy-on/proxy-off must be shell functions (not standalone executables),
# because they export environment variables into the *current* shell.

# 1) 清除历史遗留的同名 alias。
#    bash/zsh 中 alias 优先于函数，旧版 (mihomo 等) 留下的
#    alias proxy-on 会遮蔽这里的函数。
unalias proxy-on proxy-off proxy-status 2>/dev/null || true

# 2) 使用 `function name { }` 写法而不是 `name() { }`。
#    在交互式 shell 中，若已存在 `alias proxy-on=...`，
#    `proxy-on() {` 会在解析阶段被别名展开，导致整个文件语法错误、
#    后续函数全部无法加载。以 function 关键字开头可避免别名展开。
function proxy-on {
    export http_proxy="http://127.0.0.1:${XRAY_PROXY_HTTP_PORT:-7890}"
    export https_proxy="http://127.0.0.1:${XRAY_PROXY_HTTP_PORT:-7890}"
    export ALL_PROXY="socks5://127.0.0.1:${XRAY_PROXY_SOCKS_PORT:-7891}"
    export socks_proxy="socks5://127.0.0.1:${XRAY_PROXY_SOCKS_PORT:-7891}"
    echo "✅ 代理已开启"
    echo "   http_proxy: $http_proxy"
    echo "   https_proxy: $https_proxy"
    echo "   ALL_PROXY: $ALL_PROXY"
}

function proxy-off {
    unset http_proxy https_proxy ALL_PROXY socks_proxy
    echo "❌ 代理已关闭"
}

function proxy-status {
    echo "当前代理设置:"
    echo "  http_proxy: ${http_proxy:-未设置}"
    echo "  https_proxy: ${https_proxy:-未设置}"
    echo "  ALL_PROXY: ${ALL_PROXY:-未设置}"
    echo "  socks_proxy: ${socks_proxy:-未设置}"
    echo ""
    echo "Xray 服务状态:"
    if systemctl --user is-active xray >/dev/null 2>&1; then
        echo "  ✅ 运行中"
    else
        echo "  ❌ 未运行"
    fi
    echo ""
    echo "测试连接:"
    _xray_code=$(curl -x "http://127.0.0.1:${XRAY_PROXY_HTTP_PORT:-7890}" -s -o /dev/null \
        -w "%{http_code}" --connect-timeout 5 \
        https://www.google.com/generate_204 2>/dev/null)
    if [ "$_xray_code" = "204" ]; then
        echo "  ✅ 连接正常"
    else
        echo "  ⚠️ 连接失败 (状态码: ${_xray_code:-无响应})"
    fi
}

function xray-status {
    systemctl --user status xray --no-pager
}

function xray-restart {
    systemctl --user restart xray && echo "🔄 xray 服务已重启"
}

function xray-stop {
    systemctl --user stop xray && echo "❌ xray 服务已停止"
}

function xray-log {
    journalctl --user -u xray -f
}
