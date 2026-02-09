#!/bin/bash

# MyStoryApp Docker 端到端测试脚本
# 测试完整的 API 链路

set -e

API_URL="http://localhost:8000"
FRONTEND_URL="http://localhost:8080"

echo "🧪 MyStoryApp Docker 端到端测试"
echo "================================"
echo ""

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

# 测试函数
run_test() {
    local name="$1"
    local command="$2"
    
    echo -n "测试: $name ... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ 失败${NC}"
        ((failed++))
    fi
}

# 1. 测试健康检查
echo "1. 基础服务测试"
echo "----------------"

run_test "后端健康检查" "curl -s ${API_URL}/health | grep -q 'ok'"
run_test "Swagger 文档" "curl -s ${API_URL}/docs | grep -q 'swagger'"
run_test "前端页面" "curl -s ${FRONTEND_URL} | grep -q 'MyStoryApp'"
run_test "Redis 连接" "docker exec mystoryapp-redis redis-cli ping | grep -q 'PONG'"

echo ""
echo "2. API 功能测试"
echo "----------------"

# 测试语音列表
run_test "语音列表 API" "curl -s ${API_URL}/api/v1/tts/voices | grep -q 'success'"

# 测试语音合成（短文本）
echo -n "测试: TTS 语音合成 ... "
TTS_RESULT=$(curl -s -X POST ${API_URL}/api/v1/tts/generate \
    -H "Content-Type: application/json" \
    -d '{"text":"测试语音","voice_type":"standardFemale","speed":1.0}')

if echo "$TTS_RESULT" | grep -q "success"; then
    echo -e "${GREEN}✅ 通过${NC}"
    AUDIO_URL=$(echo "$TTS_RESULT" | grep -o '"audio_url":"[^"]*"' | cut -d'"' -f4)
    echo "   音频地址: $AUDIO_URL"
    ((passed++))
else
    echo -e "${RED}❌ 失败${NC}"
    echo "   响应: $TTS_RESULT"
    ((failed++))
fi

# 测试图片扩展（需要实际图片，这里跳过）
echo -n "测试: 图片扩展 API (检查端点) ... "
if curl -s -X POST ${API_URL}/api/v1/image/validate \
    -H "Content-Type: application/json" \
    -d '{"mimetype":"image/jpeg"}' | grep -q "success"; then
    echo -e "${GREEN}✅ 通过${NC}"
    ((passed++))
else
    echo -e "${RED}❌ 失败${NC}"
    ((failed++))
fi

# 测试视频任务创建
echo -n "测试: 视频任务创建 ... "
VIDEO_RESULT=$(curl -s -X POST ${API_URL}/api/v1/video/create \
    -H "Content-Type: application/json" \
    -d '{
        "title": "Docker测试视频",
        "slides": [{
            "image_url": "https://picsum.photos/1280/720",
            "caption": "测试幻灯片",
            "voice_text": "这是测试配音",
            "duration": 3,
            "transition": "fade"
        }],
        "config": {
            "resolution": "720p",
            "voice_type": "standardFemale",
            "subtitle_enabled": true,
            "ai_image_expansion": false
        }
    }')

if echo "$VIDEO_RESULT" | grep -q "success"; then
    echo -e "${GREEN}✅ 通过${NC}"
    TASK_ID=$(echo "$VIDEO_RESULT" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
    echo "   任务ID: $TASK_ID"
    ((passed++))
    
    # 查询任务状态
    echo -n "测试: 视频任务状态查询 ... "
    sleep 2
    STATUS_RESULT=$(curl -s ${API_URL}/api/v1/video/status/${TASK_ID})
    if echo "$STATUS_RESULT" | grep -q "success"; then
        echo -e "${GREEN}✅ 通过${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ 失败${NC}"
        ((failed++))
    fi
else
    echo -e "${RED}❌ 失败${NC}"
    echo "   响应: $VIDEO_RESULT"
    ((failed++))
fi

# 测试队列状态
echo -n "测试: 队列状态查询 ... "
if curl -s ${API_URL}/api/v1/video/queue-status | grep -q "success"; then
    echo -e "${GREEN}✅ 通过${NC}"
    ((passed++))
else
    echo -e "${RED}❌ 失败${NC}"
    ((failed++))
fi

echo ""
echo "3. 容器状态检查"
echo "----------------"

run_test "Redis 容器" "docker ps | grep -q 'mystoryapp-redis'"
run_test "后端容器" "docker ps | grep -q 'mystoryapp-backend-py'"
run_test "Worker 容器" "docker ps | grep -q 'mystoryapp-worker'"
run_test "Flower 容器" "docker ps | grep -q 'mystoryapp-flower'"
run_test "前端容器" "docker ps | grep -q 'mystoryapp-frontend'"

echo ""
echo "📊 测试结果汇总"
echo "================"
echo -e "${GREEN}✅ 通过: $passed${NC}"
echo -e "${RED}❌ 失败: $failed${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过！Docker 端到端链路正常。${NC}"
    echo ""
    echo "访问地址:"
    echo "  • API 文档: http://localhost:8000/docs"
    echo "  • 测试页面: http://localhost:8080"
    echo "  • Flower:   http://localhost:5555"
    exit 0
else
    echo -e "${YELLOW}⚠️  有 $failed 项测试失败${NC}"
    echo ""
    echo "排查建议:"
    echo "  1. 查看日志: ./docker-deploy.sh logs"
    echo "  2. 检查状态: ./docker-deploy.sh status"
    echo "  3. 确认 BAILIAN_API_KEY 有效"
    exit 1
fi
