# MyStoryApp 端到端测试指南

## 🚀 快速开始

### 1. 启动后端服务

```bash
cd MyStoryApp/MyStoryAppBackend

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env，填入 BAILIAN_API_KEY

# 启动 Redis (新终端)
redis-server

# 启动后端服务 (新终端)
npm run dev
```

服务启动后会显示：
```
🚀 Server running on port 3000
📁 Upload directory: .../uploads
📁 Output directory: .../output
```

### 2. 测试后端 API

#### 方法 A: 浏览器可视化测试 (推荐)

直接打开 `api-test.html` 文件：

```bash
# 在项目根目录
open api-test.html
```

或拖拽文件到浏览器。

这个页面可以：
- ✅ 测试服务器连接
- 🎤 测试语音合成（可试听）
- 🖼️ 测试图片扩展
- 🎬 测试视频生成（可预览）

#### 方法 B: 命令行自动测试

```bash
cd MyStoryApp/MyStoryAppBackend/test

# 安装测试依赖
npm install

# 运行测试
npm test
```

### 3. 测试 iOS 客户端

#### 使用 Xcode 模拟器

```bash
# 在项目根目录
open MyStoryApp/MyStoryApp.xcodeproj
```

或在 Xcode 中打开项目，选择模拟器运行。

#### 配置 API 地址

在 `MyStoryApp/Services/PPTVideoAPIService.swift` 中：

```swift
// 如果使用模拟器，使用 localhost
init(baseURL: String = "http://localhost:3000/api/v1")

// 如果使用真机，使用电脑 IP
init(baseURL: String = "http://192.168.x.x:3000/api/v1")
```

### 4. 测试流程

1. **打开 PPT视频 Tab**
2. **添加幻灯片**
   - 点击右上角「+」
   - 选择照片
3. **编辑幻灯片**
   - 添加字幕
   - 输入配音文本
   - 设置时长
4. **配置视频**
   - 选择分辨率
   - 选择配音角色
   - 开启字幕
5. **生成视频**
   - 点击「生成视频」
   - 等待进度完成
   - 预览生成的视频

## 🧪 API 测试示例

### 健康检查
```bash
curl http://localhost:3000/health
```

### 语音合成
```bash
curl -X POST http://localhost:3000/api/v1/tts/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "欢迎使用我的故事应用",
    "voiceType": "standardFemale",
    "speed": 1.0
  }'
```

### 图片扩展
```bash
curl -X POST http://localhost:3000/api/v1/image/expand \
  -F "image=@test-image.jpg" \
  -F "style=cinematic"
```

### 创建视频任务
```bash
curl -X POST http://localhost:3000/api/v1/video/create \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试视频",
    "slides": [{
      "imageUrl": "https://picsum.photos/1280/720",
      "caption": "测试",
      "voiceText": "这是测试",
      "duration": 5,
      "transition": "fade"
    }],
    "config": {
      "resolution": "720p",
      "voiceType": "standardFemale",
      "subtitleEnabled": true
    }
  }'
```

### 查询任务状态
```bash
curl http://localhost:3000/api/v1/video/status/{taskId}
```

## 📋 测试清单

### 后端 API
- [ ] 健康检查通过
- [ ] 语音列表获取
- [ ] TTS 生成成功
- [ ] 图片扩展成功
- [ ] 视频任务创建
- [ ] 任务状态查询
- [ ] 视频结果获取

### iOS 客户端
- [ ] 添加幻灯片
- [ ] 编辑幻灯片
- [ ] 图片上传
- [ ] 视频生成流程
- [ ] 进度显示
- [ ] 视频预览
- [ ] 视频分享

## 🔧 故障排除

### 后端无法启动

```bash
# 检查 Redis
redis-cli ping  # 应该返回 PONG

# 检查端口占用
lsof -i :3000

# 检查环境变量
cat .env | grep BAILIAN
```

### API 返回错误

```bash
# 查看日志
tail -f MyStoryAppBackend/logs/error.log

# 检查百炼 API Key 是否有效
curl -H "Authorization: Bearer $BAILIAN_API_KEY" \
  https://dashscope.aliyuncs.com/api/v1/models
```

### iOS 无法连接后端

1. 确保电脑和手机在同一 WiFi
2. 使用电脑 IP 而非 localhost
3. 检查防火墙设置
4. 在 Xcode 中查看网络日志

## 📊 预期结果

| 功能 | 预期时间 | 成功率 |
|------|----------|--------|
| TTS 生成 | 1-3 秒 | >95% |
| 图片扩展 | 10-30 秒 | >90% |
| 视频生成 (2页) | 30-60 秒 | >85% |

## 📝 反馈

测试完成后请记录：
1. 成功的功能
2. 失败的功能及错误信息
3. 改进建议
