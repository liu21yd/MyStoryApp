"""
百炼语音合成服务
"""

import httpx
import uuid
from pathlib import Path
from typing import Optional

from app.config import settings
from app.core.logger import logger


BAILIAN_BASE_URL = "https://dashscope.aliyuncs.com/api/v1"

# 语音映射
VOICE_MAP = {
    "standardFemale": "zhitian",  # 知甜-温柔女声
    "standardMale": "zhizhe",     # 知哲-标准男声
    "gentleFemale": "zhishu",     # 知树-柔和女声
    "deepMale": "zhida",          # 知达-磁性男声
    "child": "zhimiao",           # 知妙-童声
    "cartoon": "zhifei"           # 知飞-活泼女声
}


class BailianTTSService:
    """百炼语音合成服务"""
    
    def __init__(self):
        self.api_key = settings.BAILIAN_API_KEY
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    async def generate_speech(
        self,
        text: str,
        voice_type: str = "standardFemale",
        speed: float = 1.0
    ) -> dict:
        """
        生成语音
        
        Args:
            text: 要合成的文字
            voice_type: 语音类型
            speed: 语速 (0.5-2.0)
            
        Returns:
            包含 url 和 duration 的字典
        """
        logger.info(f"[百炼] 生成语音: {text[:30]}...")
        
        voice = VOICE_MAP.get(voice_type, VOICE_MAP["standardFemale"])
        
        # 短文本直接同步请求
        if len(text) <= 300:
            return await self._sync_tts(text, voice, speed)
        else:
            # 长文本使用异步接口
            return await self._async_tts(text, voice, speed)
    
    async def _sync_tts(self, text: str, voice: str, speed: float) -> dict:
        """同步 TTS"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{BAILIAN_BASE_URL}/services/aigc/tts",
                headers=self.headers,
                json={
                    "model": "sambert-zhimao-v1",
                    "input": {"text": text},
                    "parameters": {
                        "voice": voice,
                        "speech_rate": speed,
                        "pitch_rate": 1.0,
                        "volume": 50,
                        "format": "mp3"
                    }
                },
                timeout=60.0
            )
            
            response.raise_for_status()
            
            # 保存音频文件
            audio_data = response.content
            filename = f"tts_{uuid.uuid4()}.mp3"
            output_path = Path(settings.OUTPUT_DIR) / filename
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(audio_data)
            
            # 估算时长 (中文字符约每秒5个)
            duration = len(text) / 5
            
            logger.info(f"[百炼] 语音生成成功: {filename}, 预估时长: {duration:.1f}s")
            
            return {
                "url": f"/output/{filename}",
                "duration": duration
            }
    
    async def _async_tts(self, text: str, voice: str, speed: float) -> dict:
        """异步 TTS（长文本）"""
        async with httpx.AsyncClient() as client:
            # 提交任务
            response = await client.post(
                f"{BAILIAN_BASE_URL}/services/aigc/tts/async",
                headers=self.headers,
                json={
                    "model": "sambert-zhimao-v1",
                    "input": {"text": text},
                    "parameters": {
                        "voice": voice,
                        "speech_rate": speed,
                        "format": "mp3"
                    }
                },
                timeout=30.0
            )
            
            response.raise_for_status()
            result = response.json()
            
            task_id = result.get("output", {}).get("task_id")
            if not task_id:
                raise ValueError("未获取到 task_id")
            
            # 轮询结果
            audio_url = await self._poll_tts_result(task_id)
            
            # 下载音频
            audio_data = await self._download_audio(audio_url)
            
            filename = f"tts_{uuid.uuid4()}.mp3"
            output_path = Path(settings.OUTPUT_DIR) / filename
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(audio_data)
            
            duration = len(text) / 5
            
            return {
                "url": f"/output/{filename}",
                "duration": duration
            }
    
    async def _poll_tts_result(self, task_id: str, max_attempts: int = 30) -> str:
        """轮询 TTS 任务结果"""
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
                    audio_url = result.get("output", {}).get("audio_address")
                    if audio_url:
                        return audio_url
                    raise ValueError("结果中没有音频 URL")
                
                elif task_status == "FAILED":
                    error_msg = result.get("output", {}).get("message", "未知错误")
                    raise RuntimeError(f"任务失败: {error_msg}")
                
                logger.info(f"[百炼] TTS 任务 {task_id} 状态: {task_status}, 第 {i+1} 次查询...")
            
            raise TimeoutError("轮询超时")
    
    async def _download_audio(self, url: str) -> bytes:
        """下载音频文件"""
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=30.0)
            response.raise_for_status()
            return response.content
    
    def get_voices(self) -> list:
        """获取支持的语音列表"""
        return [
            {"id": "standardFemale", "name": "知甜", "description": "温柔女声"},
            {"id": "standardMale", "name": "知哲", "description": "标准男声"},
            {"id": "gentleFemale", "name": "知树", "description": "柔和女声"},
            {"id": "deepMale", "name": "知达", "description": "磁性男声"},
            {"id": "child", "name": "知妙", "description": "童声"},
            {"id": "cartoon", "name": "知飞", "description": "活泼女声"}
        ]


import asyncio

# 单例
bailian_tts_service = BailianTTSService()
