"""
存储服务工厂
根据配置自动选择存储实现
"""

from app.config import settings
from app.services.storage.base import StorageService
from app.services.storage.local import LocalStorageService
from app.services.storage.oss import OSSStorageService
from app.core.logger import logger


class StorageFactory:
    """存储服务工厂"""
    
    _instance: StorageService = None
    
    @classmethod
    def get_storage_service(cls) -> StorageService:
        """
        获取存储服务实例（单例）
        """
        if cls._instance is None:
            storage_type = settings.STORAGE_TYPE.lower()
            
            if storage_type == "local":
                cls._instance = LocalStorageService()
                logger.info("[存储工厂] 使用本地存储服务")
                
            elif storage_type in ["oss", "s3", "aliyun"]:
                cls._instance = OSSStorageService()
                logger.info("[存储工厂] 使用阿里云 OSS 存储服务")
                
            else:
                raise ValueError(f"不支持的存储类型: {storage_type}")
        
        return cls._instance
    
    @classmethod
    def reset(cls):
        """
        重置存储服务（用于测试）
        """
        cls._instance = None


# 便捷函数
def get_storage() -> StorageService:
    """获取存储服务实例"""
    return StorageFactory.get_storage_service()
