#!/bin/bash
# The Deep Sea - 本地启动脚本
# 双击运行：自动找可用端口、启动本地服务器并用 Chrome 打开页面

cd "$(dirname "$0")"

# 1. 先检查本页面是否已在某个本地端口正常提供服务
check_alive() {
    curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$1/index.html" 2>/dev/null | grep -q "200"
}

# 2. 清理本脚本之前启动的残留 python 服务器（只清理服务于本目录的）
for old in $(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep "python3 -m http.server\|python.*http.server" | awk '{print $2}' | sort -u); do
    old_dir=$(lsof -a -p "$old" -d cwd -Fn 2>/dev/null | grep '^n' | head -1 | sed 's/^n//')
    if [ "$old_dir" = "$(pwd)" ]; then
        kill "$old" 2>/dev/null
        echo "已清理旧服务器进程 (PID $old)"
    fi
done
sleep 0.5

# 3. 自动挑选可用端口（8765 起，顺延最多 10 个）
PORT=8765
for p in $(seq 8765 8790); do
    if check_alive "$p"; then
        PORT="$p"
        echo "检测到已在运行的本地服务 (端口 $p)，直接使用"
        break
    fi
    if ! lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"
        break
    fi
done

# 4. 若端口未被占用，启动服务器
if ! check_alive "$PORT"; then
    echo "启动本地服务器 http://127.0.0.1:$PORT ..."
    nohup python3 -m http.server "$PORT" --bind 127.0.0.1 > /tmp/deepsea_server.log 2>&1 &
    for i in $(seq 1 25); do
        check_alive "$PORT" && break
        sleep 0.3
    done
fi

# 5. 用 Chrome 打开（直接打开应用页 deep-sea/，根 index.html 只做重定向兜底）
URL="http://127.0.0.1:$PORT/deep-sea/"
if [ -d "/Applications/Google Chrome.app" ]; then
    open -a "Google Chrome" "$URL"
else
    open "$URL"
fi

echo "已在 Chrome 打开: $URL"
echo "提示：若页面空白，请按 Cmd+Shift+R 强制刷新。停止服务: kill \$(lsof -ti :$PORT)"
