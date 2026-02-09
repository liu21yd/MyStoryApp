"""
本地存储服务实现
"""

import shutil
from pathlib import Path
from typing import Optional

from app.services.storage.base import StorageService
from app.config import settings
from app.core.logger import logger


class LocalStorageService(StorageService):
    """本地文件系统存储"""
    
    def __init__(self):
        self.upload_dir = Path(settings.UPLOAD_DIR)
        self.output_dir = Path(settings.OUTPUT_DIR)
        self.base_url = settings.BASE_URL or f"http://localhost:{settings.API_PORT}"
        
        # 确保目录存在
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    async def upload_file(
        self,
        local_path: str,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """
        本地存储：复制文件到上传目录
        """
        source = Path(local_path)
        dest = self.upload_dir / filename
        
        # 复制文件
        shutil.copy2(source, dest)
        
        # 返回访问 URL
        public_url = self.get_public_url(filename)
        logger.info(f"[本地存储] 文件已保存: {dest}, URL: {public_url}")
        
        return public_url
    
    async def upload_from_bytes(
        self,
        data: bytes,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """
        从字节数据上传
        """
        dest = self.upload_dir / filename
        dest.write_bytes(data)
        
        public_url = self.get_public_url(filename)
        logger.info(f"[本地存储] 文件已保存: {dest}, 大小: {len(data)} bytes")
        
        return public_url
    
    async def download_file(self, remote_url: str, local_path: str) -> str:
        """
        本地存储：直接从路径复制
        """
        # 从 URL 中提取文件名
        filename = remote_url.split("/")[-1]
        source = self.upload_dir / filename
        
        if not source.exists():
            # 尝试从 output 目录查找
            source = self.output_dir / filename
        
        if not source.exists():
            raise FileNotFoundError(f"文件不存在: {source}")
        
        dest = Path(local_path)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        
        return str(dest)
    
    async def delete_file(self, file_url: str) -> bool:
        """
        删除本地文件
        """
        try:
            filename = file_url.split("/")[-1]
            
            # 尝试删除 upload 目录
            upload_file = self.upload_dir / filename
            if upload_file.exists():
                upload_file.unlink()
                logger.info(f"[本地存储] 文件已删除: {upload_file}")
                return True
            
            # 尝试删除 output 目录
            output_file = self.output_dir / filename
            if output_file.exists():
                output_file.unlink()
                logger.info(f"[本地存储] 文件已删除: {output_file}")
                return True
            
            return False
        except Exception as e:
            logger.error(f"[本地存储] 删除文件失败: {e}")
            return False
    
    async def get_file_url(self, filename: str, expire: int = 3600) -> str:
        """
        本地存储：返回公共 URL（本地存储不过期）
        """
        return self.get_public_url(filename)
    
    def get_public_url(self, filename: str) -> str:
        """
        获取公共访问 URL
        """
        return f"{self.base_url}/uploads/{filename}"
    
    def get_output_url(self, filename: str) -> str:
        """
        获取输出文件 URL
        """
        return f"{self.base_url}/output/{filename}"
