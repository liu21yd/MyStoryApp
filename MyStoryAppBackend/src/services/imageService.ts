import { GoogleGenerativeAI } from '@google/generative-ai';
import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';
import { logger } from '../utils/logger';
import { storageService } from './storageService';

const genAI = new GoogleGenerativeAI(config.gemini.apiKey);

const stylePrompts: Record<string, string> = {
  cinematic: 'cinematic lighting, professional color grading, movie quality, 16:9 aspect ratio',
  anime: 'anime art style, vibrant colors, clean lines, 16:9 aspect ratio',
  realistic: 'photorealistic, natural lighting, lifelike details, 16:9 aspect ratio',
  dreamy: 'soft focus, dreamy atmosphere, pastel tones, 16:9 aspect ratio',
  vintage: 'vintage film look, warm tones, film grain, 16:9 aspect ratio',
  artistic: 'artistic interpretation, creative composition, painterly style, 16:9 aspect ratio'
};

export class ImageService {
  /**
   * 扩展图片
   */
  async expandImage(imagePath: string, style: string = 'cinematic'): Promise<string> {
    try {
      logger.info(`Expanding image: ${imagePath} with style: ${style}`);
      
      // 读取图片文件
      const imageBuffer = await fs.readFile(imagePath);
      const base64Image = imageBuffer.toString('base64');
      
      // 使用 Gemini 扩展图片
      const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp-image-generation' });
      
      const prompt = `Expand this image to fill a widescreen 16:9 frame while maintaining the main subject. 
        ${stylePrompts[style] || stylePrompts.cinematic}. 
        Keep the original content intact and seamlessly extend the edges.`;
      
      const result = await model.generateContent({
        contents: [{
          role: 'user',
          parts: [
            { text: prompt },
            { inlineData: { mimeType: 'image/jpeg', data: base64Image } }
          ]
        }],
        generationConfig: {
          responseModalities: ['Image', 'Text']
        }
      });
      
      const response = await result.response;
      
      // 提取生成的图片
      for (const part of response.candidates?.[0]?.content?.parts || []) {
        if ('inlineData' in part && part.inlineData) {
          const imageData = Buffer.from(part.inlineData.data, 'base64');
          
          // 保存扩展后的图片
          const filename = `expanded_${uuidv4()}.png`;
          const outputPath = path.join(config.storage.local.outputDir, filename);
          
          await fs.mkdir(path.dirname(outputPath), { recursive: true });
          await fs.writeFile(outputPath, imageData);
          
          // 上传到存储
          const publicUrl = await storageService.saveFile(outputPath, filename);
          
          logger.info(`Image expanded successfully: ${publicUrl}`);
          return publicUrl;
        }
      }
      
      throw new Error('No image generated from Gemini');
    } catch (error) {
      logger.error('Image expansion failed:', error);
      throw error;
    }
  }
  
  /**
   * 验证图片格式
   */
  validateImage(mimetype: string): boolean {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    return allowedTypes.includes(mimetype);
  }
}

export const imageService = new ImageService();
