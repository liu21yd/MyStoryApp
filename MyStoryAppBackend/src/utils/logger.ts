import winston from 'winston';
import path from 'path';

const { combine, timestamp, json, errors, printf, colorize } = winston.format;

// 开发环境格式
const devFormat = printf(({ level, message, timestamp, stack }) => {
  return `${timestamp} [${level}]: ${stack || message}`;
});

// 生产环境格式
const prodFormat = combine(
  timestamp(),
  json(),
  errors({ stack: true })
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  defaultMeta: { service: 'mystoryapp-backend' },
  transports: [
    // 控制台输出
    new winston.transports.Console({
      format: combine(
        colorize(),
        timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        process.env.NODE_ENV === 'production' ? prodFormat : devFormat
      )
    }),
    // 错误日志文件
    new winston.transports.File({
      filename: path.join(__dirname, '../../logs/error.log'),
      level: 'error',
      format: prodFormat
    }),
    // 所有日志文件
    new winston.transports.File({
      filename: path.join(__dirname, '../../logs/combined.log'),
      format: prodFormat
    })
  ]
});
