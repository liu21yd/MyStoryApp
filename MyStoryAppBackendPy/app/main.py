"""
MyStoryApp Python Backend
FastAPI + Celery 实现
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager

from app.config import settings
from app.api import image, tts, video
from app.core.logger import logger


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    logger.info("🚀 MyStoryApp Python Backend 启动中...")
    logger.info(f"📁 上传目录: {settings.UPLOAD_DIR}")
    logger.info(f"📁 输出目录: {settings.OUTPUT_DIR}")
    yield
    logger.info("🛑 应用关闭")


app = FastAPI(
    title="MyStoryApp API",
    description="PPT 视频生成服务",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
app.mount("/output", StaticFiles(directory=settings.OUTPUT_DIR), name="output")

# 路由
app.include_router(image.router, prefix="/api/v1/image", tags=["图片"])
app.include_router(tts.router, prefix="/api/v1/tts", tags=["语音"])
app.include_router(video.router, prefix="/api/v1/video", tags=["视频"])


@app.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "version": "1.0.0",
        "language": "python",
        "framework": "fastapi"
    }


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "MyStoryApp Python Backend",
        "docs": "/docs",
        "health": "/health"
    }
