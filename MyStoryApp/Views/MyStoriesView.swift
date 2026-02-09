//
//  MyStoriesView.swift
//  MyStoryApp
//
//  我的故事列表
//

import SwiftUI

struct MyStoriesView: View {
    @ObservedObject var storyManager: StoryManager
    @State private var selectedStory: Story?
    @State private var showStoryDetail = false
    @State private var showDeleteConfirmation = false
    @State private var storyToDelete: Story?
    
    var body: some View {
        NavigationView {
            List {
                if storyManager.stories.isEmpty {
                    Section {
                        VStack(spacing: 20) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("还没有故事")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("去\"创作\"页面制作你的第一个故事吧")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // 按状态分组
                    ForEach(StoryStatus.allCases, id: \.self) { status in
                        let storiesForStatus = storyManager.stories.filter { $0.status == status }
                        if !storiesForStatus.isEmpty {
                            Section(header: StatusHeader(status: status, count: storiesForStatus.count)) {
                                ForEach(storiesForStatus.sorted(by: { $0.createdAt > $1.createdAt })) { story in
                                    StoryCard(story: story)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedStory = story
                                            showStoryDetail = true
                                        }
                                        .contextMenu {
                                            contextMenu(for: story)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("我的故事")
            .sheet(item: $selectedStory) { story in
                StoryDetailView(story: story, storyManager: storyManager)
            }
            .alert("删除故事", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let story = storyToDelete {
                        storyManager.deleteStory(story)
                    }
                }
            } message: {
                Text("确定要删除这个故事吗？此操作无法撤销。")
            }
            .refreshable {
                // 刷新故事列表
            }
        }
    }
    
    @ViewBuilder
    private func contextMenu(for story: Story) -> some View {
        if story.status == .completed, let videoURL = story.videoURL {
            Button {
                shareVideo(url: videoURL)
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            
            Button {
                saveToAlbum(url: videoURL)
            } label: {
                Label("保存到相册", systemImage: "photo")
            }
        }
        
        if story.status == .failed {
            Button {
                retryGenerate(story: story)
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
            }
        }
        
        Button(role: .destructive) {
            storyToDelete = story
            showDeleteConfirmation = true
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
    
    private func shareVideo(url: String) {
        // 实现分享功能
        guard let url = URL(string: url) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // 获取当前窗口并显示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func saveToAlbum(url: String) {
        // 实现保存到相册功能
        print("保存视频到相册: \(url)")
    }
    
    private func retryGenerate(story: Story) {
        storyManager.generateVideo(for: story) { result in
            switch result {
            case .success:
                print("重试成功")
            case .failure(let error):
                print("重试失败: \(error)")
            }
        }
    }
}

// MARK: - 状态头部
struct StatusHeader: View {
    let status: StoryStatus
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(status.color)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 故事卡片
struct StoryCard: View {
    let story: Story
    
    var body: some View {
        HStack(spacing: 16) {
            // 缩略图
            ZStack {
                if let thumbnailURL = story.thumbnailURL,
                   let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
                
                // 状态遮罩
                if story.status == .generating {
                    Color.black.opacity(0.5)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(story.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // 风格标签
                    HStack(spacing: 4) {
                        Image(systemName: story.style.icon)
                            .font(.caption2)
                        Text(story.style.rawValue)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.pink.opacity(0.1))
                    .foregroundColor(.pink)
                    .cornerRadius(4)
                    
                    // 时长标签
                    Text(story.duration.displayText)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // 创建时间
                    Text(formatDate(story.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // 场景数
                Text("\(story.scenes.count) 个场景")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 故事详情视图
struct StoryDetailView: View {
    let story: Story
    @ObservedObject var storyManager: StoryManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 视频播放器区域
                    videoPlayerSection
                    
                    // 故事信息
                    storyInfoSection
                    
                    // 场景列表
                    scenesSection
                    
                    // 操作按钮
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(story.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var videoPlayerSection: some View {
        VStack {
            if story.status == .completed, let videoURL = story.videoURL {
                // 实际项目中这里应该使用 VideoPlayer
                ZStack {
                    Color.black
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    Text("点击播放")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.bottom, 12),
                    alignment: .bottom
                )
            } else if story.status == .generating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("视频生成中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView(value: storyManager.generationProgress, total: 1.0)
                        .frame(width: 200)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else if story.status == .failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("视频生成失败")
                        .font(.headline)
                    Button("重新生成") {
                        retryGeneration()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // 草稿状态
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("草稿状态")
                        .font(.headline)
                    Text("前往创作页面生成视频")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var storyInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(story.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态标签
                Label(story.status.rawValue, systemImage: story.status.icon)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(story.status.color.opacity(0.1))
                    .foregroundColor(story.status.color)
                    .cornerRadius(16)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                InfoItem(icon: story.style.icon, title: "风格", value: story.style.rawValue)
                InfoItem(icon: "clock", title: "时长", value: story.duration.displayText)
                InfoItem(icon: "photo.on.rectangle", title: "场景", value: "\(story.scenes.count)个")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("场景详情")
                .font(.headline)
            
            ForEach(story.scenes) { scene in
                HStack(spacing: 12) {
                    // 场景序号
                    Text("\(scene.order + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.pink)
                        .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.caption)
                            .font(.body)
                        
                        HStack(spacing: 6) {
                            Image(systemName: scene.emotion.icon)
                                .font(.caption)
                            Text(scene.emotion.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(scene.emotion.color)
                    }
                    
                    Spacer()
                    
                    if scene.imageURL != nil {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.1), radius: 2)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if story.status == .completed {
                Button {
                    shareStory()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享视频")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    saveToPhotos()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("保存到相册")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if story.status == .draft {
                Button {
                    generateVideo()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("生成视频")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func retryGeneration() {
        storyManager.generateVideo(for: story) { _ in }
    }
    
    private func generateVideo() {
        storyManager.generateVideo(for: story) { _ in }
    }
    
    private func shareStory() {
        // 实现分享
    }
    
    private func saveToPhotos() {
        // 实现保存到相册
    }
}

// MARK: - 信息项
struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.pink)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}
