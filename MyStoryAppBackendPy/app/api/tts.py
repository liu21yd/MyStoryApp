"""
语音合成 API
"""

from fastapi import APIRouter, HTTPException

from app.models.schemas import TTSRequest, TTSResponse, VoiceListResponse, VoiceInfo
from app.services.bailian_tts import bailian_tts_service
from app.core.logger import logger

router = APIRouter()


@router.post("/generate", response_model=TTSResponse)
async def generate_speech(request: TTSRequest):
    """
    生成语音
    
    - **text**: 要合成的文字 (1-5000字)
    - **voice_type**: 语音类型
    - **speed**: 语速 (0.5-2.0)
    """
    try:
        result = await bailian_tts_service.generate_speech(
            request.text,
            request.voice_type.value,
            request.speed
        )
        
        return TTSResponse(
            success=True,
            data={
                "audio_url": result["url"],
                "duration": result["duration"]
            }
        )
        
    except Exception as e:
        logger.exception("语音合成失败")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/voices", response_model=VoiceListResponse)
async def list_voices():
    """获取支持的语音列表"""
    voices = bailian_tts_service.get_voices()
    voice_list = [VoiceInfo(**v) for v in voices]
    
    return VoiceListResponse(success=True, data=voice_list)
