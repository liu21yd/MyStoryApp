//
//  CreateStoryView.swift
//  MyStoryApp
//
//  创作故事主界面
//

import SwiftUI
import PhotosUI

struct CreateStoryView: View {
    @ObservedObject var storyManager: StoryManager
    
    @State private var storyTitle = ""
    @State private var storyDescription = ""
    @State private var selectedStyle: VideoStyle = .cinematic
    @State private var selectedDuration: VideoDuration = .short
    @State private var scenes: [SceneInput] = []
    @State private var showImagePicker = false
    @State private var selectedSceneIndex: Int?
    @State private var showGenerateConfirmation = false
    @State private var navigateToPreview = false
    
    // 临时场景输入模型
    struct SceneInput: Identifiable {
        let id = UUID()
        var image: UIImage?
        var caption: String
        var emotion: EmotionType
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 故事基本信息
                    storyInfoSection
                    
                    // 视频设置
                    videoSettingsSection
                    
                    // 场景列表
                    scenesSection
                    
                    // 生成按钮
                    generateButton
                }
                .padding()
            }
            .navigationTitle("创作故事")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { selectedSceneIndex != nil ? scenes[selectedSceneIndex!].image : nil },
                    set: { newImage in
                        if let index = selectedSceneIndex {
                            scenes[index].image = newImage
                        }
                    }
                ))
            }
            .alert("生成视频", isPresented: $showGenerateConfirmation) {
                Button("取消", role: .cancel) {}
                Button("确认生成") {
                    createAndGenerateStory()
                }
            } message: {
                Text("将使用AI生成约\(selectedDuration.displayText)的\(selectedStyle.rawValue)风格视频。这会消耗一定的API额度。")
            }
            .overlay(
                Group {
                    if storyManager.isGenerating {
                        GenerationProgressView(progress: storyManager.generationProgress)
                    }
                }
            )
        }
    }
    
    // MARK: - 故事信息部分
    private var storyInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("故事信息")
                .font(.headline)
                .fontWeight(.bold)
            
            // 标题输入
            VStack(alignment: .leading, spacing: 8) {
                Text("标题")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("给你的故事起个名字", text: $storyTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
            }
            
            // 描述输入
            VStack(alignment: .leading, spacing: 8) {
                Text("描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $storyDescription)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 视频设置部分
    private var videoSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频设置")
                .font(.headline)
                .fontWeight(.bold)
            
            // 风格选择
            VStack(alignment: .leading, spacing: 8) {
                Text("视频风格")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VideoStyle.allCases, id: \.self) { style in
                            StyleCard(style: style, isSelected: selectedStyle == style) {
                                selectedStyle = style
                            }
                        }
                    }
                }
            }
            
            // 时长选择
            VStack(alignment: .leading, spacing: 8) {
                Text("视频时长")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("时长", selection: $selectedDuration) {
                    ForEach(VideoDuration.allCases, id: \.self) { duration in
                        Text(duration.displayText)
                            .tag(duration)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 场景部分
    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("故事场景")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(scenes.count) 个场景")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if scenes.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("还没有添加场景")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("添加第一个场景") {
                        addNewScene()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                // 场景列表
                VStack(spacing: 12) {
                    ForEach(scenes.indices, id: \.self) { index in
                        SceneEditorCard(
                            scene: $scenes[index],
                            index: index,
                            onDelete: { deleteScene(at: index) },
                            onSelectImage: {
                                selectedSceneIndex = index
                                showImagePicker = true
                            }
                        )
                    }
                    
                    // 添加场景按钮
                    Button {
                        addNewScene()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加场景")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .foregroundColor(.pink)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 生成按钮
    private var generateButton: some View {
        Button {
            if canGenerate {
                showGenerateConfirmation = true
            }
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("生成视频")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canGenerate ? Color.pink : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canGenerate || storyManager.isGenerating)
    }
    
    // MARK: - 辅助属性和方法
    private var canGenerate: Bool {
        !storyTitle.isEmpty && !scenes.isEmpty && scenes.allSatisfy { !$0.caption.isEmpty }
    }
    
    private func addNewScene() {
        scenes.append(SceneInput(image: nil, caption: "", emotion: .neutral))
    }
    
    private func deleteScene(at index: Int) {
        scenes.remove(at: index)
    }
    
    private func createAndGenerateStory() {
        // 创建故事
        let story = storyManager.createStory(
            title: storyTitle,
            description: storyDescription,
            style: selectedStyle,
            duration: selectedDuration
        )
        
        // 添加场景（需要保存图片到本地并获取路径）
        for sceneInput in scenes {
            let imageURL = sceneInput.image != nil ? saveImage(sceneInput.image!) : nil
            storyManager.addScene(
                imageURL: imageURL,
                caption: sceneInput.caption,
                emotion: sceneInput.emotion
            )
        }
        
        // 生成视频
        if let finalStory = storyManager.currentStory {
            storyManager.generateVideo(for: finalStory) { result in
                switch result {
                case .success(let videoURL):
                    print("视频生成成功: \(videoURL)")
                case .failure(let error):
                    print("视频生成失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveImage(_ image: UIImage) -> String {
        // 简化实现：实际应该保存到应用沙盒并返回路径
        return "local_image_\(UUID().uuidString)"
    }
}

// MARK: - 风格卡片
struct StyleCard: View {
    let style: VideoStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 28))
                
                Text(style.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    
                Text(style.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
            .padding()
            .frame(width: 120, height: 140)
            .background(isSelected ? Color.pink.opacity(0.2) : Color.white)
            .foregroundColor(isSelected ? .pink : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.pink : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 场景编辑卡片
struct SceneEditorCard: View {
    @Binding var scene: CreateStoryView.SceneInput
    let index: Int
    let onDelete: () -> Void
    let onSelectImage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack {
                Text("场景 \(index + 1)")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // 图片选择
            Button(action: onSelectImage) {
                if let image = scene.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                        Text("点击添加图片")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 描述输入
            VStack(alignment: .leading, spacing: 4) {
                Text("场景描述")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("描述这个场景...", text: $scene.caption)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // 情感选择
            VStack(alignment: .leading, spacing: 4) {
                Text("情感氛围")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EmotionType.allCases, id: \.self) { emotion in
                            Button {
                                scene.emotion = emotion
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: emotion.icon)
                                    Text(emotion.rawValue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(scene.emotion == emotion ? emotion.color.opacity(0.2) : Color.gray.opacity(0.1))
                                .foregroundColor(scene.emotion == emotion ? emotion.color : .gray)
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4)
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - 生成进度视图
struct GenerationProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("正在生成视频...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .pink))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(16)
        }
    }
}
