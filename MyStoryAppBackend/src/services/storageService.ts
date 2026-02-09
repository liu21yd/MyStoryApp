import fs from 'fs/promises';
import path from 'path';
import { config } from '../config';
import { logger } from '../utils/logger';

export class StorageService {
  /**
   * 保存文件并返回访问URL
   */
  async saveFile(filePath: string, filename: string): Promise<string> {
    if (config.storage.type === 's3') {
      return this.saveToS3(filePath, filename);
    } else {
      return this.saveLocal(filePath, filename);
    }
  }
  
  /**
   * 本地存储
   */
  private async saveLocal(filePath: string, filename: string): Promise<string> {
    // 文件已经在本地目录，直接返回URL
    const relativePath = `/output/${filename}`;
    return `${this.getBaseUrl()}${relativePath}`;
  }
  
  /**
   * S3 存储
   */
  private async saveToS3(filePath: string, filename: string): Promise<string> {
    // 这里应该实现 S3 上传逻辑
    // 简化实现，返回本地URL
    logger.warn('S3 storage not implemented, using local storage');
    return this.saveLocal(filePath, filename);
  }
  
  /**
   * 获取文件URL
   */
  getFileUrl(filename: string): string {
    return `${this.getBaseUrl()}/output/${filename}`;
  }
  
  /**
   * 删除文件
   */
  async deleteFile(filename: string): Promise<void> {
    const filePath = path.join(config.storage.local.outputDir, filename);
    try {
      await fs.unlink(filePath);
      logger.info(`File deleted: ${filePath}`);
    } catch (error) {
      logger.warn(`Failed to delete file: ${filePath}`);
    }
  }
  
  /**
   * 获取基础URL
   */
  private getBaseUrl(): string {
    return process.env.BASE_URL || `http://localhost:${config.port}`;
  }
}

export const storageService = new StorageService();
