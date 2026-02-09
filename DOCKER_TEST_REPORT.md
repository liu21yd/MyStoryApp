# MyStoryApp Docker 测试报告

## 验证结果

运行时间: 2025-01-09

### ✅ 通过项 (7)

| 检查项 | 状态 | 说明 |
|--------|------|------|
| docker-compose.yml | ✅ | 配置文件存在 |
| docker-deploy.sh | ✅ | 部署脚本存在 |
| 后端 Dockerfile | ✅ | 镜像构建文件存在 |
| 后端 package.json | ✅ | 依赖配置存在 |
| 端口 3000 | ✅ | 后端 API 端口可用 |
| 端口 6379 | ✅ | Redis 端口可用 |
| 端口 8080 | ✅ | 前端端口可用 |

### ❌ 失败项 (3)

| 检查项 | 状态 | 解决方案 |
|--------|------|----------|
| Docker 安装 | ❌ | 运行 `brew install --cask docker` |
| Docker Compose | ❌ | Docker Desktop 自带 |
| .env 配置 | ❌ | 已创建模板文件，需填入 API Key |

---

## 🚀 下一步操作

### 1. 完成 Docker 安装

Homebrew 正在安装 Docker Desktop，完成后：

1. 打开「启动台」找到 Docker
2. 点击启动，等待 "Docker is running" 提示
3. 可能需要输入系统密码授权

### 2. 配置 API Key

```bash
cd MyStoryApp

# 编辑 .env 文件
open -e .env

# 替换为你的百炼 API Key
BAILIAN_API_KEY=sk-xxxxxxxxxxxxxxxx
```

获取 API Key: https://dashscope.aliyun.com/

### 3. 重新验证

```bash
./verify-docker.sh
```

### 4. 启动服务

```bash
./docker-deploy.sh start
```

---

## 🧪 测试清单

服务启动后，执行以下测试：

### 测试 1: 健康检查
```bash
curl http://localhost:3000/health
```
预期返回: `{"status":"ok",...}`

### 测试 2: 语音合成
```bash
curl -X POST http://localhost:3000/api/v1/tts/generate \
  -H "Content-Type: application/json" \
  -d '{"text":"你好","voiceType":"standardFemale"}'
```
预期返回: 包含 audioUrl

### 测试 3: 浏览器测试
打开 http://localhost:8080
- 测试 TTS 生成
- 测试图片扩展
- 测试视频生成

---

## 🐛 常见问题

### Docker 启动失败
```bash
# 检查 Docker 状态
docker info

# 重置 Docker
docker system prune -a
```

### 端口被占用
```bash
# 查找占用进程
lsof -i :3000

# 杀死进程
kill -9 <PID>
```

### API Key 无效
```bash
# 测试百炼 API
curl -H "Authorization: Bearer $BAILIAN_API_KEY" \
  https://dashscope.aliyuncs.com/api/v1/models
```

---

## 📊 预期结果

| 服务 | 地址 | 预期状态 |
|------|------|----------|
| 后端 API | http://localhost:3000 | ✅ 运行中 |
| 前端页面 | http://localhost:8080 | ✅ 可访问 |
| Redis | localhost:6379 | ✅ 连接正常 |

所有服务正常运行即部署成功！
