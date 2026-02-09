import { Router } from 'express';
import { body } from 'express-validator';
import { ttsService } from '../services/ttsService';
import { asyncHandler } from '../middleware/errorHandler';

const router = Router();

/**
 * POST /api/v1/tts/generate
 * 生成语音
 */
router.post(
  '/generate',
  body('text').isString().isLength({ min: 1, max: 5000 }),
  body('voiceType').optional().isString(),
  body('speed').optional().isFloat({ min: 0.5, max: 2.0 }),
  asyncHandler(async (req, res) => {
    const { text, voiceType = 'standardFemale', speed = 1.0 } = req.body;
    
    const result = await ttsService.generateSpeech(text, voiceType, speed);
    
    res.json({
      success: true,
      data: {
        audioUrl: result.url,
        duration: result.duration
      }
    });
  })
);

/**
 * GET /api/v1/tts/voices
 * 获取支持的语音列表
 */
router.get(
  '/voices',
  asyncHandler(async (req, res) => {
    const voices = ttsService.getSupportedVoices();
    
    res.json({
      success: true,
      data: voices
    });
  })
);

export default router;
