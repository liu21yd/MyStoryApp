//
//  StoryManager.swift
//  MyStoryApp
//
//  故事数据管理
//

import Foundation
import Combine

class StoryManager: ObservableObject {
    @Published var stories: [Story] = []
    @Published var currentStory: Story?
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Double = 0.0
    
    private let videoService = VideoGenerationService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadStories()
    }
    
    // MARK: - 创建新故事
    func createStory(title: String, description: String, style: VideoStyle, duration: VideoDuration) -> Story {
        let story = Story(
            title: title,
            description: description,
            style: style,
            duration: duration
        )
        currentStory = story
        return story
    }
    
    // MARK: - 添加场景
    func addScene(imageURL: String?, caption: String, emotion: EmotionType) {
        guard var story = currentStory else { return }
        
        let scene = Scene(
            imageURL: imageURL,
            caption: caption,
            order: story.scenes.count,
            emotion: emotion
        )
        
        story.scenes.append(scene)
        currentStory = story
        
        // 更新存储中的故事
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories[index] = story
        } else {
            stories.append(story)
        }
        saveStories()
    }
    
    // MARK: - 删除场景
    func removeScene(at index: Int) {
        guard var story = currentStory else { return }
        story.scenes.remove(at: index)
        // 重新排序
        for i in story.scenes.indices {
            story.scenes[i].order = i
        }
        currentStory = story
        updateStory(story)
    }
    
    // MARK: - 更新场景
    func updateScene(_ scene: Scene) {
        guard var story = currentStory else { return }
        if let index = story.scenes.firstIndex(where: { $0.id == scene.id }) {
            story.scenes[index] = scene
            currentStory = story
            updateStory(story)
        }
    }
    
    // MARK: - 更新故事
    func updateStory(_ story: Story) {
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories[index] = story
        } else {
            stories.append(story)
        }
        currentStory = story
        saveStories()
    }
    
    // MARK: - 生成视频
    func generateVideo(for story: Story, completion: @escaping (Result<String, Error>) -> Void) {
        isGenerating = true
        generationProgress = 0.0
        
        var updatingStory = story
        updatingStory.status = .generating
        updateStory(updatingStory)
        
        videoService.generateVideo(
            request: VideoGenerationRequest(
                storyId: story.id,
                style: story.style,
                duration: story.duration,
                scenes: story.scenes,
                backgroundMusic: true,
                voiceOver: false
            ),
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.generationProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isGenerating = false
                
                switch result {
                case .success(let videoURL):
                    var completedStory = story
                    completedStory.status = .completed
                    completedStory.videoURL = videoURL
                    self?.updateStory(completedStory)
                    completion(.success(videoURL))
                    
                case .failure(let error):
                    var failedStory = story
                    failedStory.status = .failed
                    self?.updateStory(failedStory)
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 删除故事
    func deleteStory(_ story: Story) {
        stories.removeAll { $0.id == story.id }
        if currentStory?.id == story.id {
            currentStory = nil
        }
        saveStories()
    }
    
    // MARK: - 数据持久化
    private func saveStories() {
        if let encoded = try? JSONEncoder().encode(stories) {
            UserDefaults.standard.set(encoded, forKey: "saved_stories")
        }
    }
    
    private func loadStories() {
        if let data = UserDefaults.standard.data(forKey: "saved_stories"),
           let decoded = try? JSONDecoder().decode([Story].self, from: data) {
            stories = decoded
        }
    }
}
