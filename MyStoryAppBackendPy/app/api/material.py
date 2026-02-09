"""
素材管理 API
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import json

from app.db.database import get_db
from app.db.models import User
from app.db.material import Material, MaterialType, VideoTaskDB
from app.auth.utils import get_current_user
from app.config import settings
from app.core.logger import logger
import uuid
import os

router = APIRouter()


# ========== 请求/响应模型 ==========

class MaterialResponse(BaseModel):
    """素材响应"""
    id: int
    title: str
    description: str
    material_type: str
    file_url: str
    file_size: int
    file_format: str
    metadata: dict
    tags: List[str]
    is_favorite: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class MaterialListResponse(BaseModel):
    """素材列表响应"""
    total: int
    items: List[MaterialResponse]
    page: int
    page_size: int


class MaterialUpdateRequest(BaseModel):
    """素材更新请求"""
    title: Optional[str] = None
    description: Optional[str] = None
    tags: Optional[List[str]] = None
    is_favorite: Optional[bool] = None


class VideoTaskResponse(BaseModel):
    """视频任务响应"""
    id: int
    task_id: str
    title: str
    description: str
    status: str
    progress: int
    message: str
    output_url: str
    thumbnail_url: str
    duration: int
    resolution: str
    slides_count: int
    created_at: datetime
    completed_at: Optional[datetime]
    
    class Config:
        from_attributes = True


# ========== 素材 API ==========

@router.post("/upload", response_model=MaterialResponse)
async def upload_material(
    file: UploadFile = File(...),
    title: str = Form(default=""),
    description: str = Form(default=""),
    material_type: str = Form(default="image"),
    tags: str = Form(default=""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    上传素材
    """
    # 验证文件类型
    allowed_types = {
        "image": ["image/jpeg", "image/png", "image/webp", "image/heic"],
        "audio": ["audio/mpeg", "audio/wav", "audio/mp3"],
        "video": ["video/mp4", "video/quicktime"],
        "music": ["audio/mpeg", "audio/mp3"]
    }
    
    material_type_enum = MaterialType(material_type)
    if file.content_type not in allowed_types.get(material_type, []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支持的文件类型: {file.content_type}"
        )
    
    # 保存文件
    file_ext = file.filename.split(".")[-1] if "." in file.filename else "bin"
    unique_name = f"{uuid.uuid4()}.{file_ext}"
    
    user_upload_dir = os.path.join(settings.UPLOAD_DIR, str(current_user.id))
    os.makedirs(user_upload_dir, exist_ok=True)
    
    file_path = os.path.join(user_upload_dir, unique_name)
    
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)
    
    file_size = len(content)
    
    # 创建素材记录
    material = Material(
        user_id=current_user.id,
        title=title or file.filename,
        description=description,
        material_type=material_type_enum,
        file_url=f"/uploads/{current_user.id}/{unique_name}",
        file_path=file_path,
        file_size=file_size,
        file_format=file_ext.lower(),
        tags=tags,
        metadata="{}"
    )
    
    db.add(material)
    
    # 更新用户存储使用量
    current_user.storage_used += file_size
    if material_type == "image":
        current_user.total_images += 1
    elif material_type == "video":
        current_user.total_videos += 1
    
    await db.commit()
    await db.refresh(material)
    
    logger.info(f"素材上传成功: {material.title} (用户: {current_user.email})")
    
    return MaterialResponse(
        **{k: v for k, v in material.__dict__.items() if k in MaterialResponse.model_fields},
        tags=tags.split(",") if tags else [],
        metadata={}
    )


@router.get("/list", response_model=MaterialListResponse)
async def list_materials(
    material_type: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
    is_favorite: Optional[bool] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    获取素材列表
    """
    # 构建查询
    query = select(Material).where(
        Material.user_id == current_user.id,
        Material.is_deleted == 0
    )
    
    if material_type:
        query = query.where(Material.material_type == MaterialType(material_type))
    
    if is_favorite is not None:
        query = query.where(Material.is_favorite == (1 if is_favorite else 0))
    
    # 统计总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # 分页查询
    query = query.order_by(desc(Material.created_at))
    query = query.offset((page - 1) * page_size).limit(page_size)
    
    result = await db.execute(query)
    materials = result.scalars().all()
    
    return MaterialListResponse(
        total=total,
        items=[
            MaterialResponse(
                **{k: v for k, v in m.__dict__.items() if k in MaterialResponse.model_fields},
                tags=m.tags.split(",") if m.tags else [],
                metadata=json.loads(m.metadata) if m.metadata else {}
            )
            for m in materials
        ],
        page=page,
        page_size=page_size
    )


@router.get("/{material_id}", response_model=MaterialResponse)
async def get_material(
    material_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    获取素材详情
    """
    result = await db.execute(
        select(Material).where(
            Material.id == material_id,
            Material.user_id == current_user.id,
            Material.is_deleted == 0
        )
    )
    material = result.scalar_one_or_none()
    
    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="素材不存在"
        )
    
    return MaterialResponse(
        **{k: v for k, v in material.__dict__.items() if k in MaterialResponse.model_fields},
        tags=material.tags.split(",") if material.tags else [],
        metadata=json.loads(material.metadata) if material.metadata else {}
    )


@router.put("/{material_id}", response_model=MaterialResponse)
async def update_material(
    material_id: int,
    request: MaterialUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    更新素材信息
    """
    result = await db.execute(
        select(Material).where(
            Material.id == material_id,
            Material.user_id == current_user.id,
            Material.is_deleted == 0
        )
    )
    material = result.scalar_one_or_none()
    
    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="素材不存在"
        )
    
    if request.title is not None:
        material.title = request.title
    if request.description is not None:
        material.description = request.description
    if request.tags is not None:
        material.tags = ",".join(request.tags)
    if request.is_favorite is not None:
        material.is_favorite = 1 if request.is_favorite else 0
    
    await db.commit()
    await db.refresh(material)
    
    return MaterialResponse(
        **{k: v for k, v in material.__dict__.items() if k in MaterialResponse.model_fields},
        tags=material.tags.split(",") if material.tags else [],
        metadata=json.loads(material.metadata) if material.metadata else {}
    )


@router.delete("/{material_id}")
async def delete_material(
    material_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    删除素材（软删除）
    """
    result = await db.execute(
        select(Material).where(
            Material.id == material_id,
            Material.user_id == current_user.id
        )
    )
    material = result.scalar_one_or_none()
    
    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="素材不存在"
        )
    
    # 软删除
    material.is_deleted = 1
    
    # 更新用户存储统计
    current_user.storage_used -= material.file_size
    if material.material_type == MaterialType.IMAGE or material.material_type == MaterialType.EXPANDED_IMAGE:
        current_user.total_images = max(0, current_user.total_images - 1)
    elif material.material_type == MaterialType.VIDEO:
        current_user.total_videos = max(0, current_user.total_videos - 1)
    
    await db.commit()
    
    logger.info(f"素材删除: {material.title} (用户: {current_user.email})")
    
    return {"success": True, "message": "素材已删除"}


# ========== 视频任务 API ==========

@router.get("/tasks/list", response_model=List[VideoTaskResponse])
async def list_video_tasks(
    page: int = 1,
    page_size: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    获取视频任务列表
    """
    result = await db.execute(
        select(VideoTaskDB)
        .where(VideoTaskDB.user_id == current_user.id)
        .order_by(desc(VideoTaskDB.created_at))
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    tasks = result.scalars().all()
    
    return [VideoTaskResponse.model_validate(t) for t in tasks]
