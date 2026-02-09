"""
素材模型
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Enum, BigInteger
from sqlalchemy.orm import relationship
from app.db.database import Base
import enum


class MaterialType(str, enum.Enum):
    """素材类型"""
    IMAGE = "image"           # 原始图片
    EXPANDED_IMAGE = "expanded_image"  # AI扩展后的图片
    AUDIO = "audio"           # 配音音频
    VIDEO = "video"           # 生成的视频
    MUSIC = "music"           # 背景音乐


class Material(Base):
    """素材表"""
    __tablename__ = "materials"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # 素材信息
    title = Column(String(200), default="")
    description = Column(Text, default="")
    material_type = Column(Enum(MaterialType), nullable=False)
    
    # 文件信息
    file_url = Column(String(500), nullable=False)  # 文件URL
    file_path = Column(String(500), nullable=False)  # 本地路径
    file_size = Column(BigInteger, default=0)  # 文件大小（字节）
    file_format = Column(String(20), default="")  # jpg/png/mp3/mp4等
    
    # 元数据（JSON格式存储）
    metadata = Column(Text, default="{}")  # 宽度、高度、时长等
    
    # 标签（逗号分隔）
    tags = Column(String(500), default="")
    
    # 状态
    is_deleted = Column(Integer, default=0)  # 软删除
    is_favorite = Column(Integer, default=0)  # 收藏
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关联
    user = relationship("User", back_populates="materials")


class VideoTaskDB(Base):
    """视频任务表"""
    __tablename__ = "video_tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # 任务信息
    task_id = Column(String(100), unique=True, index=True, nullable=False)
    title = Column(String(200), default="")
    description = Column(Text, default="")
    
    # 状态
    status = Column(String(50), default="pending")  # pending/processing/completed/failed
    progress = Column(Integer, default=0)  # 0-100
    message = Column(String(500), default="")
    error = Column(Text, default="")
    
    # 输出
    output_url = Column(String(500), default="")
    thumbnail_url = Column(String(500), default="")
    duration = Column(Integer, default=0)  # 视频时长（秒）
    resolution = Column(String(20), default="")  # 720p/1080p等
    
    # 配置快照
    config_snapshot = Column(Text, default="{}")  # JSON格式存储完整配置
    slides_count = Column(Integer, default=0)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    # 关联
    user = relationship("User", back_populates="video_tasks")
