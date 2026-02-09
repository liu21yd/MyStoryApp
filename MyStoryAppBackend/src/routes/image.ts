import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { body } from 'express-validator';
import { config } from '../config';
import { imageService } from '../services/imageService';
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
    if (imageService.validateImage(file.mimetype)) {
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
    
    // 异步处理
    const processImage = async () => {
      try {
        const expandedUrl = await imageService.expandImage(req.file!.path, style);
        return { taskId, expandedImageUrl: expandedUrl };
      } catch (error) {
        logger.error('Image expansion error:', error);
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
    const isValid = imageService.validateImage(mimetype);
    
    res.json({
      success: true,
      data: { valid: isValid }
    });
  })
);

export default router;
