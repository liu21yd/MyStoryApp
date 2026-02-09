"""
配置管理
"""

from pydantic_settings import BaseSettings
from functools import lru_cache
import secrets


class Settings(BaseSettings):
    """应用配置"""
    
    # 百炼 API
    BAILIAN_API_KEY: str = ""
    
    # 数据库
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/mystoryapp"
    
    # JWT 密钥（自动生成或使用环境变量）
    SECRET_KEY: str = secrets.token_urlsafe(32)
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # 存储
    STORAGE_TYPE: str = "local"  # local or s3
    UPLOAD_DIR: str = "./uploads"
    OUTPUT_DIR: str = "./output"
    
    # 日志
    LOG_LEVEL: str = "info"
    
    # API
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """获取配置（缓存）"""
    return Settings()


settings = get_settings()
