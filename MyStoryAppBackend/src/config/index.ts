export const config = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  
  // Redis
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  },
  
  // Bailian (阿里云百炼)
  bailian: {
    apiKey: process.env.BAILIAN_API_KEY || ''
  },
  
  // 保留备用配置
  gemini: {
    apiKey: process.env.GEMINI_API_KEY || ''
  },
  azureTTS: {
    key: process.env.AZURE_TTS_KEY || '',
    region: process.env.AZURE_TTS_REGION || 'eastasia'
  },
  
  // Storage
  storage: {
    type: (process.env.STORAGE_TYPE || 'local') as 'local' | 's3',
    local: {
      uploadDir: process.env.UPLOAD_DIR || './uploads',
      outputDir: process.env.OUTPUT_DIR || './output'
    },
    s3: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
      bucket: process.env.AWS_S3_BUCKET || '',
      region: process.env.AWS_REGION || 'ap-northeast-1'
    }
  },
  
  // Video Processing
  video: {
    maxSlides: 20,
    maxDuration: 300, // 最大视频时长 5分钟
    supportedResolutions: ['480p', '720p', '1080p', '2k', '4k'],
    defaultResolution: '1080p',
    frameRate: 30
  },
  
  // Rate Limiting
  rateLimit: {
    windowMs: 15 * 60 * 1000, // 15分钟
    maxRequests: 100
  }
};

// 验证必要配置
export function validateConfig(): void {
  const required = [
    'GEMINI_API_KEY',
    'AZURE_TTS_KEY',
    'AZURE_TTS_REGION'
  ];
  
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    console.warn(`⚠️  Missing environment variables: ${missing.join(', ')}`);
    console.warn('Some features may not work properly.');
  }
}
