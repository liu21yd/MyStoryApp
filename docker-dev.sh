#!/bin/bash

# MyStoryApp 开发环境 Docker 脚本
# 快速启动开发环境

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🛠️ MyStoryApp 开发环境"
echo "======================"

# 检查命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 未安装"
        return 1
    fi
    echo "✅ $1 已安装"
    return 0
}

# 启动开发环境
start_dev() {
    echo -e "\n📦 启动 Redis..."
    
    # 检查 Redis 容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -q "^mystoryapp-dev-redis$"; then
        echo "Redis 容器已存在，正在启动..."
        docker start mystoryapp-dev-redis
    else
        echo "创建 Redis 容器..."
        docker run -d \
            --name mystoryapp-dev-redis \
            -p 6379:6379 \
            -v mystoryapp-dev-redis:/data \
            redis:7-alpine \
            redis-server --appendonly yes
    fi
    
    echo -e "\n✅ Redis 已启动: redis://localhost:6379"
    
    # 检查后端依赖
    if [ ! -d "MyStoryAppBackend/node_modules" ]; then
        echo -e "\n📥 安装后端依赖..."
        cd MyStoryAppBackend
        npm install
        cd ..
    fi
    
    # 检查 .env
    if [ ! -f "MyStoryAppBackend/.env" ]; then
        echo -e "\n⚠️  未找到 .env 文件"
        if [ -f "MyStoryAppBackend/.env.example" ]; then
            cp MyStoryAppBackend/.env.example MyStoryAppBackend/.env
            echo "已创建 .env，请编辑并填入 BAILIAN_API_KEY"
        fi
    fi
    
    echo -e "\n🚀 启动后端服务..."
    echo "运行: cd MyStoryAppBackend && npm run dev"
    echo ""
    echo "其他终端命令:"
    echo "  查看 Redis: docker exec -it mystoryapp-dev-redis redis-cli"
    echo "  停止 Redis: docker stop mystoryapp-dev-redis"
    echo "  删除 Redis: docker rm mystoryapp-dev-redis"
}

# 停止开发环境
stop_dev() {
    echo "🛑 停止开发环境..."
    docker stop mystoryapp-dev-redis 2>/dev/null || true
    echo "✅ Redis 已停止"
}

# 重置开发环境
reset_dev() {
    echo "🗑️  重置开发环境..."
    docker stop mystoryapp-dev-redis 2>/dev/null || true
    docker rm mystoryapp-dev-redis 2>/dev/null || true
    docker volume rm mystoryapp-dev-redis 2>/dev/null || true
    echo "✅ 开发环境已重置"
}

# 主命令
case "${1:-start}" in
    start)
        start_dev
        ;;
    stop)
        stop_dev
        ;;
    restart)
        stop_dev
        sleep 1
        start_dev
        ;;
    reset)
        reset_dev
        ;;
    *)
        echo "使用方法: $0 [start|stop|restart|reset]"
        echo ""
        echo "命令:"
        echo "  start   - 启动 Redis 并准备开发环境"
        echo "  stop    - 停止 Redis"
        echo "  restart - 重启 Redis"
        echo "  reset   - 重置 Redis 数据"
        exit 1
        ;;
esac
