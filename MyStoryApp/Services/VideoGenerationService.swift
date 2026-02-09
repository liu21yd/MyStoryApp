//
//  VideoGenerationService.swift
//  MyStoryApp
//
//  视频生成服务 - 集成可灵/即梦等AI API
//

import Foundation
import Combine

class VideoGenerationService {
    
    // MARK: - API配置（需要替换为你的API Key）
    private let apiKey = "YOUR_KLING_API_KEY"  // 可灵API Key
    private let baseURL = "https://api.klingai.com/v1"  // 可灵API地址
    
    // 备用API配置
    private let backupAPIs: [(name: String, baseURL: String)] = [
        ("可灵", "https://api.klingai.com/v1"),
        ("即梦", "https://api.dreamina.com/v1"),
        ("Runway", "https://api.runwayml.com/v1")
    ]
    
    // MARK: - 生成视频
    func generateVideo(
        request: VideoGenerationRequest,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 步骤1: 构建提示词
        let prompt = buildPrompt(from: request)
        
        // 步骤2: 上传图片（如果有）
        uploadImagesIfNeeded(request.scenes) { [weak self] imageURLs in
            guard let self = self else { return }
            
            // 步骤3: 创建视频生成任务
            self.createVideoTask(
                prompt: prompt,
                imageURLs: imageURLs,
                style: request.style,
                duration: request.duration
            ) { result in
                switch result {
                case .success(let taskId):
                    // 步骤4: 轮询任务状态
                    self.pollTaskStatus(
                        taskId: taskId,
                        progressHandler: progressHandler,
                        completion: completion
                    )
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 构建提示词
    private func buildPrompt(from request: VideoGenerationRequest) -> String {
        var prompt = "Create a short video story with the following elements:\n\n"
        
        // 添加风格描述
        prompt += "Style: \(request.style.rawValue). "
        switch request.style {
        case .cinematic:
            prompt += "Cinematic lighting, professional color grading, smooth camera movements. "
        case .anime:
            prompt += "Anime art style, vibrant colors, dynamic compositions. "
        case .realistic:
            prompt += "Photorealistic, natural lighting, lifelike details. "
        case .dreamy:
            prompt += "Soft focus, pastel colors, ethereal atmosphere. "
        case .vintage:
            prompt += "Film grain, warm tones, nostalgic feel. "
        }
        
        // 添加场景描述
        prompt += "\n\nScenes:\n"
        for scene in request.scenes {
            prompt += "- \(scene.caption)"
            if scene.emotion != .neutral {
                prompt += " (mood: \(scene.emotion.rawValue))"
            }
            prompt += "\n"
        }
        
        // 添加时长要求
        prompt += "\nDuration: \(request.duration.displayText). "
        prompt += "Smooth transitions between scenes."
        
        return prompt
    }
    
    // MARK: - 上传图片
    private func uploadImagesIfNeeded(
        _ scenes: [Scene],
        completion: @escaping ([String]) -> Void
    ) {
        // 实际实现需要上传图片到服务器并获取URL
        // 这里简化处理
        let imageURLs = scenes.compactMap { $0.imageURL }
        completion(imageURLs)
    }
    
    // MARK: - 创建视频任务（可灵API示例）
    private func createVideoTask(
        prompt: String,
        imageURLs: [String],
        style: VideoStyle,
        duration: VideoDuration,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/videos") else {
            completion(.failure(VideoError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "image_urls": imageURLs,
            "duration": duration.rawValue,
            "aspect_ratio": "9:16",  // 竖屏视频
            "model": "kling-v1-6"    // 使用可灵V1.6模型
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(VideoError.noData))
                return
            }
            
            // 解析响应获取task_id
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let taskId = json["task_id"] as? String {
                completion(.success(taskId))
            } else {
                completion(.failure(VideoError.invalidResponse))
            }
        }.resume()
    }
    
    // MARK: - 轮询任务状态
    private func pollTaskStatus(
        taskId: String,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let maxAttempts = 60  // 最多轮询60次
        var attempts = 0
        
        func checkStatus() {
            guard attempts < maxAttempts else {
                completion(.failure(VideoError.timeout))
                return
            }
            
            attempts += 1
            
            guard let url = URL(string: "\(baseURL)/videos/\(taskId)") else {
                completion(.failure(VideoError.invalidURL))
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        completion(.failure(VideoError.invalidResponse))
                    }
                    return
                }
                
                let status = json["status"] as? String ?? "unknown"
                let progress = json["progress"] as? Double ?? 0.0
                
                DispatchQueue.main.async {
                    progressHandler(progress)
                    
                    switch status {
                    case "completed":
                        if let videoURL = json["video_url"] as? String {
                            completion(.success(videoURL))
                        } else {
                            completion(.failure(VideoError.noVideoURL))
                        }
                    case "failed":
                        let errorMessage = json["error_message"] as? String ?? "Unknown error"
                        completion(.failure(VideoError.apiError(errorMessage)))
                    case "processing":
                        // 继续轮询
                        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                            checkStatus()
                        }
                    default:
                        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                            checkStatus()
                        }
                    }
                }
            }.resume()
        }
        
        checkStatus()
    }
}

// MARK: - 错误类型
enum VideoError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case noVideoURL
    case timeout
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有收到数据"
        case .invalidResponse:
            return "无效的响应"
        case .noVideoURL:
            return "未获取到视频地址"
        case .timeout:
            return "生成超时，请重试"
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
}
