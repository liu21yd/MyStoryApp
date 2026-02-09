"""
数据模型定义
"""

from typing import List, Optional
from enum import Enum
from pydantic import BaseModel, Field


# ========== 枚举类型 ==========

class VideoResolution(str, Enum):
    SD = "480p"
    HD = "720p"
    FHD = "1080p"
    K2 = "2k"
    K4 = "4k"


class VoiceType(str, Enum):
    STANDARD_FEMALE = "standardFemale"
    STANDARD_MALE = "standardMale"
    GENTLE_FEMALE = "gentleFemale"
    DEEP_MALE = "deepMale"
    CHILD = "child"
    CARTOON = "cartoon"


class BGMOption(str, Enum):
    NONE = "none"
    GENTLE = "gentle"
    UPBEAT = "upbeat"
    EPIC = "epic"
    ROMANTIC = "romantic"
    NOSTALGIC = "nostalgic"


class ImageExpansionStyle(str, Enum):
    CINEMATIC = "cinematic"
    ANIME = "anime"
    REALISTIC = "realistic"
    DREAMY = "dreamy"
    VINTAGE = "vintage"
    ARTISTIC = "artistic"


# ========== 请求模型 ==========

class SlideRequest(BaseModel):
    """幻灯片请求模型"""
    image_url: str = Field(..., description="图片URL")
    caption: str = Field(default="", description="字幕文字")
    voice_text: str = Field(default="", description="配音文本")
    duration: int = Field(default=5, ge=2, le=30, description="显示时长(秒)")
    transition: str = Field(default="fade", description="转场效果")


class VideoConfigRequest(BaseModel):
    """视频配置请求模型"""
    resolution: VideoResolution = Field(default=VideoResolution.HD)
    frame_rate: int = Field(default=30)
    voice_type: VoiceType = Field(default=VoiceType.STANDARD_FEMALE)
    voice_speed: float = Field(default=1.0, ge=0.5, le=2.0)
    background_music: BGMOption = Field(default=BGMOption.GENTLE)
    subtitle_enabled: bool = Field(default=True)
    subtitle_position: str = Field(default="bottom")
    ai_image_expansion: bool = Field(default=True)
    expansion_style: ImageExpansionStyle = Field(default=ImageExpansionStyle.CINEMATIC)


class VideoCreateRequest(BaseModel):
    """创建视频请求模型"""
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(default="")
    slides: List[SlideRequest] = Field(..., min_length=1, max_length=20)
    config: VideoConfigRequest


class TTSRequest(BaseModel):
    """语音合成请求模型"""
    text: str = Field(..., min_length=1, max_length=5000)
    voice_type: VoiceType = Field(default=VoiceType.STANDARD_FEMALE)
    speed: float = Field(default=1.0, ge=0.5, le=2.0)


# ========== 响应模型 ==========

class BaseResponse(BaseModel):
    """基础响应模型"""
    success: bool
    message: Optional[str] = None


class TTSResponse(BaseResponse):
    """语音合成响应"""
    data: dict = Field(default_factory=dict)


class ImageExpandResponse(BaseResponse):
    """图片扩展响应"""
    data: dict = Field(default_factory=dict)


class VideoCreateResponse(BaseResponse):
    """创建视频响应"""
    data: dict = Field(default_factory=dict)


class VideoStatusResponse(BaseResponse):
    """视频状态响应"""
    data: dict = Field(default_factory=dict)


class VoiceInfo(BaseModel):
    """语音信息"""
    id: str
    name: str
    description: str


class VoiceListResponse(BaseResponse):
    """语音列表响应"""
    data: List[VoiceInfo]


# ========== 内部模型 ==========

class Slide(BaseModel):
    """幻灯片模型"""
    id: str
    image_url: str
    expanded_image_url: Optional[str] = None
    caption: str = ""
    voice_text: str = ""
    voice_url: Optional[str] = None
    duration: int = 5
    transition: str = "fade"


class VideoTask(BaseModel):
    """视频任务模型"""
    id: str
    title: str
    description: str = ""
    slides: List[Slide]
    config: VideoConfigRequest
    status: str = "pending"  # pending, expanding_images, generating_voice, composing, completed, failed
    progress: float = 0.0
    message: str = "等待处理..."
    output_url: Optional[str] = None
    error: Optional[str] = None
