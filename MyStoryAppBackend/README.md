# MyStoryApp Backend

MyStoryApp 后端服务 - PPT 视频生成 API

## 功能特性

- 🖼️ **AI 图片扩展** - 使用 Gemini AI 扩展图片
- 🗣️ **TTS 配音** - Azure 语音合成
- 🎬 **视频合成** - FFmpeg 视频处理
- 📦 **任务队列** - Redis + Bull 异步处理
- 📁 **文件存储** - 本地/S3 存储支持

## 快速开始

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env` 并填写：

```bash
cp .env.example .env
```

### 3. 启动服务

开发模式：
```bash
npm run dev
```

生产模式：
```bash
npm run build
npm start
```

## API 文档

### 基础信息

- Base URL: `http://localhost:3000/api/v1`
- 所有响应格式: `application/json`

### 接口列表

#### 1. 图片扩展

```http
POST /api/v1/image/expand
Content-Type: multipart/form-data

image: File (required)
style: string (optional, default: "cinematic")
```

**Response:**
```json
{
  "success": true,
  "data": {
    "expandedImageUrl": "https://...",
    "taskId": "uuid"
  }
}
```

#### 2. 文字转语音

```http
POST /api/v1/tts/generate
Content-Type: application/json

{
  "text": "要转换的文字",
  "voiceType": "standardFemale",
  "speed": 1.0
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "audioUrl": "https://...",
    "duration": 5.2
  }
}
```

#### 3. 创建视频任务

```http
POST /api/v1/video/create
Content-Type: application/json

{
  "title": "视频标题",
  "slides": [
    {
      "imageUrl": "https://...",
      "caption": "字幕文字",
      "voiceText": "配音文字",
      "duration": 5,
      "transition": "fade"
    }
  ],
  "config": {
    "resolution": "1080p",
    "voiceType": "standardFemale",
    "backgroundMusic": "gentle",
    "subtitleEnabled": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "taskId": "uuid",
    "status": "pending",
    "estimatedTime": 60
  }
}
```

#### 4. 查询任务状态

```http
GET /api/v1/video/status/:taskId
```

**Response:**
```json
{
  "success": true,
  "data": {
    "taskId": "uuid",
    "status": "processing",
    "progress": 0.5,
    "message": "生成配音中...",
    "outputUrl": null
  }
}
```

#### 5. 获取视频结果

```http
GET /api/v1/video/result/:taskId
```

**Response:**
```json
{
  "success": true,
  "data": {
    "taskId": "uuid",
    "status": "completed",
    "videoUrl": "https://...",
    "thumbnailUrl": "https://...",
    "duration": 30
  }
}
```

## 环境变量

| 变量名 | 说明 | 必填 |
|--------|------|------|
| `PORT` | 服务端口 | 否 (默认3000) |
| `NODE_ENV` | 环境模式 | 否 |
| `REDIS_URL` | Redis 连接地址 | 是 |
| `BAILIAN_API_KEY` | **阿里云百炼 API Key** ⭐️ | **是** |
| `GEMINI_API_KEY` | Gemini AI API Key | 否 (备用) |
| `AZURE_TTS_KEY` | Azure TTS Key | 否 (备用) |
| `AZURE_TTS_REGION` | Azure TTS 区域 | 否 |
| `AWS_ACCESS_KEY_ID` | AWS S3 Key | 否 |
| `AWS_SECRET_ACCESS_KEY` | AWS S3 Secret | 否 |
| `AWS_S3_BUCKET` | S3 Bucket 名称 | 否 |
| `STORAGE_TYPE` | 存储类型 (local/s3) | 否 (默认local) |

### 百炼 API Key 获取

1. 访问 [阿里云百炼](https://dashscope.aliyun.com/)
2. 登录阿里云账号
3. 进入「API-KEY 管理」创建新 Key
4. 开通以下服务：
   - 通义万相（图像生成）
   - Sambert 语音合成

## 项目结构

```
MyStoryAppBackend/
├── src/
│   ├── index.ts              # 应用入口
│   ├── config/               # 配置文件
│   ├── routes/               # API 路由
│   │   ├── image.ts          # 图片扩展
│   │   ├── tts.ts            # 语音合成
│   │   └── video.ts          # 视频生成
│   ├── services/             # 业务逻辑
│   │   ├── imageService.ts   # 图片处理
│   │   ├── ttsService.ts     # TTS 服务
│   │   ├── videoService.ts   # 视频合成
│   │   └── storageService.ts # 文件存储
│   ├── models/               # 数据模型
│   ├── middleware/           # 中间件
│   └── utils/                # 工具函数
├── uploads/                  # 上传文件目录
├── output/                   # 输出文件目录
├── package.json
├── tsconfig.json
└── README.md
```

## 部署

### Docker 部署

```bash
docker build -t mystoryapp-backend .
docker run -p 3000:3000 --env-file .env mystoryapp-backend
```

### 服务器要求

- Node.js >= 18
- Redis >= 6
- FFmpeg >= 5.0
- 内存 >= 2GB
- 磁盘 >= 10GB

## License

MIT
