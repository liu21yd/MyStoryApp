#!/bin/bash

# MyStoryApp Docker 部署脚本 (Python 后端)
# 一键启动所有服务

set -e  # 遇到错误立即退出

echo "🚀 MyStoryApp Docker 部署脚本 (Python 后端)"
echo "=============================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 检查命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 未安装${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ $1 已安装${NC}"
    return 0
}

# 启动服务
start_services() {
    echo -e "\n${BLUE}🔍 检查环境...${NC}"
    
    # 检查 Docker
    if ! check_command docker; then
        echo "请先安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! check_command docker-compose; then
        echo "请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查 .env
    if [ ! -f .env ]; then
        echo -e "${YELLOW}⚠️  未找到 .env 文件${NC}"
        echo "正在从 .env.example 创建..."
        
        if [ -f MyStoryAppBackendPy/.env.example ]; then
            cp MyStoryAppBackendPy/.env.example .env
        fi
        
        echo -e "${YELLOW}📝 请编辑 .env 文件，填入你的 BAILIAN_API_KEY${NC}"
        echo "   获取地址: https://dashscope.aliyun.com/"
        exit 1
    fi
    
    # 检查 BAILIAN_API_KEY
    if grep -q "BAILIAN_API_KEY=your_" .env 2>/dev/null || grep -q "BAILIAN_API_KEY=$" .env 2>/dev/null; then
        echo -e "${RED}❌ BAILIAN_API_KEY 未配置${NC}"
        echo "请编辑 .env 文件，填入有效的 API Key"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 环境检查通过${NC}"
    
    # 构建并启动
    echo -e "\n${BLUE}🐳 启动 Docker 服务...${NC}"
    docker-compose up --build -d
    
    echo -e "\n${BLUE}⏳ 等待服务启动...${NC}"
    
    # 等待后端健康检查通过
    for i in {1..30}; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 后端服务已就绪${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    echo ""
    echo -e "${GREEN}🎉 所有服务已启动！${NC}"
    echo ""
    echo "访问地址:"
    echo "  🌐 API 文档:     http://localhost:8000/docs"
    echo "  🧪 测试页面:     http://localhost:8080"
    echo "  📊 Flower 监控:  http://localhost:5555"
    echo "  🔧 后端 API:      http://localhost:8000"
    echo ""
    echo "管理命令:"
    echo "  ./docker-deploy.sh logs    # 查看日志"
    echo "  ./docker-deploy.sh status  # 查看状态"
    echo "  ./docker-deploy.sh stop    # 停止服务"
}

# 停止服务
stop_services() {
    echo -e "${BLUE}🛑 停止服务...${NC}"
    docker-compose down
    echo -e "${GREEN}✅ 服务已停止${NC}"
}

# 查看日志
show_logs() {
    echo -e "${BLUE}📋 查看日志 (按 Ctrl+C 退出)...${NC}"
    docker-compose logs -f
}

# 查看状态
show_status() {
    echo -e "${BLUE}📊 服务状态:${NC}"
    docker-compose ps
    
    echo -e "\n${BLUE}🔗 访问地址:${NC}"
    echo "  • API 文档:    http://localhost:8000/docs"
    echo "  • 测试页面:    http://localhost:8080"
    echo "  • Flower:      http://localhost:5555"
    echo "  • Redis:       localhost:6379"
    
    # 健康检查
    echo -e "\n${BLUE}🏥 健康检查:${NC}"
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Python 后端 API 正常${NC}"
    else
        echo -e "  ${RED}❌ Python 后端 API 异常${NC}"
    fi
    
    # Celery Worker 检查
    if docker ps | grep -q "mystoryapp-worker"; then
        echo -e "  ${GREEN}✅ Celery Worker 运行中${NC}"
    else
        echo -e "  ${RED}❌ Celery Worker 未运行${NC}"
    fi
}

# 重置数据
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

# 运行测试
run_tests() {
    echo -e "${BLUE}🧪 运行端到端测试...${NC}"
    
    if [ -f "test-docker-e2e.sh" ]; then
        ./test-docker-e2e.sh
    else
        echo -e "${YELLOW}⚠️  未找到测试脚本${NC}"
        echo "运行基础测试:"
        
        # 测试健康检查
        echo "1. 测试健康检查..."
        curl -s http://localhost:8000/health | python -m json.tool
        
        # 测试语音列表
        echo -e "\n2. 测试语音列表..."
        curl -s http://localhost:8000/api/v1/tts/voices | python -m json.tool
        
        echo -e "\n${GREEN}✅ 基础测试完成${NC}"
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
    test)
        run_tests
        ;;
    update)
        echo -e "${BLUE}🔄 更新服务...${NC}"
        docker-compose pull
        docker-compose up --build -d
        show_status
        ;;
    *)
        echo "使用方法: $0 [start|stop|restart|logs|status|reset|test|update]"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动所有服务（默认）"
        echo "  stop    - 停止所有服务"
        echo "  restart - 重启所有服务"
        echo "  logs    - 查看实时日志"
        echo "  status  - 查看服务状态"
        echo "  reset   - 重置所有数据（谨慎使用）"
        echo "  test    - 运行端到端测试"
        echo "  update  - 更新并重启服务"
        exit 1
        ;;
esac
