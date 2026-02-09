"""
视频生成 Celery 任务
"""

import asyncio
from celery import Task
from asgiref.sync import async_to_sync

from app.tasks import celery_app
from app.models.schemas import Slide, VideoConfigRequest, VideoTask
from app.services.bailian_image import bailian_image_service
from app.services.bailian_tts import bailian_tts_service
from app.services.video_service import video_service
from app.core.logger import logger


class CallbackTask(Task):
    """带回调的任务基类"""
    
    def on_success(self, retval, task_id, args, kwargs):
        logger.info(f"任务成功: {task_id}")
    
    def on_failure(self, exc, task_id, args, kwargs, einfo):
        logger.error(f"任务失败: {task_id}, 错误: {exc}")


@celery_app.task(base=CallbackTask, bind=True, max_retries=3)
def generate_video_task(self, task_id: str, slides_data: list, config_data: dict):
    """
    生成视频任务
    
    Args:
        task_id: 任务ID
        slides_data: 幻灯片数据列表
        config_data: 配置数据
    """
    try:
        # 转换数据模型
        slides = [Slide(**slide) for slide in slides_data]
        config = VideoConfigRequest(**config_data)
        
        # 运行异步任务
        async_to_sync(_generate_video_async)(self, task_id, slides, config)
        
        return {"success": True, "task_id": task_id}
        
    except Exception as exc:
        logger.exception(f"视频生成任务失败: {task_id}")
        # 重试
        raise self.retry(exc=exc, countdown=60)


async def _generate_video_async(task, task_id: str, slides: list, config: VideoConfigRequest):
    """异步生成视频"""
    
    # 步骤1: 扩展图片
    if config.ai_image_expansion:
        task.update_state(
            state="expanding_images",
            meta={"progress": 0.1, "message": "AI扩展图片中..."}
        )
        
        for i, slide in enumerate(slides):
            try:
                expanded_url = await bailian_image_service.expand_image(
                    slide.image_url,
                    config.expansion_style.value
                )
                slide.expanded_image_url = expanded_url
                
                progress = 0.1 + (0.3 * (i + 1) / len(slides))
                task.update_state(
                    state="expanding_images",
                    meta={"progress": progress, "message": f"扩展图片 {i+1}/{len(slides)}..."}
                )
            except Exception as e:
                logger.warning(f"图片扩展失败，使用原图: {e}")
    
    # 步骤2: 生成配音
    task.update_state(
        state="generating_voice",
        meta={"progress": 0.4, "message": "生成配音中..."}
    )
    
    for i, slide in enumerate(slides):
        if slide.voice_text:
            try:
                tts_result = await bailian_tts_service.generate_speech(
                    slide.voice_text,
                    config.voice_type.value,
                    config.voice_speed
                )
                slide.voice_url = tts_result["url"]
                
                progress = 0.4 + (0.2 * (i + 1) / len(slides))
                task.update_state(
                    state="generating_voice",
                    meta={"progress": progress, "message": f"生成配音 {i+1}/{len(slides)}..."}
                )
            except Exception as e:
                logger.warning(f"配音生成失败: {e}")
    
    # 步骤3: 合成视频
    async def progress_callback(progress: float, message: str):
        task.update_state(
            state="composing",
            meta={"progress": 0.6 + (progress * 0.4), "message": message}
        )
    
    output_url = await video_service.compose_video(
        slides,
        config,
        task_id,
        progress_callback
    )
    
    # 完成
    task.update_state(
        state="completed",
        meta={"progress": 1.0, "message": "视频生成完成！", "output_url": output_url}
    )
    
    return output_url
