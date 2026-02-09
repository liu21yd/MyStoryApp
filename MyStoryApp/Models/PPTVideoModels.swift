//
//  PPTVideoModels.swift
//  MyStoryApp
//
//  PPT视频生成器数据模型
//

import Foundation
import SwiftUI
import AVFoundation

// MARK: - PPT视频模型
struct PPTVideo: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var status: PPTVideoStatus
    var outputURL: String?  // 生成的视频路径
    var thumbnailURL: String?
    var slides: [PPTSlide]
    var config: PPTVideoConfig
    var totalDuration: TimeInterval  // 总时长（秒）
    
    init(id: UUID = UUID(),
         title: String = "",
         description: String = "",
         createdAt: Date = Date(),
         status: PPTVideoStatus = .draft,
         outputURL: String? = nil,
         thumbnailURL: String? = nil,
         slides: [PPTSlide] = [],
         config: PPTVideoConfig = PPTVideoConfig(),
         totalDuration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.status = status
        self.outputURL = outputURL
        self.thumbnailURL = thumbnailURL
        self.slides = slides
        self.config = config
        self.totalDuration = totalDuration
    }
    
    // 计算总时长
    mutating func calculateDuration() {
        totalDuration = slides.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - PPT幻灯片模型
struct PPTSlide: Identifiable, Codable {
    let id: UUID
    var imageURL: String?  // 原始图片路径
    var expandedImageURL: String?  // AI扩展后的图片路径
    var caption: String    // 描述文字/字幕内容
    var duration: TimeInterval  // 该幻灯片显示时长（秒）
    var order: Int         // 顺序
    var voiceText: String  // 配音文本（可以与caption不同）
    var voiceURL: String?  // 生成的配音文件路径
    var transition: SlideTransition  // 转场效果
    var subtitleStyle: SubtitleStyle  // 字幕样式
    
    init(id: UUID = UUID(),
         imageURL: String? = nil,
         expandedImageURL: String? = nil,
         caption: String = "",
         duration: TimeInterval = 5.0,
         order: Int = 0,
         voiceText: String = "",
         voiceURL: String? = nil,
         transition: SlideTransition = .fade,
         subtitleStyle: SubtitleStyle = SubtitleStyle()) {
        self.id = id
        self.imageURL = imageURL
        self.expandedImageURL = expandedImageURL
        self.caption = caption
        self.duration = duration
        self.order = order
        self.voiceText = voiceText
        self.voiceURL = voiceURL
        self.transition = transition
        self.subtitleStyle = subtitleStyle
    }
}

// MARK: - PPT视频配置
struct PPTVideoConfig: Codable {
    var resolution: VideoResolution
    var frameRate: Int
    var backgroundMusic: BGMOption
    var voiceType: VoiceType
    var voiceSpeed: Double  // 0.5 - 2.0
    var subtitleEnabled: Bool
    var subtitlePosition: SubtitlePosition
    var aiImageExpansion: Bool  // 是否使用AI扩展图片
    var expansionStyle: ImageExpansionStyle
    
    init(resolution: VideoResolution = .hd,
         frameRate: Int = 30,
         backgroundMusic: BGMOption = .gentle,
         voiceType: VoiceType = .standardFemale,
         voiceSpeed: Double = 1.0,
         subtitleEnabled: Bool = true,
         subtitlePosition: SubtitlePosition = .bottom,
         aiImageExpansion: Bool = true,
         expansionStyle: ImageExpansionStyle = .cinematic) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.backgroundMusic = backgroundMusic
        self.voiceType = voiceType
        self.voiceSpeed = voiceSpeed
        self.subtitleEnabled = subtitleEnabled
        self.subtitlePosition = subtitlePosition
        self.aiImageExpansion = aiImageExpansion
        self.expansionStyle = expansionStyle
    }
}

// MARK: - 视频分辨率
enum VideoResolution: String, Codable, CaseIterable {
    case sd = "480p"
    case hd = "720p"
    case fhd = "1080p"
    case _2k = "2K"
    case _4k = "4K"
    
