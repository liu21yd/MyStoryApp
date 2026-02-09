#!/bin/bash

# MyStoryApp Docker 部署脚本
# 一键启动所有服务

set -e  # 遇到错误立即退出

echo "🚀 MyStoryApp Docker 部署脚本"
echo "=============================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    echo "请先安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装${NC}"
    echo "请先安装 Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✅ Docker 和 Docker Compose 已安装${NC}"

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 检查 .env 文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  未找到 .env 文件${NC}"
    echo "正在从 .env.example 创建..."
    
    if [ -f MyStoryAppBackend/.env.example ]; then
        cp MyStoryAppBackend/.env.example .env
    else
        cat > .env << 'EOF'
# MyStoryApp Docker 环境配置

# 百炼 API Key (必填)
# 获取地址: https://dashscope.aliyun.com/
BAILIAN_API_KEY=your_bailian_api_key_here

# 可选配置
NODE_ENV=production
LOG_LEVEL=info
EOF
    fi
    
    echo -e "${YELLOW}📝 请编辑 .env 文件，填入你的 BAILIAN_API_KEY${NC}"
    echo "   获取地址: https://dashscope.aliyun.com/"
    exit 1
fi

# 检查 BAILIAN_API_KEY
if grep -q "BAILIAN_API_KEY=your_" .env || grep -q "BAILIAN_API_KEY=$" .env; then
    echo -e "${RED}❌ BAILIAN_API_KEY 未配置${NC}"
    echo "请编辑 .env 文件，填入有效的 API Key"
    exit 1
fi

echo -e "${GREEN}✅ 环境配置检查通过${NC}"

# 函数：启动服务
start_services() {
    echo -e "\n${BLUE}🐳 启动 Docker 服务...${NC}"
    
    # 构建并启动
    docker-compose up --build -d
    
    echo -e "\n${BLUE}⏳ 等待服务启动...${NC}"
    
    # 等待后端健康检查通过
    for i in {1..30}; do
        if curl -s http://localhost:3000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 后端服务已就绪${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    echo -e "\n${GREEN}🎉 所有服务已启动！${NC}"
}

# 函数：停止服务
stop_services() {
    echo -e "${BLUE}🛑 停止服务...${NC}"
    docker-compose down
    echo -e "${GREEN}✅ 服务已停止${NC}"
}

# 函数：查看日志
show_logs() {
    echo -e "${BLUE}📋 查看日志 (按 Ctrl+C 退出)...${NC}"
    docker-compose logs -f
}

# 函数：查看状态
show_status() {
    echo -e "${BLUE}📊 服务状态:${NC}"
    docker-compose ps
    
    echo -e "\n${BLUE}🔗 访问地址:${NC}"
    echo "  • API 文档:    http://localhost:3000"
    echo "  • 测试页面:    http://localhost:8080"
    echo "  • Redis:       localhost:6379"
    
    # 健康检查
    echo -e "\n${BLUE}🏥 健康检查:${NC}"
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ 后端 API 正常${NC}"
    else
        echo -e "  ${RED}❌ 后端 API 异常${NC}"
    fi
}

# 函数：重置数据
reset_data() {
    echo -e "${YELLOW}⚠️  警告：这将删除所有数据！${NC}"
    read -p "确定要继续吗？(yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo -e "${BLUE}🗑️  删除数据卷...${NC}"
        docker-compose down -v
        echo -e "${GREEN}✅ 数据已重置${NC}"
    else
        echo "已取消"
    fi
}

# 主菜单
case "${1:-start}" in
    start)
        start_services
        show_status
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        show_status
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    reset)
        reset_data
        ;;
    update)
        echo -e "${BLUE}🔄 更新服务...${NC}"
        docker-compose pull
        docker-compose up --build -d
        show_status
        ;;
    *)
        echo "使用方法: $0 [start|stop|restart|logs|status|reset|update]"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动所有服务（默认）"
        echo "  stop    - 停止所有服务"
        echo "  restart - 重启所有服务"
        echo "  logs    - 查看实时日志"
        echo "  status  - 查看服务状态"
        echo "  reset   - 重置所有数据（谨慎使用）"
        echo "  update  - 更新并重启服务"
        exit 1
        ;;
esac
