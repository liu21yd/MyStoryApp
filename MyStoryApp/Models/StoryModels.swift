//
//  StoryModels.swift
//  MyStoryApp
//
//  数据模型定义
//

import Foundation
import UIKit
import SwiftUI

// MARK: - 故事模型
struct Story: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var status: StoryStatus
    var videoURL: String?  // 生成的视频本地路径或远程URL
    var thumbnailURL: String?
    var scenes: [Scene]
    var style: VideoStyle
    var duration: VideoDuration
    
    init(id: UUID = UUID(), 
         title: String = "",
         description: String = "",
         createdAt: Date = Date(),
         status: StoryStatus = .draft,
         videoURL: String? = nil,
         thumbnailURL: String? = nil,
         scenes: [Scene] = [],
         style: VideoStyle = .cinematic,
         duration: VideoDuration = .short) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.status = status
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.scenes = scenes
        self.style = style
        self.duration = duration
    }
}

// MARK: - 场景模型
struct Scene: Identifiable, Codable {
    let id: UUID
    var imageURL: String?  // 本地图片路径
    var caption: String    // 场景描述/配文
    var order: Int         // 场景顺序
    var emotion: EmotionType  // 情感标签
    
    init(id: UUID = UUID(),
         imageURL: String? = nil,
         caption: String = "",
         order: Int = 0,
         emotion: EmotionType = .neutral) {
        self.id = id
        self.imageURL = imageURL
        self.caption = caption
        self.order = order
        self.emotion = emotion
    }
}

// MARK: - 故事状态
enum StoryStatus: String, Codable, CaseIterable {
    case draft = "草稿"
    case generating = "生成中"
    case completed = "已完成"
    case failed = "生成失败"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .generating: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .generating: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - 视频风格
enum VideoStyle: String, Codable, CaseIterable {
    case cinematic = "电影感"
    case anime = "动漫风"
    case realistic = "写实风"
    case dreamy = "梦幻风"
    case vintage = "复古风"
    
    var icon: String {
        switch self {
        case .cinematic: return "film"
        case .anime: return "sparkles"
        case .realistic: return "camera.fill"
        case .dreamy: return "cloud.fill"
        case .vintage: return "clock.arrow.circlepath"
        }
    }
    
    var description: String {
        switch self {
        case .cinematic:
            return "电影级别的画面质感，适合记录重要时刻"
        case .anime:
            return "动漫风格的渲染，让故事更加生动有趣"
        case .realistic:
            return "真实自然的视觉效果，还原美好瞬间"
        case .dreamy:
            return "柔和梦幻的色调，营造浪漫氛围"
        case .vintage:
            return "怀旧复古风格，重温经典记忆"
        }
    }
}

// MARK: - 视频时长
enum VideoDuration: Int, Codable, CaseIterable {
    case short = 10     // 10秒
    case medium = 30    // 30秒
    case long = 60      // 60秒
    
    var displayText: String {
        switch self {
        case .short: return "10秒"
        case .medium: return "30秒"
        case .long: return "60秒"
        }
    }
    
    var description: String {
        switch self {
        case .short:
            return "适合短视频分享，节奏紧凑"
        case .medium:
            return "平衡的内容展示，适合大多数场景"
        case .long:
            return "完整的故事叙述，细节更丰富"
        }
    }
}

// MARK: - 情感类型
enum EmotionType: String, Codable, CaseIterable {
    case happy = "开心"
    case sad = "感伤"
    case excited = "激动"
    case calm = "平静"
    case romantic = "浪漫"
    case nostalgic = "怀旧"
    case neutral = "中性"
    
    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .sad: return "cloud.rain"
        case .excited: return "flame.fill"
        case .calm: return "leaf.fill"
        case .romantic: return "heart.fill"
        case .nostalgic: return "clock"
        case .neutral: return "minus.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .sad: return .blue
        case .excited: return .orange
        case .calm: return .green
        case .romantic: return .pink
        case .nostalgic: return .purple
        case .neutral: return .gray
        }
    }
}

// MARK: - 视频生成请求
struct VideoGenerationRequest: Codable {
    let storyId: UUID
    let style: VideoStyle
    let duration: VideoDuration
    let scenes: [Scene]
    let backgroundMusic: Bool
    let voiceOver: Bool
}

// MARK: - 视频生成响应
struct VideoGenerationResponse: Codable {
    let taskId: String
    let status: String
    let progress: Int
    let videoURL: String?
    let errorMessage: String?
}
