"""
日志配置
"""

import sys
from loguru import logger
from app.config import settings

# 移除默认 handler
logger.remove()

# 添加控制台输出
logger.add(
    sys.stdout,
    level=settings.LOG_LEVEL.upper(),
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
           "<level>{level: <8}</level> | "
           "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - "
           "<level>{message}</level>"
)

# 添加文件日志
logger.add(
    "logs/app.log",
    rotation="10 MB",
    retention="7 days",
    level="INFO",
    encoding="utf-8"
)

# 添加错误日志
logger.add(
    "logs/error.log",
    rotation="10 MB",
    retention="30 days",
    level="ERROR",
    encoding="utf-8"
)