    var size: CGSize {
        switch self {
        case .sd: return CGSize(width: 854, height: 480)
        case .hd: return CGSize(width: 1280, height: 720)
        case .fhd: return CGSize(width: 1920, height: 1080)
        case ._2k: return CGSize(width: 2560, height: 1440)
        case ._4k: return CGSize(width: 3840, height: 2160)
        }
    }
    
    var displayText: String {
        return rawValue
    }
}

// MARK: - BGM选项
enum BGMOption: String, Codable, CaseIterable {
    case none = "无背景音乐"
    case gentle = "轻柔舒缓"
    case upbeat = "轻快活泼"
    case epic = "宏大史诗"
    case romantic = "浪漫温馨"
    case nostalgic = "怀旧复古"
    case custom = "自定义音乐"
    
    var icon: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .gentle: return "music.note"
        case .upbeat: return "music.note.list"
        case .epic: return "music.mic"
        case .romantic: return "heart.fill"
        case .nostalgic: return "clock.arrow.circlepath"
        case .custom: return "folder.fill"
        }
    }
    
    var defaultVolume: Float {
        switch self {
        case .none: return 0
        case .gentle: return 0.3
        case .upbeat: return 0.4
        case .epic: return 0.5
        case .romantic: return 0.35
        case .nostalgic: return 0.3
        case .custom: return 0.4
        }
    }
}

// MARK: - 配音类型
enum VoiceType: String, Codable, CaseIterable {
    case standardFemale = "标准女声"
    case standardMale = "标准男声"
    case gentleFemale = "温柔女声"
    case deepMale = "磁性男声"
    case child = "童声"
    case cartoon = "卡通音"
    
    var icon: String {
        switch self {
        case .standardFemale: return "person.fill"
        case .standardMale: return "person.fill"
        case .gentleFemale: return "heart.fill"
        case .deepMale: return "mic.fill"
        case .child: return "face.smiling.fill"
        case .cartoon: return "sparkles"
        }
    }
    
    // 对应 TTS API 的 voice ID
    var ttsVoiceId: String {
        switch self {
        case .standardFemale: return "zh-CN-XiaoxiaoNeural"
        case .standardMale: return "zh-CN-YunjianNeural"
        case .gentleFemale: return "zh-CN-XiaoyiNeural"
        case .deepMale: return "zh-CN-YunxiNeural"
        case .child: return "zh-CN-XiaoxiaoNeural"  //  fallback
        case .cartoon: return "zh-CN-YunxiNeural"    //  fallback
        }
    }
}

// MARK: - 字幕位置
enum SubtitlePosition: String, Codable, CaseIterable {
    case top = "顶部"
    case center = "居中"
    case bottom = "底部"
    
    var yPosition: CGFloat {
        switch self {
        case .top: return 0.15
        case .center: return 0.5
        case .bottom: return 0.85
        }
    }
}

// MARK: - 字幕样式
struct SubtitleStyle: Codable {
    var fontSize: CGFloat
    var fontColor: String  // Hex color
    var backgroundColor: String  // Hex color with alpha
    var strokeWidth: CGFloat
    var strokeColor: String
    var animation: SubtitleAnimation
    
    init(fontSize: CGFloat = 32,
         fontColor: String = "#FFFFFF",
         backgroundColor: String = "#00000066",
         strokeWidth: CGFloat = 2,
         strokeColor: String = "#000000",
         animation: SubtitleAnimation = .fade) {
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.backgroundColor = backgroundColor
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor
        self.animation = animation
    }
    
    static let `default` = SubtitleStyle()
}

// MARK: - 字幕动画
enum SubtitleAnimation: String, Codable, CaseIterable {
    case none = "无动画"
    case fade = "淡入淡出"
    case slideUp = "上滑入"
    case typewriter = "打字机"
    case bounce = "弹跳"
}

// MARK: - 幻灯片转场效果
enum SlideTransition: String, Codable, CaseIterable {
    case none = "无转场"
    case fade = "淡入淡出"
    case slideLeft = "左滑"
    case slideRight = "右滑"
    case slideUp = "上滑"
    case slideDown = "下滑"
    case zoom = "缩放"
    case flip = "翻转"
    case wipe = "擦除"
    
