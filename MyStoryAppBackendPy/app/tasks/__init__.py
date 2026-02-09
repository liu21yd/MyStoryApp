"""
Celery 任务配置
"""

from celery import Celery
from app.config import settings
from app.core.logger import logger

# 创建 Celery 应用
celery_app = Celery(
    "mystoryapp",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.tasks.video_tasks"]
)

# Celery 配置
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Shanghai",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 任务超时时间 1小时
    worker_prefetch_multiplier=1,  # 每次只取一个任务
)
