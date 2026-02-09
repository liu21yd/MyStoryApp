import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';
import { config } from '../config';
import { logger } from '../utils/logger';
import { storageService } from './storageService';

// 百炼 API 配置
const BAILIAN_BASE_URL = 'https://dashscope.aliyuncs.com/api/v1';

// 语音类型映射
const voiceMap: Record<string, string> = {
  standardFemale: 'zhitian',      // 知甜-温柔女声
  standardMale: 'zhizhe',         // 知哲-标准男声
  gentleFemale: 'zhishu',         // 知树-柔和女声
  deepMale: 'zhida',              // 知达-磁性男声
  child: 'zhimiao',               // 知妙-童声
  cartoon: 'zhifei'               // 知飞-活泼女声
};

// 语速映射 (百炼用 scale 参数，范围 0.5-2.0)
const speedMap: Record<number, number> = {
  0.5: 0.5,
  0.75: 0.75,
  1.0: 1.0,
  1.25: 1.25,
  1.5: 1.5,
  2.0: 2.0
};

export class BailianTTSService {
  private apiKey: string;
  
  constructor() {
    this.apiKey = process.env.BAILIAN_API_KEY || '';
  }
  
  /**
   * 使用百炼语音合成生成语音
   * API文档: https://help.aliyun.com/document_detail/2589141.html
   */
  async generateSpeech(
    text: string,
    voiceType: string = 'standardFemale',
    speed: number = 1.0
  ): Promise<{ url: string; duration: number }> {
    try {
      logger.info(`[百炼] 生成语音: "${text.substring(0, 30)}..."`);
      
      const voice = voiceMap[voiceType] || voiceMap.standardFemale;
      const speedValue = speedMap[speed] || 1.0;
      
      // 调用百炼 Sambert 语音合成 API
      const response = await axios.post(
        `${BAILIAN_BASE_URL}/services/aigc/tts`,
        {
          model: 'sambert-zhimao-v1',  // 使用默认中文模型
          input: {
            text: text
          },
          parameters: {
            voice: voice,
            speech_rate: speedValue,
            pitch_rate: 1.0,
            volume: 50,
            format: 'mp3'
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          responseType: 'arraybuffer'  // 直接获取音频二进制数据
        }
      );
      
      // 保存音频文件
      const filename = `tts_${uuidv4()}.mp3`;
      const outputPath = path.join(config.storage.local.outputDir, filename);
      
      await fs.mkdir(path.dirname(outputPath), { recursive: true });
      await fs.writeFile(outputPath, response.data);
      
      // 估算时长 (中文字符约每秒5个)
      const estimatedDuration = text.length / 5;
      
      // 上传并返回 URL
      const publicUrl = await storageService.saveFile(outputPath, filename);
      
      logger.info(`[百炼] 语音生成成功: ${publicUrl}, 预估时长: ${estimatedDuration}s`);
      
      return {
        url: publicUrl,
        duration: estimatedDuration
      };
      
    } catch (error) {
      logger.error('[百炼] 语音合成失败:', error);
      throw error;
    }
  }
  
  /**
   * 长文本语音合成（异步）
   * 用于超过 300 字符的长文本
   */
  async generateSpeechAsync(
    text: string,
    voiceType: string = 'standardFemale',
    speed: number = 1.0
  ): Promise<{ url: string; duration: number }> {
    try {
      logger.info(`[百炼] 异步长文本语音合成: "${text.substring(0, 30)}..."`);
      
      const voice = voiceMap[voiceType] || voiceMap.standardFemale;
      const speedValue = speedMap[speed] || 1.0;
      
      // 调用异步接口
      const response = await axios.post(
        `${BAILIAN_BASE_URL}/services/aigc/tts/async`,
        {
          model: 'sambert-zhimao-v1',
          input: {
            text: text
          },
          parameters: {
            voice: voice,
            speech_rate: speedValue,
            format: 'mp3'
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          }
        }
      );
      
      const taskId = response.data.output?.task_id;
      if (!taskId) {
        throw new Error('Failed to get task_id');
      }
      
      // 轮询获取结果
      const audioUrl = await this.pollTaskResult(taskId);
      
      // 下载音频
      const audioPath = await this.downloadAudio(audioUrl);
      
      // 保存并返回
      const filename = `tts_${uuidv4()}.mp3`;
      const publicUrl = await storageService.saveFile(audioPath, filename);
      
      const estimatedDuration = text.length / 5;
      
      return {
        url: publicUrl,
        duration: estimatedDuration
      };
      
    } catch (error) {
      logger.error('[百炼] 异步语音合成失败:', error);
      throw error;
    }
  }
  
  /**
   * 轮询任务结果
   */
  private async pollTaskResult(taskId: string, maxAttempts: number = 30): Promise<string> {
    const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
    
    for (let i = 0; i < maxAttempts; i++) {
      await delay(2000);
      
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
        const audioUrl = response.data.output?.audio_address;
        if (audioUrl) {
          return audioUrl;
        }
        throw new Error('No audio URL in results');
      }
      
      if (taskStatus === 'FAILED') {
        const errorMessage = response.data.output?.message || 'Unknown error';
        throw new Error(`Task failed: ${errorMessage}`);
      }
      
      logger.info(`[百炼] TTS任务 ${taskId} 状态: ${taskStatus}, 第 ${i + 1} 次查询...`);
    }
    
    throw new Error('Polling timeout');
  }
  
  /**
   * 下载音频文件
   */
  private async downloadAudio(url: string): Promise<string> {
    const response = await axios.get(url, { responseType: 'arraybuffer' });
    const filename = `download_${uuidv4()}.mp3`;
    const outputPath = path.join(config.storage.local.outputDir, filename);
    
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, response.data);
    
    return outputPath;
  }
  
  /**
   * 获取支持的语音列表
   */
  getSupportedVoices(): { id: string; name: string; description: string }[] {
    return [
      { id: 'standardFemale', name: '知甜', description: '温柔女声，适合温柔的故事讲述' },
      { id: 'standardMale', name: '知哲', description: '标准男声，清晰稳重' },
      { id: 'gentleFemale', name: '知树', description: '柔和女声，亲切自然' },
      { id: 'deepMale', name: '知达', description: '磁性男声，低沉有磁性' },
      { id: 'child', name: '知妙', description: '童声，活泼可爱' },
      { id: 'cartoon', name: '知飞', description: '活泼女声，轻快生动' }
    ];
  }
}

export const bailianTTSService = new BailianTTSService();
