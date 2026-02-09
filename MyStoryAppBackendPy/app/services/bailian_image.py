"""
百炼图片扩展服务
"""

import httpx
import asyncio
from pathlib import Path
from typing import Optional
import uuid

from app.config import settings
from app.core.logger import logger


BAILIAN_BASE_URL = "https://dashscope.aliyuncs.com/api/v1"

STYLE_PROMPTS = {
    "cinematic": "电影感，专业调色，电影质感，16:9宽屏比例",
    "anime": "动漫风格，鲜艳色彩，二次元画风，16:9宽屏比例",
    "realistic": "写实风格，自然光影，逼真细节，16:9宽屏比例",
    "dreamy": "梦幻风格，柔和色调，朦胧美感，16:9宽屏比例",
    "vintage": "复古胶片风格，暖色调，怀旧感，16:9宽屏比例",
    "artistic": "艺术风格，创意构图，绘画感，16:9宽屏比例"
}


class BailianImageService:
    """百炼图片服务"""
    
    def __init__(self):
        self.api_key = settings.BAILIAN_API_KEY
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    async def expand_image(self, image_path: str, style: str = "cinematic") -> str:
        """
        扩展图片为 16:9 宽屏
        
        Args:
            image_path: 本地图片路径
            style: 扩展风格
            
        Returns:
            扩展后图片的 URL
        """
        logger.info(f"[百炼] 扩展图片: {image_path}, 风格: {style}")
        
        # 读取图片并转为 base64
        image_data = Path(image_path).read_bytes()
        import base64
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        style_prompt = STYLE_PROMPTS.get(style, STYLE_PROMPTS["cinematic"])
        
        # 调用百炼图像生成 API
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{BAILIAN_BASE_URL}/services/aigc/text2image/image-synthesis",
                headers={**self.headers, "X-DashScope-Async": "enable"},
                json={
                    "model": "wanx-v1",
                    "input": {
                        "prompt": f"基于参考图创建16:9宽屏版本，保持主体内容完整。风格：{style_prompt}",
                        "ref_image": base64_image,
                        "size": "1280*720",
                        "n": 1
                    },
                    "parameters": {
                        "style": "<auto>",
                        "seed": uuid.uuid4().int % 1000000
                    }
                },
                timeout=30.0
            )
            
            response.raise_for_status()
            result = response.json()
            
            task_id = result.get("output", {}).get("task_id")
            if not task_id:
                raise ValueError("未获取到 task_id")
            
            # 轮询获取结果
            image_url = await self._poll_task_result(task_id)
            
            logger.info(f"[百炼] 图片扩展成功: {image_url}")
            return image_url
    
    async def _poll_task_result(self, task_id: str, max_attempts: int = 30) -> str:
        """轮询任务结果"""
        async with httpx.AsyncClient() as client:
            for i in range(max_attempts):
                await asyncio.sleep(2)
                
                response = await client.get(
                    f"{BAILIAN_BASE_URL}/tasks/{task_id}",
                    headers=self.headers,
                    timeout=10.0
                )
                response.raise_for_status()
                result = response.json()
                
                task_status = result.get("output", {}).get("task_status")
                
                if task_status == "SUCCEEDED":
                    results = result.get("output", {}).get("results", [])
                    if results and len(results) > 0:
                        return results[0].get("url")
                    raise ValueError("结果中没有图片 URL")
                
                elif task_status == "FAILED":
                    error_msg = result.get("output", {}).get("message", "未知错误")
                    raise RuntimeError(f"任务失败: {error_msg}")
                
                logger.info(f"[百炼] 任务 {task_id} 状态: {task_status}, 第 {i+1} 次查询...")
            
            raise TimeoutError("轮询超时")
    
    def validate_image(self, mimetype: str) -> bool:
        """验证图片格式"""
        allowed_types = ["image/jpeg", "image/png", "image/webp", "image/heic"]
        return mimetype in allowed_types


# 单例
bailian_image_service = BailianImageService()
