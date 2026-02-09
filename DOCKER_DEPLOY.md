# MyStoryApp Docker 部署指南

## 🚀 一键部署

### 快速开始

```bash
# 1. 进入项目目录
cd MyStoryApp

# 2. 配置环境变量
cp MyStoryAppBackend/.env.example .env
# 编辑 .env 填入你的 BAILIAN_API_KEY

# 3. 启动所有服务
./docker-deploy.sh start
```

服务启动后会自动：
- ✅ 启动 Redis 服务
- ✅ 构建并启动后端 API
- ✅ 启动前端测试页面
- ✅ 健康检查

### 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| 后端 API | http://localhost:3000 | REST API |
| 测试页面 | http://localhost:8080 | 可视化测试 |
| Redis | localhost:6379 | 缓存和队列 |

## 📋 管理命令

```bash
# 查看状态
./docker-deploy.sh status

# 查看日志
./docker-deploy.sh logs

# 停止服务
./docker-deploy.sh stop

# 重启服务
./docker-deploy.sh restart

# 更新服务（拉取最新镜像）
./docker-deploy.sh update

# 重置数据（⚠️ 谨慎使用）
./docker-deploy.sh reset
```

## 🔧 手动 Docker 操作

如果你熟悉 Docker，也可以直接操作：

```bash
# 启动
docker-compose up -d

# 构建并启动
docker-compose up --build -d

# 查看日志
docker-compose logs -f backend

# 停止
docker-compose down

# 删除数据卷
docker-compose down -v
```

## 📁 数据存储

Docker 使用以下数据卷持久化数据：

| 卷名 | 用途 | 本地路径 |
|------|------|----------|
| redis-data | Redis 数据 | Docker 管理 |
| backend-uploads | 上传的图片 | Docker 管理 |
| backend-output | 生成的视频 | Docker 管理 |
| backend-logs | 应用日志 | Docker 管理 |

查看数据卷：
```bash
docker volume ls | grep mystoryapp
```

## 🔍 故障排除

### 服务无法启动

```bash
# 检查日志
docker-compose logs backend

# 检查端口占用
lsof -i :3000
lsof -i :6379
lsof -i :8080

# 重启服务
docker-compose restart
```

### 后端健康检查失败

```bash
# 进入后端容器检查
docker exec -it mystoryapp-backend sh

# 在容器内测试
curl http://localhost:3000/health

# 检查环境变量
echo $BAILIAN_API_KEY
```

### 重新构建

```bash
# 删除旧容器和镜像
docker-compose down
docker rmi mystoryapp-backend

# 重新构建
docker-compose up --build -d
```

## 🔐 环境变量配置

创建 `.env` 文件：

```bash
# 必填
BAILIAN_API_KEY=你的百炼API密钥

# 可选（有默认值）
NODE_ENV=production
LOG_LEVEL=info
STORAGE_TYPE=local
```

## 🌍 生产部署

### 使用外部 Redis

修改 `docker-compose.yml`：
```yaml
backend:
  environment:
    - REDIS_URL=redis://your-redis-host:6379
  # 移除 depends_on redis
```

### 使用 S3 存储

```bash
# .env 中添加
STORAGE_TYPE=s3
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_S3_BUCKET=mystoryapp
AWS_REGION=ap-northeast-1
```

### 使用反向代理（Nginx/Traefik）

```yaml
# 添加 traefik 标签
backend:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.backend.rule=Host(`api.yourdomain.com`)"
    - "traefik.http.services.backend.loadbalancer.server.port=3000"
```

## 📊 监控

### 查看资源使用

```bash
# 容器资源使用
docker stats

# 磁盘使用
docker system df
```

### 日志管理

```bash
# 限制日志大小（docker-compose.yml）
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 🆘 获取帮助

```bash
# 查看部署脚本帮助
./docker-deploy.sh

# Docker 命令帮助
docker-compose --help

# 查看容器详情
docker inspect mystoryapp-backend
```

## ✅ 验证部署

```bash
# 1. 检查所有容器运行状态
docker-compose ps

# 2. 测试 API
curl http://localhost:3000/health

# 3. 测试 TTS
curl -X POST http://localhost:3000/api/v1/tts/generate \
  -H "Content-Type: application/json" \
  -d '{"text":"测试","voiceType":"standardFemale"}'

# 4. 打开测试页面
open http://localhost:8080
```

所有测试通过即部署成功！🎉
