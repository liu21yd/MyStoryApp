"""
视频生成 API
"""

import uuid
from fastapi import APIRouter, HTTPException, BackgroundTasks
from celery.result import AsyncResult

from app.models.schemas import (
    VideoCreateRequest, VideoCreateResponse, VideoStatusResponse
)
from app.tasks.video_tasks import generate_video_task
from app.tasks import celery_app
from app.core.logger import logger

router = APIRouter()


@router.post("/create", response_model=VideoCreateResponse)
async def create_video(request: VideoCreateRequest):
    """
    创建视频生成任务
    
    异步任务，返回 task_id 用于查询进度
    """
    try:
        task_id = str(uuid.uuid4())
        
        # 准备任务数据
        slides_data = [slide.model_dump() for slide in request.slides]
        config_data = request.config.model_dump()
        
        # 提交 Celery 任务
        task = generate_video_task.delay(task_id, slides_data, config_data)
        
        # 估算时间 (每页约10秒)
        estimated_time = len(request.slides) * 10
        
        return VideoCreateResponse(
            success=True,
            data={
                "task_id": task_id,
                "celery_task_id": task.id,
                "status": "pending",
                "estimated_time": estimated_time
            }
        )
        
    except Exception as e:
        logger.exception("创建视频任务失败")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status/{task_id}", response_model=VideoStatusResponse)
async def get_video_status(task_id: str):
    """查询视频生成任务状态"""
    try:
        # 查询 Celery 任务结果
        # 注意：这里简化处理，实际应该通过 task_id 关联 celery_task_id
        # 或者使用 Redis 存储任务状态
        
        return VideoStatusResponse(
            success=True,
            data={
                "task_id": task_id,
                "status": "processing",
                "progress": 0.5,
                "message": "处理中..."
            }
        )
        
    except Exception as e:
        logger.exception("查询任务状态失败")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/result/{task_id}")
async def get_video_result(task_id: str):
    """获取视频结果"""
    # TODO: 从存储中查询结果
    return {
        "success": True,
        "data": {
            "task_id": task_id,
            "status": "completed",
            "video_url": f"/output/video_{task_id}.mp4"
        }
    }


@router.get("/queue-status")
async def get_queue_status():
    """获取队列状态"""
    try:
        # 使用 Celery Inspect 获取队列信息
        inspect = celery_app.control.inspect()
        
        active = inspect.active() or {}
        scheduled = inspect.scheduled() or {}
        reserved = inspect.reserved() or {}
        
        return {
            "success": True,
            "data": {
                "active": len(list(active.values())[0]) if active else 0,
                "waiting": len(list(scheduled.values())[0]) if scheduled else 0,
                "reserved": len(list(reserved.values())[0]) if reserved else 0
            }
        }
        
    except Exception as e:
        logger.warning(f"获取队列状态失败: {e}")
        return {
            "success": True,
            "data": {
                "active": 0,
                "waiting": 0,
                "reserved": 0
            }
        }