    var icon: String {
        switch self {
        case .none: return "minus"
        case .fade: return "sun.minus.fill"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .zoom: return "arrow.up.left.and.arrow.down.right"
        case .flip: return "arrow.2.squarepath"
        case .wipe: return "rectangle.portrait.fill"
        }
    }
    
    var duration: TimeInterval {
        return 0.5  // 转场动画时长
    }
}

// MARK: - 图片扩展风格
enum ImageExpansionStyle: String, Codable, CaseIterable {
    case cinematic = "电影感"
    case anime = "动漫风"
    case realistic = "写实风"
    case dreamy = "梦幻风"
    case vintage = "复古风"
    case artistic = "艺术风"
    
    var promptSuffix: String {
        switch self {
        case .cinematic:
            return "cinematic lighting, professional color grading, movie quality"
        case .anime:
            return "anime art style, vibrant colors, clean lines"
        case .realistic:
            return "photorealistic, natural lighting, lifelike details"
        case .dreamy:
            return "soft focus, dreamy atmosphere, pastel tones"
        case .vintage:
            return "vintage film look, warm tones, film grain"
        case .artistic:
            return "artistic interpretation, creative composition, painterly style"
        }
    }
}

// MARK: - PPT视频状态
enum PPTVideoStatus: String, Codable, CaseIterable {
    case draft = "草稿"
    case expandingImages = "扩展图片中"
    case generatingVoice = "生成配音中"
    case composing = "合成视频中"
    case completed = "已完成"
    case failed = "生成失败"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .expandingImages: return "photo.fill.on.rectangle.fill"
        case .generatingVoice: return "waveform"
        case .composing: return "film.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .expandingImages: return .blue
        case .generatingVoice: return .purple
        case .composing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - 生成进度
struct PPTGenerationProgress {
    let currentStep: GenerationStep
    let overallProgress: Double  // 0.0 - 1.0
    let stepProgress: Double     // 当前步骤进度 0.0 - 1.0
    let message: String
    
    init(currentStep: GenerationStep = .preparing,
         overallProgress: Double = 0,
         stepProgress: Double = 0,
         message: String = "准备中...") {
        self.currentStep = currentStep
        self.overallProgress = overallProgress
        self.stepProgress = stepProgress
        self.message = message
    }
}

// MARK: - 生成步骤
enum GenerationStep: String, CaseIterable {
    case preparing = "准备中"
    case expandingImages = "扩展图片"
    case generatingVoice = "生成配音"
    case preparingAudio = "准备音频"
    case composingVideo = "合成视频"
    case finalizing = "最终处理"
    
    var weight: Double {
        switch self {
        case .preparing: return 0.05
        case .expandingImages: return 0.35
        case .generatingVoice: return 0.25
        case .preparingAudio: return 0.10
        case .composingVideo: return 0.20
        case .finalizing: return 0.05
        }
    }
}

// MARK: - 生成错误
enum PPTGenerationError: LocalizedError {
    case invalidInput
    case imageExpansionFailed(String)
    case voiceGenerationFailed(String)
    case audioMixingFailed(String)
    case videoCompositionFailed(String)
    case ffmpegNotAvailable
    case outputFileError
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "输入无效，请检查图片和文字"
        case .imageExpansionFailed(let msg):
            return "图片扩展失败: \(msg)"
        case .voiceGenerationFailed(let msg):
            return "配音生成失败: \(msg)"
        case .audioMixingFailed(let msg):
            return "音频合成失败: \(msg)"
        case .videoCompositionFailed(let msg):
            return "视频合成失败: \(msg)"
        case .ffmpegNotAvailable:
            return "FFmpeg 不可用，请检查安装"
        case .outputFileError:
            return "输出文件错误"
        case .cancelled:
            return "已取消生成"
        }
    }
}

// MARK: - 背景音乐资源
struct BGMResource {
    let name: String
    let fileName: String
    let duration: TimeInterval
    let url: URL?
}

// MARK: - 预设BGM
extension BGMOption {
    func getResourceURL() -> URL? {
        // 这里返回内置BGM的URL
        // 实际项目中需要从资源包加载
        return nil
    }
}
