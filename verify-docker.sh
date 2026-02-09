#!/bin/bash

# MyStoryApp Docker 部署验证脚本
# 检查配置是否正确，以及环境是否就绪

set -e

echo "🧪 MyStoryApp Docker 部署验证"
echo "==============================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

checks_passed=0
checks_failed=0

# 检查函数
check_pass() {
    echo "✅ $1"
    ((checks_passed++)) || true
}

check_fail() {
    echo "❌ $1"
    ((checks_failed++)) || true
}

warning() {
    echo "⚠️  $1"
}

info() {
    echo "ℹ️  $1"
}

echo "📋 检查项目文件..."
echo "-------------------"

# 1. 检查必需文件
[ -f "docker-compose.yml" ] && check_pass "docker-compose.yml 存在" || check_fail "docker-compose.yml 缺失"
[ -f "docker-deploy.sh" ] && check_pass "docker-deploy.sh 存在" || check_fail "docker-deploy.sh 缺失"
[ -f "MyStoryAppBackend/Dockerfile" ] && check_pass "后端 Dockerfile 存在" || check_fail "后端 Dockerfile 缺失"
[ -f "MyStoryAppBackend/package.json" ] && check_pass "后端 package.json 存在" || check_fail "后端 package.json 缺失"

echo ""
echo "🐳 检查 Docker 环境..."
echo "-------------------"

# 2. 检查 Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
    check_pass "Docker 已安装: $DOCKER_VERSION"
    
    # 检查 Docker 守护进程
    if docker info &> /dev/null; then
        check_pass "Docker 守护进程运行中"
    else
        check_fail "Docker 守护进程未运行"
        warning "请启动 Docker Desktop 应用"
    fi
else
    check_fail "Docker 未安装"
    echo ""
    echo "安装 Docker Desktop:"
    echo "  brew install --cask docker"
    echo ""
    echo "或从官网下载: https://www.docker.com/products/docker-desktop"
fi

# 3. 检查 Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || echo "unknown")
    check_pass "Docker Compose 已安装: $COMPOSE_VERSION"
else
    check_fail "Docker Compose 未安装"
fi

echo ""
echo "⚙️ 检查配置..."
echo "-------------------"

# 4. 检查 .env 文件
if [ -f ".env" ]; then
    check_pass ".env 文件存在"
    
    # 检查 BAILIAN_API_KEY
    if grep -q "BAILIAN_API_KEY=" .env 2>/dev/null && ! grep -q "BAILIAN_API_KEY=your_" .env 2>/dev/null && ! grep -q "BAILIAN_API_KEY=$" .env 2>/dev/null; then
        KEY_VALUE=$(grep "BAILIAN_API_KEY=" .env 2>/dev/null | cut -d'=' -f2 | cut -c1-20)
        check_pass "BAILIAN_API_KEY 已配置: ${KEY_VALUE}..."
    else
        check_fail "BAILIAN_API_KEY 未正确配置"
        info "请编辑 .env 文件，填入有效的 API Key"
        info "获取地址: https://dashscope.aliyun.com/"
    fi
else
    check_fail ".env 文件不存在"
    info "运行: cp MyStoryAppBackend/.env.example .env"
    info "然后编辑 .env 填入你的 API Key"
fi

echo ""
echo "📦 检查后端依赖..."
echo "-------------------"

# 5. 检查 node_modules
if [ -d "MyStoryAppBackend/node_modules" ]; then
    check_pass "后端 node_modules 已安装"
else
    warning "后端 node_modules 未安装"
    info "Docker 构建时会自动安装"
fi

echo ""
echo "🔧 检查配置文件..."
echo "-------------------"

# 6. 验证 docker-compose.yml 语法
if command -v docker-compose &> /dev/null; then
    if docker-compose config > /dev/null 2>&1; then
        check_pass "docker-compose.yml 语法正确"
    else
        check_fail "docker-compose.yml 语法错误"
    fi
else
    warning "无法验证 docker-compose.yml（Docker Compose 未安装）"
fi

# 7. 检查端口占用
echo ""
echo "🌐 检查端口..."
echo "-------------------"

check_port() {
    if command -v lsof &> /dev/null && lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        warning "端口 $1 已被占用"
        info "占用进程: $(lsof -Pi :$1 -sTCP:LISTEN | tail -1 | awk '{print $1}')"
        ((checks_failed++)) || true
    else
        check_pass "端口 $1 可用"
    fi
}

check_port 3000
check_port 6379  
check_port 8080

echo ""
echo "📊 检查结果汇总"
echo "==================="
echo "✅ 通过: $checks_passed"
echo "❌ 失败: $checks_failed"
echo ""

if [ $checks_failed -eq 0 ]; then
    echo "🎉 所有检查通过！可以开始部署。"
    echo ""
    echo "启动命令:"
    echo "  ./docker-deploy.sh start"
    echo ""
    echo "或使用 Docker Compose 直接启动:"
    echo "  docker-compose up --build -d"
    exit 0
else
    echo "⚠️  有 $checks_failed 项检查失败，请先修复。"
    echo ""
    echo "常见问题:"
    echo "  1. Docker 未安装: brew install --cask docker"
    echo "  2. Docker 未启动: 打开 Docker Desktop 应用"
    echo "  3. 端口被占用: lsof -i :3000 然后 kill -9 <PID>"
    echo "  4. API Key 未配置: 编辑 .env 文件"
    exit 1
fi
