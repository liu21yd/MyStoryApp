import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';
import { logger } from '../utils/logger';
import { storageService } from './storageService';
import FormData from 'form-data';
import axios from 'axios';

// 百炼 API 配置
const BAILIAN_BASE_URL = 'https://dashscope.aliyuncs.com/api/v1';

// 风格映射到百炼的提示词
const stylePrompts: Record<string, string> = {
  cinematic: '电影感，专业调色，电影质感，16:9宽屏比例',
  anime: '动漫风格，鲜艳色彩，二次元画风，16:9宽屏比例',
  realistic: '写实风格，自然光影，逼真细节，16:9宽屏比例',
  dreamy: '梦幻风格，柔和色调，朦胧美感，16:9宽屏比例',
  vintage: '复古胶片风格，暖色调，怀旧感，16:9宽屏比例',
  artistic: '艺术风格，创意构图，绘画感，16:9宽屏比例'
};

export class BailianImageService {
  private apiKey: string;
  
  constructor() {
    this.apiKey = process.env.BAILIAN_API_KEY || '';
  }
  
  /**
   * 使用百炼通义万相扩展图片
   * API文档: https://help.aliyun.com/document_detail/2589141.html
   */
  async expandImage(imagePath: string, style: string = 'cinematic'): Promise<string> {
    try {
      logger.info(`[百炼] 扩展图片: ${imagePath}, 风格: ${style}`);
      
      // 读取并转换图片为 base64
      const imageBuffer = await fs.readFile(imagePath);
      const base64Image = imageBuffer.toString('base64');
      
      const stylePrompt = stylePrompts[style] || stylePrompts.cinematic;
      
      // 调用百炼图像生成 API（以参考图为基础生成）
      const response = await axios.post(
        `${BAILIAN_BASE_URL}/services/aigc/text2image/image-synthesis`,
        {
          model: 'wanx-v1',  // 通义万相
          input: {
            prompt: `基于参考图创建16:9宽屏版本，保持主体内容完整。风格：${stylePrompt}`,
            ref_image: base64Image,
            size: '1280*720',  // 16:9 高清
            n: 1
          },
          parameters: {
            style: '<auto>',
            seed: Math.floor(Math.random() * 1000000)
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            'X-DashScope-Async': 'enable'  // 启用异步模式
          }
        }
      );
      
      const taskId = response.data.output?.task_id;
      if (!taskId) {
        throw new Error('Failed to get task_id from Bailian');
      }
      
      // 轮询获取结果
      const imageUrl = await this.pollTaskResult(taskId);
      
      // 下载图片到本地
      const expandedPath = await this.downloadImage(imageUrl);
      
      // 上传并返回 URL
      const filename = `expanded_${uuidv4()}.png`;
      const publicUrl = await storageService.saveFile(expandedPath, filename);
      
      logger.info(`[百炼] 图片扩展成功: ${publicUrl}`);
      return publicUrl;
      
    } catch (error) {
      logger.error('[百炼] 图片扩展失败:', error);
      throw error;
    }
  }
  
  /**
   * 轮询任务结果
   */
  private async pollTaskResult(taskId: string, maxAttempts: number = 30): Promise<string> {
    const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
    
    for (let i = 0; i < maxAttempts; i++) {
      await delay(2000); // 等待2秒
      
      const response = await axios.get(
        `${BAILIAN_BASE_URL}/tasks/${taskId}`,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`
          }
        }
      );
      
      const taskStatus = response.data.output?.task_status;
      
      if (taskStatus === 'SUCCEEDED') {
        const results = response.data.output?.results;
        if (results && results.length > 0) {
          return results[0].url;
        }
        throw new Error('No image URL in results');
      }
      
      if (taskStatus === 'FAILED') {
        const errorMessage = response.data.output?.message || 'Unknown error';
        throw new Error(`Task failed: ${errorMessage}`);
      }
      
      // 继续轮询 (PENDING / RUNNING)
      logger.info(`[百炼] 任务 ${taskId} 状态: ${taskStatus}, 第 ${i + 1} 次查询...`);
    }
    
    throw new Error('Polling timeout');
  }
  
  /**
   * 下载图片
   */
  private async downloadImage(url: string): Promise<string> {
    const response = await axios.get(url, { responseType: 'arraybuffer' });
    const filename = `download_${uuidv4()}.png`;
    const outputPath = path.join(config.storage.local.outputDir, filename);
    
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, response.data);
    
    return outputPath;
  }
  
  /**
   * 验证图片格式
   */
  validateImage(mimetype: string): boolean {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    return allowedTypes.includes(mimetype);
  }
}

export const bailianImageService = new BailianImageService();
