# Fish shell proxy functions
# Usage: source this file in config.fish or copy functions individually

function proxy-on
    set -gx http_proxy http://127.0.0.1:7890
    set -gx https_proxy http://127.0.0.1:7890
    set -gx ALL_PROXY socks5://127.0.0.1:7890
    echo "✅ 代理已开启"
    echo "   http_proxy: $http_proxy"
    echo "   https_proxy: $https_proxy"
    echo "   ALL_PROXY: $ALL_PROXY"
end

function proxy-off
    set -e http_proxy
    set -e https_proxy
    set -e ALL_PROXY
    echo "❌ 代理已关闭"
end

function proxy-status
    echo "当前代理设置:"
    echo "  http_proxy: "(set -q http_proxy; and echo $http_proxy; or echo "未设置")
    echo "  https_proxy: "(set -q https_proxy; and echo $https_proxy; or echo "未设置")
    echo "  ALL_PROXY: "(set -q ALL_PROXY; and echo $ALL_PROXY; or echo "未设置")
    echo ""
    echo "Xray 服务状态:"
    if systemctl --user is-active xray >/dev/null 2>&1
        echo "  ✅ 运行中"
    else
        echo "  ❌ 未运行"
    end
    echo ""
    echo "测试连接:"
    set -l test_result (curl -x http://127.0.0.1:7890 -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://www.google.com/generate_204 2>/dev/null)
    if test "$test_result" = "204"
        echo "  ✅ 连接正常"
    else
        echo "  ⚠️ 连接失败 (状态码: $test_result)"
    end
end

function proxy-update
    bash ~/bin/proxy-update
end

function proxy-switch
    python3 ~/bin/proxy-switch $argv
end

function xray-status
    systemctl --user status xray --no-pager
end

function xray-restart
    systemctl --user restart xray
    echo "🔄 xray 服务已重启"
end

function xray-stop
    systemctl --user stop xray
    echo "❌ xray 服务已停止"
end

function xray-log
    journalctl --user -u xray -f
end
