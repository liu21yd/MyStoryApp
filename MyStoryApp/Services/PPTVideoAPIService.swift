//
//  PPTVideoAPIService.swift
//  MyStoryApp
//
//  PPT视频生成 API 服务 - 调用后端接口
//

import Foundation
import UIKit
import Combine

class PPTVideoAPIService: ObservableObject {
    
    // MARK: - Configuration
    private let baseURL: String
    private let session: URLSession
    
    @Published var currentTaskId: String?
    @Published var taskStatus: VideoTaskStatus?
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var statusTimer: Timer?
    
    // MARK: - Initialization
    init(baseURL: String = "http://localhost:3000/api/v1") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 1. 上传并扩展图片
    func expandImage(
        image: UIImage,
        style: ImageExpansionStyle,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            completion(.failure(APIError.invalidImage))
            return
        }
        
        let url = URL(string: "\(baseURL)/image/expand")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"style\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(style)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success == true,
                  let dataDict = json["data"] as? [String: Any],
                  let expandedUrl = dataDict["expandedImageUrl"] as? String else {
                DispatchQueue.main.async { completion(.failure(APIError.invalidResponse)) }
                return
            }
            
            DispatchQueue.main.async { completion(.success(expandedUrl)) }
        }.resume()
    }
    
    // MARK: - 2. 生成配音
    func generateVoice(
        text: String,
        voiceType: VoiceType,
        speed: Double,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = URL(string: "\(baseURL)/tts/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text,
            "voiceType": voiceType.rawValue,
            "speed": speed
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success == true,
                  let dataDict = json["data"] as? [String: Any],
                  let audioUrl = dataDict["audioUrl"] as? String else {
                DispatchQueue.main.async { completion(.failure(APIError.invalidResponse)) }
                return
            }
            
            DispatchQueue.main.async { completion(.success(audioUrl)) }
        }.resume()
    }
    
    // MARK: - 3. 创建视频任务
    func createVideoTask(
        pptVideo: PPTVideo,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        isProcessing = true
        progress = 0
        
        let url = URL(string: "\(baseURL)/video/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        let slidesData = pptVideo.slides.map { slide -> [String: Any] in
            return [
                "imageUrl": slide.expandedImageURL ?? slide.imageURL ?? "",
                "caption": slide.caption,
                "voiceText": slide.voiceText,
                "duration": slide.duration,
                "transition": slide.transition.rawValue
            ]
        }
        
        let configData: [String: Any] = [
            "resolution": pptVideo.config.resolution.rawValue,
            "frameRate": pptVideo.config.frameRate,
            "voiceType": pptVideo.config.voiceType.rawValue,
            "voiceSpeed": pptVideo.config.voiceSpeed,
            "backgroundMusic": pptVideo.config.backgroundMusic.rawValue,
            "subtitleEnabled": pptVideo.config.subtitleEnabled,
            "subtitlePosition": pptVideo.config.subtitlePosition.rawValue,
            "aiImageExpansion": pptVideo.config.aiImageExpansion,
            "expansionStyle": pptVideo.config.expansionStyle.rawValue
        ]
        
        let body: [String: Any] = [
            "title": pptVideo.title,
            "description": pptVideo.description,
            "slides": slidesData,
            "config": configData
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success == true,
                  let dataDict = json["data"] as? [String: Any],
                  let taskId = dataDict["taskId"] as? String else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.currentTaskId = taskId
                self?.startPollingStatus(taskId: taskId, completion: completion)
            }
        }.resume()
    }
    
    // MARK: - 4. 轮询任务状态
    private func startPollingStatus(taskId: String, completion: @escaping (Result<String, Error>) -> Void) {
        statusTimer?.invalidate()
        
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkTaskStatus(taskId: taskId, completion: completion)
        }
        
        // 立即检查一次
        checkTaskStatus(taskId: taskId, completion: completion)
    }
    
    private func checkTaskStatus(taskId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/video/status/\(taskId)")!
        
        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.stopPolling()
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success == true,
                  let dataDict = json["data"] as? [String: Any] else {
                return
            }
            
            let status = dataDict["status"] as? String ?? "unknown"
            let progress = dataDict["progress"] as? Double ?? 0
            let message = dataDict["message"] as? String ?? ""
            let outputUrl = dataDict["outputUrl"] as? String
            let errorMsg = dataDict["error"] as? String
            
            DispatchQueue.main.async {
                self.progress = progress
                self.taskStatus = VideoTaskStatus(
                    taskId: taskId,
                    status: status,
                    progress: progress,
                    message: message,
                    outputUrl: outputUrl,
                    error: errorMsg
                )
                
                switch status {
                case "completed":
                    self.stopPolling()
                    self.isProcessing = false
                    if let url = outputUrl {
                        completion(.success(url))
                    } else {
                        completion(.failure(APIError.noOutput))
                    }
                    
                case "failed":
                    self.stopPolling()
                    self.isProcessing = false
                    completion(.failure(APIError.taskFailed(errorMsg ?? "Unknown error")))
                    
                default:
                    break
                }
            }
        }.resume()
    }
    
    private func stopPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    // MARK: - 5. 取消任务
    func cancelTask() {
        stopPolling()
        isProcessing = false
        progress = 0
        currentTaskId = nil
    }
}

// MARK: - 任务状态模型
struct VideoTaskStatus {
    let taskId: String
    let status: String
    let progress: Double
    let message: String
    let outputUrl: String?
    let error: String?
}

// MARK: - API 错误
enum APIError: LocalizedError {
    case invalidImage
    case invalidResponse
    case noOutput
    case taskFailed(String)
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图片"
        case .invalidResponse:
            return "服务器响应无效"
        case .noOutput:
            return "没有输出文件"
        case .taskFailed(let msg):
            return "任务失败: \(msg)"
        case .serverError(let code):
            return "服务器错误: \(code)"
        }
    }
}
