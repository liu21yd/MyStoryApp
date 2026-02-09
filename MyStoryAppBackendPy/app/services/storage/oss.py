"""
阿里云 OSS 存储服务实现
"""

import oss2
from pathlib import Path
from typing import Optional
import asyncio
from concurrent.futures import ThreadPoolExecutor

from app.services.storage.base import StorageService
from app.config import settings
from app.core.logger import logger


class OSSStorageService(StorageService):
    """阿里云 OSS 存储服务"""
    
    def __init__(self):
        self.access_key_id = settings.OSS_ACCESS_KEY_ID
        self.access_key_secret = settings.OSS_ACCESS_KEY_SECRET
        self.endpoint = settings.OSS_ENDPOINT
        self.bucket_name = settings.OSS_BUCKET
        self.custom_domain = settings.OSS_CUSTOM_DOMAIN  # 可选：自定义域名/CDN
        
        # 初始化 OSS 客户端
        self.auth = oss2.Auth(self.access_key_id, self.access_key_secret)
        self.bucket = oss2.Bucket(self.auth, self.endpoint, self.bucket_name)
        
        # 线程池用于异步操作
        self.executor = ThreadPoolExecutor(max_workers=4)
        
        logger.info(f"[OSS存储] 已初始化: bucket={self.bucket_name}, endpoint={self.endpoint}")
    
    def _get_key(self, filename: str) -> str:
        """
        生成 OSS 对象 key
        按用户和日期组织文件
        """
        from datetime import datetime
        today = datetime.now().strftime("%Y/%m/%d")
        return f"uploads/{today}/{filename}"
    
    async def upload_file(
        self,
        local_path: str,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """
        上传文件到 OSS
        """
        key = self._get_key(filename)
        
        # 在线程池中执行上传
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            self.executor,
            self._upload_sync,
            local_path,
            key,
            content_type
        )
        
        public_url = self.get_public_url(key)
        logger.info(f"[OSS存储] 文件已上传: {key}, URL: {public_url}")
        
        return public_url
    
    def _upload_sync(self, local_path: str, key: str, content_type: Optional[str]):
        """同步上传方法"""
        headers = {}
        if content_type:
            headers['Content-Type'] = content_type
        
        self.bucket.put_object_from_file(key, local_path, headers=headers)
    
    async def upload_from_bytes(
        self,
        data: bytes,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """
        从字节数据上传到 OSS
        """
        key = self._get_key(filename)
        
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            self.executor,
            self._upload_bytes_sync,
            data,
            key,
            content_type
        )
        
        public_url = self.get_public_url(key)
        logger.info(f"[OSS存储] 文件已上传: {key}, 大小: {len(data)} bytes")
        
        return public_url
    
    def _upload_bytes_sync(self, data: bytes, key: str, content_type: Optional[str]):
        """同步字节上传方法"""
        headers = {}
        if content_type:
            headers['Content-Type'] = content_type
        
        self.bucket.put_object(key, data, headers=headers)
    
    async def download_file(self, remote_url: str, local_path: str) -> str:
        """
        从 OSS 下载文件
        """
        # 从 URL 中提取 key
        key = self._extract_key_from_url(remote_url)
        
        dest = Path(local_path)
        dest.parent.mkdir(parents=True, exist_ok=True)
        
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            self.executor,
            self.bucket.get_object_to_file,
            key,
            str(dest)
        )
        
        logger.info(f"[OSS存储] 文件已下载: {key} -> {dest}")
        return str(dest)
    
    async def delete_file(self, file_url: str) -> bool:
        """
        删除 OSS 文件
        """
        try:
            key = self._extract_key_from_url(file_url)
            
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                self.executor,
                self.bucket.delete_object,
                key
            )
            
            logger.info(f"[OSS存储] 文件已删除: {key}")
            return True
        except Exception as e:
            logger.error(f"[OSS存储] 删除文件失败: {e}")
            return False
    
    async def get_file_url(self, filename: str, expire: int = 3600) -> str:
        """
        获取带签名的临时访问 URL
        """
        key = self._get_key(filename)
        
        loop = asyncio.get_event_loop()
        url = await loop.run_in_executor(
            self.executor,
            self.bucket.sign_url,
            'GET',
            key,
            expire
        )
        
        return url
    
    def get_public_url(self, key: str) -> str:
        """
        获取公共访问 URL
        """
        if self.custom_domain:
            # 使用自定义域名/CDN
            return f"https://{self.custom_domain}/{key}"
        else:
            # 使用 OSS 默认域名
            return f"https://{self.bucket_name}.{self.endpoint}/{key}"
    
    def _extract_key_from_url(self, url: str) -> str:
        """
        从 URL 中提取 OSS key
        """
        # 处理自定义域名
        if self.custom_domain and self.custom_domain in url:
            return url.split(f"{self.custom_domain}/")[-1]
        
        # 处理 OSS 域名
        if self.endpoint in url:
            return url.split(f"{self.endpoint}/")[-1]
        
        # 处理本地开发时的相对路径
        if "/uploads/" in url:
            return url.split("/uploads/")[-1]
        
        # 默认返回文件名
        return url.split("/")[-1]
    
    async def list_files(self, prefix: str = "", max_keys: int = 100):
        """
        列出文件（用于管理后台）
        """
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            self.executor,
            lambda: list(oss2.ObjectIterator(self.bucket, prefix=prefix, max_keys=max_keys))
        )
        return result
    
    async def get_file_info(self, key: str) -> dict:
        """
        获取文件信息
        """
        loop = asyncio.get_event_loop()
        meta = await loop.run_in_executor(
            self.executor,
            self.bucket.get_object_meta,
            key
        )
        return {
            "size": meta.content_length,
            "last_modified": meta.last_modified,
            "content_type": meta.content_type
        }
