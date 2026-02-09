# API 配置指南

## 可灵 AI API (推荐)

### 1. 注册账号
访问 [可灵AI官网](https://klingai.com/) 注册开发者账号

### 2. 获取 API Key
1. 登录控制台
2. 进入"密钥管理"
3. 创建新的 API Key
4. 复制保存（注意：只会显示一次）

### 3. 配置到 App
在 `VideoGenerationService.swift` 中替换：
```swift
private let apiKey = "tvly-your-actual-api-key"
```

或在应用设置页面粘贴。

### 4. API 文档参考
- 官方文档: https://klingai.com/docs
- 支持的模型: kling-v1-6, kling-video-v2-1-master

## 即梦 AI API

### 1. 申请权限
访问 [即梦AI](https://dreamina.jianying.com/)
目前API主要面向企业用户，需要申请开通。

### 2. 配置方式
与可灵类似，修改：
```swift
private let baseURL = "https://api.dreamina.com/v1"
private let apiKey = "your-dreamina-api-key"
```

## Runway ML API

### 1. 获取 API Key
1. 访问 [Runway ML](https://runwayml.com/)
2. 注册账号
3. 进入 API 页面获取 Key

### 2. 价格参考
- 可灵AI: 约 ¥0.1-0.5/秒
- 即梦AI: 约 ¥0.1-0.3/秒
- Runway: $0.01-0.05/秒

## 免费额度

各平台通常提供一定的免费额度：
- 可灵: 新用户约 1000 积分（约10-20个短视频）
- 即梦: 每日免费额度
- Runway: 试用额度

## 故障排查

### 429 错误 (Too Many Requests)
- 超过速率限制，稍后再试
- 或升级付费套餐

### 401 错误 (Unauthorized)
- API Key 错误或未激活
- 检查 Key 是否正确

### 余额不足
- 充值 API 额度
- 或更换其他 API

---
**注意**: API Key 是敏感信息，不要提交到 GitHub！
