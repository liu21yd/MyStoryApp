"""
图片扩展 API
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import Optional

from app.models.schemas import ImageExpandResponse
from app.services.bailian_image import bailian_image_service
from app.core.logger import logger

router = APIRouter()


@router.post("/expand", response_model=ImageExpandResponse)
async def expand_image(
    image: UploadFile = File(...),
    style: str = Form(default="cinematic")
):
    """
    扩展图片为 16:9 宽屏
    
    - **image**: 图片文件
    - **style**: 扩展风格 (cinematic/anime/realistic/dreamy/vintage/artistic)
    """
    # 验证图片格式
    if not bailian_image_service.validate_image(image.content_type):
        raise HTTPException(status_code=400, detail="不支持的图片格式")
    
    try:
        # 保存上传的图片
        import uuid
        from pathlib import Path
        from app.config import settings
        
        upload_dir = Path(settings.UPLOAD_DIR)
        upload_dir.mkdir(parents=True, exist_ok=True)
        
        file_ext = image.filename.split(".")[-1] if "." in image.filename else "jpg"
        file_path = upload_dir / f"{uuid.uuid4()}.{file_ext}"
        
        content = await image.read()
        file_path.write_bytes(content)
        
        # 调用百炼扩展图片
        expanded_url = await bailian_image_service.expand_image(str(file_path), style)
        
        return ImageExpandResponse(
            success=True,
            data={
                "task_id": str(uuid.uuid4()),
                "expanded_image_url": expanded_url
            }
        )
        
    except Exception as e:
        logger.exception("图片扩展失败")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/validate")
async def validate_image_format(mimetype: str):
    """验证图片格式是否支持"""
    is_valid = bailian_image_service.validate_image(mimetype)
    return {"success": True, "data": {"valid": is_valid}}
