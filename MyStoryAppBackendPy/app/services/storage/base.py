"""
存储服务抽象基类
"""

from abc import ABC, abstractmethod
from typing import Optional
from pathlib import Path


class StorageService(ABC):
    """存储服务抽象基类"""
    
    @abstractmethod
    async def upload_file(
        self,
        local_path: str,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """
        上传文件
        
        Args:
            local_path: 本地文件路径
            filename: 目标文件名
            content_type: 文件类型
            
        Returns:
            文件访问 URL
        """
        pass
    
    @abstractmethod
    async def download_file(self, remote_url: str, local_path: str) -> str:
        """
        下载文件
        
        Args:
            remote_url: 远程文件 URL
            local_path: 本地保存路径
            
        Returns:
            本地文件路径
        """
        pass
    
    @abstractmethod
    async def delete_file(self, file_url: str) -> bool:
        """
        删除文件
        
        Args:
            file_url: 文件 URL
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    async def get_file_url(self, filename: str, expire: int = 3600) -> str:
        """
        获取文件访问 URL（带签名）
        
        Args:
            filename: 文件名
            expire: URL 过期时间（秒）
            
        Returns:
            带签名的访问 URL
        """
        pass
    
    @abstractmethod
    def get_public_url(self, filename: str) -> str:
        """
        获取公共访问 URL（不带签名）
        
        Args:
            filename: 文件名
            
        Returns:
            公共访问 URL
        """
        pass
