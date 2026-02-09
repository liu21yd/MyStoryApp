import { Router } from 'express';
import { body } from 'express-validator';
import { v4 as uuidv4 } from 'uuid';
import { VideoTask, VideoConfig } from '../models';
import { taskService, videoQueue } from '../services/taskService';
import { asyncHandler } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { config } from '../config';

const router = Router();

/**
 * POST /api/v1/video/create
 * 创建视频生成任务
 */
router.post(
  '/create',
  body('title').isString().isLength({ min: 1, max: 100 }),
  body('slides').isArray({ min: 1, max: config.video.maxSlides }),
  body('config').isObject(),
  asyncHandler(async (req, res) => {
    const { title, description = '', slides, config: videoConfig } = req.body;
    
    const taskId = uuidv4();
    const task: VideoTask = {
      id: taskId,
      title,
      description,
      slides,
      config: videoConfig as VideoConfig,
      status: 'pending',
      progress: 0,
      message: '等待处理...',
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    // 添加到队列
    await taskService.enqueueTask(task);
    
    // 估算处理时间 (每页约10秒)
    const estimatedTime = slides.length * 10;
    
    res.json({
      success: true,
      data: {
        taskId,
        status: 'pending',
        estimatedTime
      }
    });
  })
);

/**
 * GET /api/v1/video/status/:taskId
 * 查询任务状态
 */
router.get(
  '/status/:taskId',
  asyncHandler(async (req, res) => {
    const { taskId } = req.params;
    
    const task = await taskService.getTask(taskId);
    
    if (!task) {
      return res.status(404).json({
        success: false,
        error: { message: 'Task not found' }
      });
    }
    
    res.json({
      success: true,
      data: {
        taskId: task.id,
        status: task.status,
        progress: task.progress,
        message: task.message,
        outputUrl: task.outputUrl,
        error: task.error
      }
    });
  })
);

/**
 * GET /api/v1/video/result/:taskId
 * 获取视频结果
 */
router.get(
  '/result/:taskId',
  asyncHandler(async (req, res) => {
    const { taskId } = req.params;
    
    const task = await taskService.getTask(taskId);
    
    if (!task) {
      return res.status(404).json({
        success: false,
        error: { message: 'Task not found' }
      });
    }
    
    if (task.status !== 'completed') {
      return res.status(400).json({
        success: false,
        error: { 
          message: 'Video not ready',
          status: task.status,
          progress: task.progress
        }
      });
    }
    
    res.json({
      success: true,
      data: {
        taskId: task.id,
        status: task.status,
        videoUrl: task.outputUrl,
        thumbnailUrl: task.thumbnailUrl,
        createdAt: task.createdAt,
        completedAt: task.updatedAt
      }
    });
  })
);

/**
 * GET /api/v1/video/queue-status
 * 获取队列状态
 */
router.get(
  '/queue-status',
  asyncHandler(async (req, res) => {
    const [waiting, active, completed, failed] = await Promise.all([
      videoQueue.getWaitingCount(),
      videoQueue.getActiveCount(),
      videoQueue.getCompletedCount(),
      videoQueue.getFailedCount()
    ]);
    
    res.json({
      success: true,
      data: {
        waiting,
        active,
        completed,
        failed,
        total: waiting + active
      }
    });
  })
);

export default router;
