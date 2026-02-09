import { Request, Response, NextFunction } from 'express';
import { RateLimiterRedis } from 'rate-limiter-flexible';
import Redis from 'ioredis';
import { config } from '../config';
import { logger } from '../utils/logger';

const redisClient = new Redis(config.redis.url);

const rateLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  keyPrefix: 'middleware',
  points: config.rateLimit.maxRequests,
  duration: config.rateLimit.windowMs / 1000,
});

export const rateLimiterMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    await rateLimiter.consume(req.ip || 'unknown');
    next();
  } catch (rejRes) {
    logger.warn(`Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      success: false,
      error: {
        message: 'Too many requests, please try again later.',
        retryAfter: Math.round((rejRes as any).msBeforeNext / 1000)
      }
    });
  }
};

export { rateLimiterMiddleware as rateLimiter };
