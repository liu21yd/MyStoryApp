# MyStoryApp 本地部署方案

## 🎯 快速选择

| 场景 | 推荐方案 | 命令 |
|------|----------|------|
| **开发测试** | Docker Dev + 本地后端 | `./docker-dev.sh start` |
| **完整体验** | Docker Compose 全栈 | `./docker-deploy.sh start` |
| **iOS 开发** | 仅 Redis Docker | `./docker-dev.sh start` |

## 🚀 方案一：开发环境（推荐开发用）

只启动 Redis，后端在本地运行（方便调试）：

```bash
# 1. 启动 Redis
cd MyStoryApp
./docker-dev.sh start

# 2. 在另一个终端启动后端
cd MyStoryAppBackend
npm install
npm run dev

# 3. 打开测试页面
open api-test.html
```

**优点**：
- ✅ 后端代码修改即时生效
- ✅ 方便断点调试
- ✅ 日志直接输出到终端

## 🚀 方案二：完整部署（推荐体验用）

一键启动所有服务：

```bash
cd MyStoryApp

# 1. 配置环境变量
echo "BAILIAN_API_KEY=你的API密钥" > .env

# 2. 一键部署
./docker-deploy.sh start

# 3. 访问测试页面
open http://localhost:8080
```

**启动的服务**：
- 🐳 Redis (localhost:6379)
- 🔧 后端 API (localhost:3000)
- 🌐 前端页面 (localhost:8080)

## 📊 服务架构

```
┌─────────────────────────────────────────────┐
│           Docker Compose 网络                │
│                                             │
│  ┌──────────┐    ┌──────────┐   ┌────────┐ │
│  │  Frontend│    │  Backend │   │  Redis │ │
│  │  (Nginx) │───→│ (Node.js)│←──│        │ │
│  │  :8080   │    │  :3000   │   │ :6379  │ │
│  └──────────┘    └──────────┘   └────────┘ │
│       ↑                                     │
│       │                                     │
│   api-test.html                             │
└─────────────────────────────────────────────┘
```

## 🔧 常用命令

### 开发环境
```bash
./docker-dev.sh start   # 启动 Redis
./docker-dev.sh stop    # 停止 Redis
./docker-dev.sh reset   # 重置 Redis 数据
```

### 生产部署
```bash
./docker-deploy.sh start    # 启动所有服务
./docker-deploy.sh stop     # 停止所有服务
./docker-deploy.sh restart  # 重启服务
./docker-deploy.sh logs     # 查看日志
./docker-deploy.sh status   # 查看状态
./docker-deploy.sh update   # 更新镜像
./docker-deploy.sh reset    # 重置数据
```

## 🐳 Docker 命令

```bash
# 查看运行中的容器
docker-compose ps

# 查看日志
docker-compose logs -f backend
docker-compose logs -f redis

# 进入容器
docker exec -it mystoryapp-backend sh
docker exec -it mystoryapp-redis redis-cli

# 重建镜像
docker-compose up --build -d

# 清理数据
docker-compose down -v
docker volume prune
```

## 🔍 故障排除

### 端口被占用
```bash
# 查找占用 3000 端口的进程
lsof -i :3000

# 杀死进程
kill -9 <PID>
```

### 容器无法启动
```bash
# 查看详细日志
docker-compose logs --tail=100

# 检查环境变量
docker-compose config

# 重新构建
docker-compose down
docker-compose up --build
```

### Redis 连接失败
```bash
# 检查 Redis 状态
docker exec mystoryapp-redis redis-cli ping

# 重启 Redis
docker-compose restart redis
```

## 📁 数据持久化

Docker 数据卷位置：
```bash
# 查看数据卷
docker volume ls

# 查看数据卷详情
docker volume inspect mystoryapp_redis-data
```

数据备份：
```bash
# 备份 Redis 数据
docker exec mystoryapp-redis redis-cli BGSAVE
docker cp mystoryapp-redis:/data/dump.rdb ./backup/

# 备份生成的视频
docker cp mystoryapp-backend:/app/output ./backup/
```

## 🌍 网络配置

### 从宿主机访问
- 后端 API: http://localhost:3000
- 前端页面: http://localhost:8080
- Redis: localhost:6379

### 容器间通信
- Redis: `redis://redis:6379`
- 后端: `http://backend:3000`

### 从其他设备访问
修改 `.env`：
```bash
BASE_URL=http://你的IP:3000
```

然后使用 Docker 主机 IP 访问。

## 🎉 验证部署

```bash
# 1. 检查容器状态
docker-compose ps

# 2. 测试健康检查
curl http://localhost:3000/health

# 3. 测试 TTS
curl -X POST http://localhost:3000/api/v1/tts/generate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","voiceType":"standardFemale"}'

# 4. 打开浏览器测试
open http://localhost:8080
```

全部通过即部署成功！
