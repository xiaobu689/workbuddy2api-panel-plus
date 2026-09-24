#!/usr/bin/env bash
# 一键拉取部署脚本（参照 dogbot deploy.sh 风格，适配 workbuddy2api-panel-plus）
# 用法：在项目根目录下执行 ./deploy.sh
set -e
cd "$(dirname "$0")"

echo "==> 检查 config/config.json 是否存在"
if [ ! -f config/config.json ]; then
    echo "错误：找不到 config/config.json，请先根据 config.example.json 创建并填好真实配置："
    echo "  mkdir -p config auths data && cp config.example.json config/config.json"
    echo "  若容器以 uid 10001 运行且挂载目录属主不符，还需：sudo chown -R 10001:10001 config auths data"
    exit 1
fi

echo "==> 拉取最新代码"
export GIT_TERMINAL_PROMPT=0
if ! timeout 20 git pull origin main; then
    echo "错误：git pull 失败，可能原因："
    echo "  1. 网络无法访问 github.com（curl -v https://github.com 测试）"
    echo "  2. SSH key 认证失败（ssh -T git@github.com 测试）"
    echo "  3. 本地有未提交的修改与远程冲突"
    exit 1
fi

echo "==> 重新构建并启动容器"
docker compose up -d --build

echo "==> 等待服务启动"
for i in $(seq 1 15); do
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7863/healthz | grep -q "200"; then
        echo "==> 部署成功，服务运行正常"
        curl -s http://127.0.0.1:7863/healthz
        echo ""
        exit 0
    fi
    sleep 1
done
echo "==> 服务未能在预期时间内启动，最近日志如下："
docker compose logs --tail 50
exit 1
