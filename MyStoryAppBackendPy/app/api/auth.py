"""
用户认证 API
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

from app.db.database import get_db
from app.db.models import User
from app.auth.utils import (
    get_password_hash, verify_password, create_access_token, get_current_user
)
from app.core.logger import logger

router = APIRouter()


# ========== 请求/响应模型 ==========

class UserRegisterRequest(BaseModel):
    """用户注册请求"""
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=100)
    nickname: Optional[str] = ""


class UserLoginRequest(BaseModel):
    """用户登录请求"""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """用户响应"""
    id: int
    email: str
    username: str
    nickname: str
    avatar: str
    bio: str
    created_at: datetime
    total_videos: int
    total_images: int
    storage_used: int
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Token 响应"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 604800  # 7天（秒）
    user: UserResponse


class UserUpdateRequest(BaseModel):
    """用户信息更新请求"""
    nickname: Optional[str] = None
    avatar: Optional[str] = None
    bio: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    """修改密码请求"""
    old_password: str
    new_password: str = Field(..., min_length=6, max_length=100)


# ========== API 路由 ==========

@router.post("/register", response_model=TokenResponse)
async def register(
    request: UserRegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    用户注册
    """
    # 检查邮箱是否已存在
    result = await db.execute(select(User).where(User.email == request.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱已被注册"
        )
    
    # 检查用户名是否已存在
    result = await db.execute(select(User).where(User.username == request.username))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已被使用"
        )
    
    # 创建用户
    user = User(
        email=request.email,
        username=request.username,
        hashed_password=get_password_hash(request.password),
        nickname=request.nickname or request.username,
    )
    
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    # 生成 Token
    access_token = create_access_token(data={"sub": str(user.id)})
    
    logger.info(f"用户注册成功: {user.email}")
    
    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user)
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    request: UserLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    用户登录
    """
    # 查找用户
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="邮箱或密码错误"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="用户已被禁用"
        )
    
    # 更新最后登录时间
    user.last_login = datetime.utcnow()
    await db.commit()
    
    # 生成 Token
    access_token = create_access_token(data={"sub": str(user.id)})
    
    logger.info(f"用户登录成功: {user.email}")
    
    return TokenResponse(
        access_token=access_token,
        user=UserResponse.model_validate(user)
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """
    获取当前用户信息
    """
    return UserResponse.model_validate(current_user)


@router.put("/me", response_model=UserResponse)
async def update_me(
    request: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    更新当前用户信息
    """
    if request.nickname is not None:
        current_user.nickname = request.nickname
    if request.avatar is not None:
        current_user.avatar = request.avatar
    if request.bio is not None:
        current_user.bio = request.bio
    
    await db.commit()
    await db.refresh(current_user)
    
    logger.info(f"用户信息更新: {current_user.email}")
    
    return UserResponse.model_validate(current_user)


@router.post("/change-password")
async def change_password(
    request: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    修改密码
    """
    # 验证旧密码
    if not verify_password(request.old_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="原密码错误"
        )
    
    # 更新密码
    current_user.hashed_password = get_password_hash(request.new_password)
    await db.commit()
    
    logger.info(f"用户修改密码: {current_user.email}")
    
    return {"success": True, "message": "密码修改成功"}
