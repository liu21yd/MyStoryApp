"""
视频合成服务
使用 FFmpeg 合成视频
"""

import ffmpeg
import uuid
from pathlib import Path
from typing import List, Callable, Optional

from app.config import settings
from app.core.logger import logger
from app.models.schemas import Slide, VideoConfigRequest


# 分辨率映射
RESOLUTION_MAP = {
    "480p": (854, 480),
    "720p": (1280, 720),
    "1080p": (1920, 1080),
    "2k": (2560, 1440),
    "4k": (3840, 2160)
}


class VideoService:
    """视频合成服务"""
    
    async def compose_video(
        self,
        slides: List[Slide],
        config: VideoConfigRequest,
        task_id: str,
        progress_callback: Optional[Callable[[float, str], None]] = None
    ) -> str:
        """
        合成视频
        
        Args:
            slides: 幻灯片列表
            config: 视频配置
            task_id: 任务ID
            progress_callback: 进度回调函数
            
        Returns:
            输出视频的 URL
        """
        logger.info(f"[视频] 开始合成任务: {task_id}")
        
        width, height = RESOLUTION_MAP.get(config.resolution.value, (1280, 720))
        output_filename = f"video_{task_id}.mp4"
        output_path = Path(settings.OUTPUT_DIR) / output_filename
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 步骤1: 创建每个幻灯片的视频片段
        if progress_callback:
            await progress_callback(0.1, "准备素材...")
        
        slide_videos = []
        for i, slide in enumerate(slides):
            slide_video = await self._create_slide_video(
                slide, width, height, config, i, task_id
            )
            slide_videos.append(slide_video)
            
            progress = 0.1 + (0.4 * (i + 1) / len(slides))
            if progress_callback:
                await progress_callback(progress, f"处理幻灯片 {i+1}/{len(slides)}...")
        
        # 步骤2: 合并所有片段
        if progress_callback:
            await progress_callback(0.5, "合并视频片段...")
        
        merged_path = await self._merge_videos(slide_videos, task_id)
        
        # 步骤3: 添加背景音乐（可选）
        if config.background_music and config.background_music != "none":
            if progress_callback:
                await progress_callback(0.7, "添加背景音乐...")
            final_path = await self._add_background_music(
                merged_path, config.background_music, task_id
            )
        else:
            final_path = merged_path
        
        # 移动最终文件
        import shutil
        shutil.move(str(final_path), str(output_path))
        
        # 清理临时文件
        await self._cleanup_temp_files(slide_videos)
        
        if progress_callback:
            await progress_callback(1.0, "完成！")
        
        logger.info(f"[视频] 合成完成: {output_path}")
        return f"/output/{output_filename}"
    
    async def _create_slide_video(
        self,
        slide: Slide,
        width: int,
        height: int,
        config: VideoConfigRequest,
        index: int,
        task_id: str
    ) -> Path:
        """创建单个幻灯片视频"""
        image_path = slide.expanded_image_url or slide.image_url
        
        # 如果是网络图片，先下载
        if image_path.startswith("http"):
            image_path = await self._download_image(image_path, task_id, index)
        
        output_path = Path(settings.OUTPUT_DIR) / f"temp_{task_id}_slide_{index}.mp4"
        
        # 构建字幕滤镜
        subtitle_filter = ""
        if config.subtitle_enabled and slide.caption:
            y_position = self._get_subtitle_y_position(config.subtitle_position, height)
            # 使用 drawtext 添加字幕
            subtitle_filter = f",drawtext=text='{slide.caption}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y={y_position}:box=1:boxcolor=black@0.5:boxborderw=10"
        
        # 使用 FFmpeg 生成视频
        try:
            (
                ffmpeg
                .input(image_path, loop=1, t=slide.duration)
                .filter('fps', fps=config.frame_rate)
                .filter('scale', width, height, force_original_aspect_ratio='decrease')
                .filter('pad', width, height, '(ow-iw)/2', '(oh-ih)/2')
                .filter('fade', type='in', start_time=0, duration=0.5)
                .filter('fade', type='out', start_time=slide.duration-0.5, duration=0.5)
                .output(
                    str(output_path),
                    vcodec='libx264',
                    pix_fmt='yuv420p',
                    **{'vf': f'fps={config.frame_rate},scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,fade=t=in:st=0:d=0.5,fade=t=out:st={slide.duration-0.5}:d=0.5'}
                )
                .run(overwrite_output=True, quiet=True)
            )
        except ffmpeg.Error as e:
            logger.error(f"FFmpeg 错误: {e.stderr}")
            raise
        
        return output_path
    
    async def _merge_videos(self, video_paths: List[Path], task_id: str) -> Path:
        """合并视频片段"""
        # 创建 concat 列表文件
        list_path = Path(settings.OUTPUT_DIR) / f"temp_{task_id}_list.txt"
        with open(list_path, 'w') as f:
            for path in video_paths:
                f.write(f"file '{path}'\n")
        
        output_path = Path(settings.OUTPUT_DIR) / f"temp_{task_id}_merged.mp4"
        
        try:
            (
                ffmpeg
                .input(str(list_path), format='concat', safe=0)
                .output(str(output_path), c='copy')
                .run(overwrite_output=True, quiet=True)
            )
        except ffmpeg.Error as e:
            logger.error(f"FFmpeg 合并错误: {e.stderr}")
            raise
        finally:
            # 删除列表文件
            list_path.unlink(missing_ok=True)
        
        return output_path
    
    async def _add_background_music(
        self,
        video_path: Path,
        bgm_type: str,
        task_id: str
    ) -> Path:
        """添加背景音乐"""
        # TODO: 实现背景音乐混音
        # 目前直接返回原视频
        return video_path
    
    async def _download_image(self, url: str, task_id: str, index: int) -> str:
        """下载网络图片"""
        import httpx
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=30.0)
            response.raise_for_status()
            
            # 保存图片
            ext = url.split('.')[-1].split('?')[0] or 'jpg'
            if ext not in ['jpg', 'jpeg', 'png', 'webp']:
                ext = 'jpg'
            
            image_path = Path(settings.OUTPUT_DIR) / f"temp_{task_id}_img_{index}.{ext}"
            image_path.write_bytes(response.content)
            
            return str(image_path)
    
    def _get_subtitle_y_position(self, position: str, video_height: int) -> int:
        """获取字幕 Y 坐标"""
        positions = {
            "top": 0.15,
            "center": 0.5,
            "bottom": 0.85
        }
        return int(positions.get(position, 0.85) * video_height)
    
    async def _cleanup_temp_files(self, files: List[Path]):
        """清理临时文件"""
        for file in files:
            try:
                file.unlink(missing_ok=True)
            except Exception as e:
                logger.warning(f"清理临时文件失败: {file}, {e}")


# 单例
video_service = VideoService()
