"""
用户模型
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, BigInteger
from sqlalchemy.orm import relationship
from app.db.database import Base


class User(Base):
    """用户表"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    
    # 用户信息
    avatar = Column(String(500), default="")
    nickname = Column(String(100), default="")
    bio = Column(Text, default="")
    
    # 状态
    is_active = Column(Integer, default=1)  # 1=正常, 0=禁用
    is_superuser = Column(Integer, default=0)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    
    # 统计
    total_videos = Column(Integer, default=0)
    total_images = Column(Integer, default=0)
    storage_used = Column(BigInteger, default=0)  # 字节
    
    # 关联
    materials = relationship("Material", back_populates="user", cascade="all, delete-orphan")
    video_tasks = relationship("VideoTaskDB", back_populates="user", cascade="all, delete-orphan")
