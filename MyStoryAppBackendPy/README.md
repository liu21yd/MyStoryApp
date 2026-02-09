# MyStoryApp Python Backend

使用 FastAPI + Celery 的 PPT 视频生成后端服务

## 技术栈

- **Web 框架**: FastAPI
- **任务队列**: Celery + Redis
- **视频处理**: FFmpeg-Python
- **HTTP 客户端**: HTTPX
- **配置管理**: Pydantic Settings

## 快速开始

```bash
# 1. 创建虚拟环境
cd MyStoryAppBackendPy
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或 venv\Scripts\activate  # Windows

# 2. 安装依赖
pip install -r requirements.txt

# 3. 配置环境变量
cp .env.example .env
# 编辑 .env 填入 BAILIAN_API_KEY

# 4. 启动 Redis
docker run -d -p 6379:6379 redis:7-alpine

# 5. 启动服务
# 终端 1: 启动 API
uvicorn app.main:app --reload

# 终端 2: 启动 Worker
celery -A app.tasks.celery_app worker --loglevel=info

# 终端 3: 启动 Flower (任务监控，可选)
celery -A app.tasks.celery_app flower --port=5555
```

## API 文档

启动后访问:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 项目结构

```
MyStoryAppBackendPy/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI 应用入口
│   ├── config.py            # 配置管理
│   ├── api/
│   │   ├── __init__.py
│   │   ├── image.py         # 图片扩展 API
│   │   ├── tts.py           # 语音合成 API
│   │   └── video.py         # 视频生成 API
│   ├── core/
│   │   ├── __init__.py
│   │   ├── errors.py        # 错误处理
│   │   └── logger.py        # 日志配置
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py       # Pydantic 模型
│   ├── services/
│   │   ├── __init__.py
│   │   ├── bailian_image.py # 百炼图片服务
│   │   ├── bailian_tts.py   # 百炼语音服务
│   │   ├── video_service.py # 视频合成服务
│   │   └── storage.py       # 文件存储服务
│   └── tasks/
│       ├── __init__.py
│       └── celery_app.py    # Celery 配置和任务
├── tests/
├── uploads/                 # 上传文件目录
├── output/                  # 输出文件目录
├── requirements.txt         # 依赖
├── Dockerfile              # Docker 镜像
└── README.md
```

## Docker 部署

```bash
# 构建镜像
docker build -t mystoryapp-python .

# 运行
docker run -d \
  -p 8000:8000 \
  -e BAILIAN_API_KEY=xxx \
  -v $(pwd)/output:/app/output \
  mystoryapp-python
```

## 环境变量

| 变量名 | 说明 | 必填 |
|--------|------|------|
| `BAILIAN_API_KEY` | 阿里云百炼 API Key | ✅ |
| `REDIS_URL` | Redis 连接地址 | 否 (默认 redis://localhost:6379) |
| `STORAGE_TYPE` | 存储类型 (local/s3) | 否 (默认 local) |
| `LOG_LEVEL` | 日志级别 | 否 (默认 info) |

## License

MIT
