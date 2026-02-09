import * as sdk from 'microsoft-cognitiveservices-speech-sdk';
import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';
import { logger } from '../utils/logger';
import { storageService } from './storageService';

// 语音类型映射
const voiceMap: Record<string, string> = {
  standardFemale: 'zh-CN-XiaoxiaoNeural',
  standardMale: 'zh-CN-YunjianNeural',
  gentleFemale: 'zh-CN-XiaoyiNeural',
  deepMale: 'zh-CN-YunxiNeural',
  child: 'zh-CN-XiaoshuangNeural',
  cartoon: 'zh-CN-YunyeNeural'
};

export class TTSService {
  private speechConfig: sdk.SpeechConfig;
  
  constructor() {
    this.speechConfig = sdk.SpeechConfig.fromSubscription(
      config.azureTTS.key,
      config.azureTTS.region
    );
    this.speechConfig.speechSynthesisOutputFormat = 
      sdk.SpeechSynthesisOutputFormat.Audio24Khz96KBitRateMonoMp3;
  }
  
  /**
   * 生成语音
   */
  async generateSpeech(
    text: string,
    voiceType: string = 'standardFemale',
    speed: number = 1.0
  ): Promise<{ url: string; duration: number }> {
    try {
      logger.info(`Generating TTS for text: ${text.substring(0, 50)}...`);
      
      const voiceName = voiceMap[voiceType] || voiceMap.standardFemale;
      this.speechConfig.speechSynthesisVoiceName = voiceName;
      
      // 创建合成器
      const synthesizer = new sdk.SpeechSynthesizer(this.speechConfig);
      
      // 构建 SSML
      const ssml = this.buildSSML(text, voiceName, speed);
      
      return new Promise((resolve, reject) => {
        synthesizer.speakSsmlAsync(
          ssml,
          async (result) => {
            synthesizer.close();
            
            if (result.reason === sdk.ResultReason.SynthesizingAudioCompleted) {
              // 保存音频文件
              const filename = `tts_${uuidv4()}.mp3`;
              const outputPath = path.join(config.storage.local.outputDir, filename);
              
              await fs.mkdir(path.dirname(outputPath), { recursive: true });
              await fs.writeFile(outputPath, Buffer.from(result.audioData));
              
              // 估算时长 (每秒约5个中文字符)
              const estimatedDuration = text.length / 5;
              
              // 上传到存储
              const publicUrl = await storageService.saveFile(outputPath, filename);
              
              logger.info(`TTS generated successfully: ${publicUrl}`);
              resolve({ url: publicUrl, duration: estimatedDuration });
            } else {
              reject(new Error(`TTS failed: ${result.errorDetails}`));
            }
          },
          (error) => {
            synthesizer.close();
            reject(error);
          }
        );
      });
    } catch (error) {
      logger.error('TTS generation failed:', error);
      throw error;
    }
  }
  
  /**
   * 构建 SSML
   */
  private buildSSML(text: string, voiceName: string, speed: number): string {
    const rate = Math.round(speed * 100);
    return `
      <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">
        <voice name="${voiceName}">
          <prosody rate="${rate}%">
            ${text}
          </prosody>
        </voice>
      </speak>
    `;
  }
  
  /**
   * 获取支持的语音列表
   */
  getSupportedVoices(): { id: string; name: string }[] {
    return [
      { id: 'standardFemale', name: '标准女声' },
      { id: 'standardMale', name: '标准男声' },
      { id: 'gentleFemale', name: '温柔女声' },
      { id: 'deepMale', name: '磁性男声' },
      { id: 'child', name: '童声' },
      { id: 'cartoon', name: '卡通音' }
    ];
  }
}

export const ttsService = new TTSService();
