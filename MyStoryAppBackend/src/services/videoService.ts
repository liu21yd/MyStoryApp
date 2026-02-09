import ffmpeg from 'fluent-ffmpeg';
import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';
import { logger } from '../utils/logger';
import { storageService } from './storageService';
import { Slide, VideoConfig } from '../models';

// 分辨率映射
const resolutionMap: Record<string, { width: number; height: number }> = {
  '480p': { width: 854, height: 480 },
  '720p': { width: 1280, height: 720 },
  '1080p': { width: 1920, height: 1080 },
  '2k': { width: 2560, height: 1440 },
  '4k': { width: 3840, height: 2160 }
};

export class VideoService {
  /**
   * 合成视频
   */
  async composeVideo(
    slides: Slide[],
    config: VideoConfig,
    taskId: string,
    onProgress?: (progress: number, message: string) => void
  ): Promise<string> {
    try {
      logger.info(`Starting video composition for task: ${taskId}`);
      
      const resolution = resolutionMap[config.resolution] || resolutionMap['1080p'];
      const outputFilename = `video_${taskId}.mp4`;
      const outputPath = path.join(config.storage.local.outputDir, outputFilename);
      
      await fs.mkdir(path.dirname(outputPath), { recursive: true });
      
      // 步骤1: 为每个幻灯片创建视频片段
      onProgress?.(0.1, '准备素材...');
      const slideVideos: string[] = [];
      
      for (let i = 0; i < slides.length; i++) {
        const slide = slides[i];
        const slideVideoPath = await this.createSlideVideo(
          slide,
          resolution,
          config,
          i,
          taskId
        );
        slideVideos.push(slideVideoPath);
        
        const progress = 0.1 + (0.4 * (i + 1) / slides.length);
        onProgress?.(progress, `处理幻灯片 ${i + 1}/${slides.length}...`);
      }
      
      // 步骤2: 合并所有片段
      onProgress?.(0.5, '合并视频片段...');
      const mergedPath = await this.mergeVideos(slideVideos, taskId);
      
      // 步骤3: 添加背景音乐（如果需要）
      if (config.backgroundMusic && config.backgroundMusic !== 'none') {
        onProgress?.(0.7, '添加背景音乐...');
        const withBgmPath = await this.addBackgroundMusic(
          mergedPath,
          config.backgroundMusic,
          taskId
        );
        
        // 替换为带BGM的版本
        await fs.rename(withBgmPath, outputPath);
      } else {
        await fs.rename(mergedPath, outputPath);
      }
      
      // 步骤4: 上传到存储
      onProgress?.(0.9, '上传视频...');
      const publicUrl = await storageService.saveFile(outputPath, outputFilename);
      
      // 清理临时文件
      await this.cleanupTempFiles(slideVideos);
      
      onProgress?.(1.0, '完成！');
      logger.info(`Video composition completed: ${publicUrl}`);
      
      return publicUrl;
    } catch (error) {
      logger.error('Video composition failed:', error);
      throw error;
    }
  }
  
  /**
   * 创建单个幻灯片视频
   */
  private async createSlideVideo(
    slide: Slide,
    resolution: { width: number; height: number },
    config: VideoConfig,
    index: number,
    taskId: string
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      const imagePath = slide.expandedImageUrl || slide.imageUrl;
      const outputPath = path.join(
        config.storage.local.outputDir,
        `temp_${taskId}_slide_${index}.mp4`
      );
      
      // 构建字幕滤镜
      let subtitleFilter = '';
      if (config.subtitleEnabled && slide.caption) {
        const escapedCaption = slide.caption.replace(/'/g, "'\\''");
        const yPosition = this.getSubtitleYPosition(config.subtitlePosition, resolution.height);
        
        subtitleFilter = `,drawtext=text='${escapedCaption}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=${yPosition}:box=1:boxcolor=black@0.5:boxborderw=10`;
      }
      
      ffmpeg()
        .input(imagePath)
        .loop()
        .duration(slide.duration)
        .videoCodec('libx264')
        .size(`${resolution.width}x${resolution.height}`)
        .autopad()
        .fps(config.frameRate || 30)
        .videoFilters(`fade=t=in:st=0:d=0.5,fade=t=out:st=${slide.duration - 0.5}:d=0.5${subtitleFilter}`)
        .outputOptions('-pix_fmt yuv420p')
        .on('end', () => resolve(outputPath))
        .on('error', reject)
        .save(outputPath);
    });
  }
  
  /**
   * 合并视频片段
   */
  private async mergeVideos(videoPaths: string[], taskId: string): Promise<string> {
    return new Promise(async (resolve, reject) => {
      // 创建 concat 列表文件
      const listPath = path.join(
        config.storage.local.outputDir,
        `temp_${taskId}_list.txt`
      );
      
      const listContent = videoPaths.map(p => `file '${p}'`).join('\n');
      await fs.writeFile(listPath, listContent);
      
      const outputPath = path.join(
        config.storage.local.outputDir,
        `temp_${taskId}_merged.mp4`
      );
      
      ffmpeg()
        .input(listPath)
        .inputOptions('-f concat', '-safe 0')
        .videoCodec('libx264')
        .audioCodec('aac')
        .on('end', () => {
          fs.unlink(listPath).catch(() => {});
          resolve(outputPath);
        })
        .on('error', reject)
        .save(outputPath);
    });
  }
  
  /**
   * 添加背景音乐
   */
  private async addBackgroundMusic(
    videoPath: string,
    bgmType: string,
    taskId: string
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      // 这里应该使用预设的BGM文件
      // 简化实现：返回原视频
      resolve(videoPath);
    });
  }
  
  /**
   * 获取字幕Y位置
   */
  private getSubtitleYPosition(position: string, videoHeight: number): number {
    switch (position) {
      case 'top': return Math.round(videoHeight * 0.15);
      case 'center': return Math.round(videoHeight * 0.5);
      case 'bottom':
      default: return Math.round(videoHeight * 0.85);
    }
  }
  
  /**
   * 清理临时文件
   */
  private async cleanupTempFiles(files: string[]): Promise<void> {
    for (const file of files) {
      try {
        await fs.unlink(file);
      } catch (error) {
        logger.warn(`Failed to cleanup temp file: ${file}`);
      }
    }
  }
  
  /**
   * 获取视频信息
   */
  async getVideoInfo(videoPath: string): Promise<{ duration: number; width: number; height: number }> {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(videoPath, (err, metadata) => {
        if (err) {
          reject(err);
          return;
        }
        
        const videoStream = metadata.streams.find(s => s.codec_type === 'video');
        resolve({
          duration: metadata.format.duration || 0,
          width: videoStream?.width || 0,
          height: videoStream?.height || 0
        });
      });
    });
  }
}

export const videoService = new VideoService();
