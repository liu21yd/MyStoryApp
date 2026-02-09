#!/bin/bash

# MyStoryApp 一键启动脚本
# 同时启动后端和前端预览

echo "🚀 Starting MyStoryApp Development Environment..."

# 检查必要工具
command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed."; exit 1; }
command -v redis-server >/dev/null 2>&1 || { echo "⚠️  Redis not found. Please install Redis."; }

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 启动 Redis（如果没有运行）
if ! pgrep -x "redis-server" > /dev/null; then
    echo "📦 Starting Redis..."
    redis-server --daemonize yes
fi

# 启动后端
echo "🔧 Starting Backend Server..."
cd "$SCRIPT_DIR/MyStoryAppBackend"

if [ ! -d "node_modules" ]; then
    echo "📥 Installing backend dependencies..."
    npm install
fi

if [ ! -f ".env" ]; then
    echo "⚠️  Please configure .env file from .env.example"
    cp .env.example .env
    echo "📝 Edit .env file with your API keys"
fi

npm run dev &
BACKEND_PID=$!

# 等待后端启动
sleep 3

# 打开预览页面
echo "🌐 Opening Preview..."
open "$SCRIPT_DIR/preview.html"

echo ""
echo "✅ Development environment started!"
echo "📱 Backend: http://localhost:3000"
echo "📖 API Docs: http://localhost:3000/api-docs"
echo ""
echo "Press Ctrl+C to stop all services"

# 捕获退出信号
trap "echo ''; echo '🛑 Stopping services...'; kill $BACKEND_PID 2>/dev/null; exit" INT

wait
