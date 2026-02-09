//
//  UserModels.swift
//  MyStoryApp
//
//  用户数据模型
//

import Foundation

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let username: String
    let nickname: String
    let avatar: String
    let bio: String
    let createdAt: Date
    let totalVideos: Int
    let totalImages: Int
    let storageUsed: Int64
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case nickname
        case avatar
        case bio
        case createdAt = "created_at"
        case totalVideos = "total_videos"
        case totalImages = "total_images"
        case storageUsed = "storage_used"
    }
    
    // 格式化存储空间
    var formattedStorage: String {
        let bytes = storageUsed
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
}

// MARK: - 登录/注册请求
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let username: String
    let password: String
    let nickname: String
}

// MARK: - 登录响应
struct AuthResponse: Codable {
    let success: Bool
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
        case message
    }
}

// MARK: - 更新用户信息请求
struct UpdateUserRequest: Codable {
    let nickname: String?
    let avatar: String?
    let bio: String?
}

// MARK: - 修改密码请求
struct ChangePasswordRequest: Codable {
    let oldPassword: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}

// MARK: - 素材模型
struct Material: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let materialType: String
    let fileUrl: String
    let fileSize: Int64
    let fileFormat: String
    let metadata: [String: AnyCodable]?
    let tags: [String]
    let isFavorite: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case materialType = "material_type"
        case fileUrl = "file_url"
        case fileSize = "file_size"
        case fileFormat = "file_format"
        case metadata
        case tags
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
    }
    
    // 格式化文件大小
    var formattedSize: String {
        let bytes = fileSize
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    
    // 图标
    var icon: String {
        switch materialType {
        case "image", "expanded_image":
            return "photo"
        case "audio":
            return "waveform"
        case "video":
            return "film"
        case "music":
            return "music.note"
        default:
            return "doc"
        }
    }
    
    // 颜色
    var color: String {
        switch materialType {
        case "image", "expanded_image":
            return "blue"
        case "audio":
            return "purple"
        case "video":
            return "red"
        case "music":
            return "pink"
        default:
            return "gray"
        }
    }
}

// MARK: - 素材列表响应
struct MaterialListResponse: Codable {
    let total: Int
    let items: [Material]
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case total
        case items
        case page
        case pageSize = "page_size"
    }
}

// MARK: - 更新素材请求
struct UpdateMaterialRequest: Codable {
    let title: String?
    let description: String?
    let tags: [String]?
    let isFavorite: Bool?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case tags
        case isFavorite = "is_favorite"
    }
}

// MARK: - 视频任务模型
struct VideoTaskItem: Codable, Identifiable {
    let id: Int
    let taskId: String
    let title: String
    let description: String
    let status: String
    let progress: Int
    let message: String
    let outputUrl: String
    let thumbnailUrl: String
    let duration: Int
    let resolution: String
    let slidesCount: Int
    let createdAt: Date
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case title
        case description
        case status
        case progress
        case message
        case outputUrl = "output_url"
        case thumbnailUrl = "thumbnail_url"
        case duration
        case resolution
        case slidesCount = "slides_count"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
    
    // 状态颜色
    var statusColor: String {
        switch status {
        case "completed":
            return "green"
        case "failed":
            return "red"
        case "processing", "expanding_images", "generating_voice", "composing":
            return "blue"
        default:
            return "gray"
        }
    }
    
    // 状态图标
    var statusIcon: String {
        switch status {
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "xmark.circle.fill"
        case "processing", "expanding_images", "generating_voice", "composing":
            return "arrow.triangle.2.circlepath"
        default:
            return "clock"
        }
    }
}

// MARK: - AnyCodable 辅助类型
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}
