import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { body } from 'express-validator';
import { config } from '../config';
import { bailianImageService } from '../services/bailianImageService';
import { taskService } from '../services/taskService';
import { asyncHandler } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// 文件上传配置
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, config.storage.local.uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (bailianImageService.validateImage(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only images are allowed.'));
    }
  }
});

/**
 * POST /api/v1/image/expand
 * 扩展图片
 */
router.post(
  '/expand',
  upload.single('image'),
  body('style').optional().isString(),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: { message: 'No image file provided' }
      });
    }
    
    const style = req.body.style || 'cinematic';
    const taskId = uuidv4();
    
    // 异步处理 - 使用百炼通义万相
    const processImage = async () => {
      try {
        const expandedUrl = await bailianImageService.expandImage(req.file!.path, style);
        return { taskId, expandedImageUrl: expandedUrl };
      } catch (error) {
        logger.error('百炼图片扩展错误:', error);
        throw error;
      }
    };
    
    const result = await processImage();
    
    res.json({
      success: true,
      data: result
    });
  })
);

/**
 * POST /api/v1/image/validate
 * 验证图片格式
 */
router.post(
  '/validate',
  asyncHandler(async (req, res) => {
    const { mimetype } = req.body;
    const isValid = bailianImageService.validateImage(mimetype);
    
    res.json({
      success: true,
      data: { valid: isValid }
    });
  })
);

export default router;
