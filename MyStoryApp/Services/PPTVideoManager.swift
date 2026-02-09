//
//  PPTVideoManager.swift
//  MyStoryApp
//
//  PPT视频数据管理
//

import Foundation
import Combine

class PPTVideoManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var videos: [PPTVideo] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let videosKey = "savedPPTVideos"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    static let shared = PPTVideoManager()
    
    private init() {
        loadVideos()
    }
    
    // MARK: - Data Persistence
    private func loadVideos() {
        isLoading = true
        
        guard let data = userDefaults.data(forKey: videosKey),
              let savedVideos = try? JSONDecoder().decode([PPTVideo].self, from: data) else {
            isLoading = false
            return
        }
        
        videos = savedVideos.sorted(by: { $0.createdAt > $1.createdAt })
        isLoading = false
    }
    
    private func saveVideos() {
        if let data = try? JSONEncoder().encode(videos) {
            userDefaults.set(data, forKey: videosKey)
        }
    }
    
    // MARK: - CRUD Operations
    func addVideo(_ video: PPTVideo) {
        videos.insert(video, at: 0)
        saveVideos()
    }
    
    func updateVideo(_ video: PPTVideo) {
        if let index = videos.firstIndex(where: { $0.id == video.id }) {
            videos[index] = video
            saveVideos()
        }
    }
    
    func deleteVideo(_ video: PPTVideo) {
        // 删除关联的视频文件
        if let outputURL = video.outputURL {
            try? FileManager.default.removeItem(atPath: outputURL)
        }
        
        videos.removeAll { $0.id == video.id }
        saveVideos()
    }
    
    func deleteVideos(at offsets: IndexSet) {
        for index in offsets {
            let video = videos[index]
            if let outputURL = video.outputURL {
                try? FileManager.default.removeItem(atPath: outputURL)
            }
        }
        
        videos.remove(atOffsets: offsets)
        saveVideos()
    }
    
    // MARK: - Get Video by ID
    func getVideo(id: UUID) -> PPTVideo? {
        return videos.first { $0.id == id }
    }
    
    // MARK: - Update Video Status
    func updateVideoStatus(id: UUID, status: PPTVideoStatus) {
        if let index = videos.firstIndex(where: { $0.id == id }) {
            videos[index].status = status
            saveVideos()
        }
    }
    
    func updateVideoOutputURL(id: UUID, url: String) {
        if let index = videos.firstIndex(where: { $0.id == id }) {
            videos[index].outputURL = url
            saveVideos()
        }
    }
    
    // MARK: - Get Statistics
    func getStatistics() -> PPTVideoStatistics {
        let totalCount = videos.count
        let completedCount = videos.filter { $0.status == .completed }.count
        let totalDuration = videos.reduce(0) { $0 + $1.totalDuration }
        
        return PPTVideoStatistics(
            totalCount: totalCount,
            completedCount: completedCount,
            totalDuration: totalDuration
        )
    }
    
    // MARK: - Export/Import
    func exportVideos() -> Data? {
        return try? JSONEncoder().encode(videos)
    }
    
    func importVideos(from data: Data) -> Bool {
        guard let importedVideos = try? JSONDecoder().decode([PPTVideo].self, from: data) else {
            return false
        }
        
        videos.append(contentsOf: importedVideos)
        saveVideos()
        return true
    }
    
    // MARK: - Cleanup
    func cleanupOrphanedFiles() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosPath = documentsPath.appendingPathComponent("PPTVideos", isDirectory: true)
        
        guard let files = try? fileManager.contentsOfDirectory(at: videosPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        let validPaths = Set(videos.compactMap { $0.outputURL })
        
        for file in files {
            if !validPaths.contains(file.path) {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

// MARK: - Statistics
struct PPTVideoStatistics {
    let totalCount: Int
    let completedCount: Int
    let totalDuration: TimeInterval
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
