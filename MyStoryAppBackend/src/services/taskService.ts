import Bull from 'bull';
import Redis from 'ioredis';
import { config } from '../config';
import { logger } from '../utils/logger';
import { VideoTask } from '../models';
import { bailianImageService } from './bailianImageService';
import { bailianTTSService } from './bailianTTSService';
import { videoService } from './videoService';

// Redis 客户端
const redisClient = new Redis(config.redis.url);

// 视频生成队列
export const videoQueue = new Bull('video-generation', {
  redis: config.redis.url,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000
    },
    removeOnComplete: 100,
    removeOnFail: 50
  }
});

// 任务状态存储
const TASK_KEY_PREFIX = 'video_task:';

export class TaskService {
  /**
   * 创建任务
   */
  async createTask(task: VideoTask): Promise<void> {
    const key = `${TASK_KEY_PREFIX}${task.id}`;
    await redisClient.setex(key, 86400, JSON.stringify(task)); // 24小时过期
  }
  
  /**
   * 获取任务
   */
  async getTask(taskId: string): Promise<VideoTask | null> {
    const key = `${TASK_KEY_PREFIX}${taskId}`;
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  }
  
  /**
   * 更新任务状态
   */
  async updateTaskStatus(
    taskId: string,
    status: VideoTask['status'],
    progress: number,
    message: string,
    outputUrl?: string,
    error?: string
  ): Promise<void> {
    const task = await this.getTask(taskId);
    if (!task) return;
    
    task.status = status;
    task.progress = progress;
    task.message = message;
    task.updatedAt = new Date();
    if (outputUrl) task.outputUrl = outputUrl;
    if (error) task.error = error;
    
    await this.createTask(task);
  }
  
  /**
   * 将任务添加到队列
   */
  async enqueueTask(task: VideoTask): Promise<void> {
    await this.createTask(task);
    
    await videoQueue.add('generate', {
      taskId: task.id,
      slides: task.slides,
      config: task.config
    });
    
    logger.info(`Task enqueued: ${task.id}`);
  }
}

export const taskService = new TaskService();

// 队列处理器
videoQueue.process('generate', 2, async (job) => {
  const { taskId, slides, config } = job.data;
  
  try {
    logger.info(`Processing video generation task: ${taskId}`);
    
    // 更新状态: 扩展图片
    await taskService.updateTaskStatus(
      taskId,
      'expanding_images',
      0.1,
      'AI扩展图片中...'
    );
    
    const processedSlides = [...slides];
    
    // 步骤1: 扩展图片 (使用百炼通义万相)
    if (config.aiImageExpansion) {
      for (let i = 0; i < processedSlides.length; i++) {
        try {
          const expandedUrl = await bailianImageService.expandImage(
            processedSlides[i].imageUrl,
            config.expansionStyle
          );
          processedSlides[i].expandedImageUrl = expandedUrl;
          
          await taskService.updateTaskStatus(
            taskId,
            'expanding_images',
            0.1 + (0.3 * (i + 1) / processedSlides.length),
            `百炼AI扩展图片 ${i + 1}/${processedSlides.length}...`
          );
        } catch (error) {
          logger.warn(`百炼图片扩展失败，使用原图: slide ${i}`);
          // 扩展失败，使用原图
        }
      }
    }
    
    // 步骤2: 生成配音 (使用百炼语音合成)
    await taskService.updateTaskStatus(
      taskId,
      'generating_voice',
      0.4,
      '百炼AI生成配音中...'
    );
    
    for (let i = 0; i < processedSlides.length; i++) {
      if (processedSlides[i].voiceText) {
        try {
          // 根据文本长度选择同步或异步接口
          const voiceText = processedSlides[i].voiceText;
          const ttsResult = voiceText.length > 300
            ? await bailianTTSService.generateSpeechAsync(voiceText, config.voiceType, config.voiceSpeed)
            : await bailianTTSService.generateSpeech(voiceText, config.voiceType, config.voiceSpeed);
          
          processedSlides[i].voiceUrl = ttsResult.url;
          
          await taskService.updateTaskStatus(
            taskId,
            'generating_voice',
            0.4 + (0.2 * (i + 1) / processedSlides.length),
            `百炼生成配音 ${i + 1}/${processedSlides.length}...`
          );
        } catch (error) {
          logger.warn(`百炼TTS失败: slide ${i}`);
        }
      }
    }
    
    // 步骤3: 合成视频
    await taskService.updateTaskStatus(
      taskId,
      'composing',
      0.6,
      '合成视频中...'
    );
    
    const videoUrl = await videoService.composeVideo(
      processedSlides,
      config,
      taskId,
      async (progress, message) => {
        await taskService.updateTaskStatus(
          taskId,
          'composing',
          0.6 + (progress * 0.4),
          message
        );
        await job.progress(0.6 + (progress * 0.4));
      }
    );
    
    // 完成
    await taskService.updateTaskStatus(
      taskId,
      'completed',
      1.0,
      '视频生成完成！',
      videoUrl
    );
    
    return { success: true, videoUrl };
  } catch (error) {
    logger.error(`Task failed: ${taskId}`, error);
    
    await taskService.updateTaskStatus(
      taskId,
      'failed',
      0,
      '视频生成失败',
      undefined,
      (error as Error).message
    );
    
    throw error;
  }
});

// 队列事件监听
videoQueue.on('completed', (job) => {
  logger.info(`Job completed: ${job.id}`);
});

videoQueue.on('failed', (job, err) => {
  logger.error(`Job failed: ${job.id}`, err);
});
