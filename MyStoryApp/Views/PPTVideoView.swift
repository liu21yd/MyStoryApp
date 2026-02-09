//
//  PPTVideoView.swift
//  MyStoryApp
//
//  PPT视频生成器主界面
//

import SwiftUI
import PhotosUI

struct PPTVideoView: View {
    @StateObject private var generator = PPTVideoGenerator()
    @State private var pptVideo = PPTVideo()
    @State private var showingImagePicker = false
    @State private var showingSlideEditor = false
    @State private var selectedSlideIndex: Int?
    @State private var showingPreview = false
    @State private var generatedVideoURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题输入
                titleSection
                
                // 幻灯片列表
                slidesList
                
                // 配置区域
                configSection
                
                // 生成按钮
                generateButton
            }
            .navigationTitle("PPT视频生成")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addNewSlide) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker { image in
                    addSlideWithImage(image)
                }
            }
            .sheet(isPresented: $showingSlideEditor) {
                if let index = selectedSlideIndex {
                    SlideEditorView(
                        slide: $pptVideo.slides[index],
                        onDelete: {
                            deleteSlide(at: index)
                            showingSlideEditor = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingPreview) {
                if let url = generatedVideoURL {
                    VideoPreviewView(videoURL: url)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if generator.isGenerating {
                    GenerationProgressView(progress: generator.currentProgress)
                }
            }
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("视频标题", text: $pptVideo.title)
                .font(.title2.bold())
            
            TextField("添加描述（可选）", text: $pptVideo.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Slides List
    private var slidesList: some View {
        List {
            Section {
                ForEach($pptVideo.slides) { $slide in
                    SlideThumbnailView(
                        slide: slide,
                        index: pptVideo.slides.firstIndex(where: { $0.id == slide.id }) ?? 0
                    )
                    .onTapGesture {
                        selectedSlideIndex = pptVideo.slides.firstIndex(where: { $0.id == slide.id })
                        showingSlideEditor = true
                    }
                }
                .onDelete(perform: deleteSlides)
                .onMove(perform: moveSlides)
            } header: {
                HStack {
                    Text("幻灯片 (\(pptVideo.slides.count))")
                    Spacer()
                    Text("长按拖动排序")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } footer: {
                if pptVideo.slides.isEmpty {
                    emptyStateView
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有幻灯片")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 添加图片")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("添加图片") {
                showingImagePicker = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Config Section
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频配置")
                .font(.headline)
            
            // 分辨率选择
            HStack {
                Text("分辨率")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("分辨率", selection: $pptVideo.config.resolution) {
                    ForEach(VideoResolution.allCases, id: \.self) { resolution in
                        Text(resolution.displayText).tag(resolution)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // AI扩展开关
            Toggle("AI 图片扩展", isOn: $pptVideo.config.aiImageExpansion)
            
            if pptVideo.config.aiImageExpansion {
                HStack {
                    Text("扩展风格")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("风格", selection: $pptVideo.config.expansionStyle) {
                        ForEach(ImageExpansionStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // 配音设置
            Toggle("添加配音", isOn: .constant(true))
            
            HStack {
                Text("配音类型")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("配音", selection: $pptVideo.config.voiceType) {
                    ForEach(VoiceType.allCases, id: \.self) { voice in
                        Text(voice.rawValue).tag(voice)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // BGM 设置
            HStack {
                Text("背景音乐")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("BGM", selection: $pptVideo.config.backgroundMusic) {
                    ForEach(BGMOption.allCases, id: \.self) { bgm in
                        Label(bgm.rawValue, systemImage: bgm.icon).tag(bgm)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 字幕设置
            Toggle("显示字幕", isOn: $pptVideo.config.subtitleEnabled)
            
            if pptVideo.config.subtitleEnabled {
                HStack {
                    Text("字幕位置")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("位置", selection: $pptVideo.config.subtitlePosition) {
                        ForEach(SubtitlePosition.allCases, id: \.self) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: generateVideo) {
            HStack {
                Image(systemName: "film.fill")
                Text("生成视频")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(pptVideo.slides.isEmpty || generator.isGenerating)
        .padding()
    }
    
    // MARK: - Actions
    private func addNewSlide() {
        showingImagePicker = true
    }
    
    private func addSlideWithImage(_ image: UIImage) {
        // 保存图片到临时目录
        let imageName = "\(UUID().uuidString).jpg"
        let imagePath = FileManager.default.temporaryDirectory.appendingPathComponent(imageName)
        
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: imagePath)
            
            let newSlide = PPTSlide(
                imageURL: imagePath.path,
                caption: "",
                duration: 5.0,
                order: pptVideo.slides.count,
                voiceText: ""
            )
            
            pptVideo.slides.append(newSlide)
        }
    }
    
    private func deleteSlide(at index: Int) {
        pptVideo.slides.remove(at: index)
        // 重新排序
        for i in pptVideo.slides.indices {
            pptVideo.slides[i].order = i
        }
    }
    
    private func deleteSlides(at offsets: IndexSet) {
        pptVideo.slides.remove(atOffsets: offsets)
        for i in pptVideo.slides.indices {
            pptVideo.slides[i].order = i
        }
    }
    
    private func moveSlides(from source: IndexSet, to destination: Int) {
        pptVideo.slides.move(fromOffsets: source, toOffset: destination)
        for i in pptVideo.slides.indices {
            pptVideo.slides[i].order = i
        }
    }
    
    private func generateVideo() {
        generator.generateVideo(from: pptVideo) { progress in
            // 进度更新已在 generator 中处理
        } completion: { result in
            switch result {
            case .success(let url):
                generatedVideoURL = url
                showingPreview = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Slide Thumbnail View
struct SlideThumbnailView: View {
    let slide: PPTSlide
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            
            // 缩略图
            Group {
                if let imageURL = slide.expandedImageURL ?? slide.imageURL,
                   let uiImage = UIImage(contentsOfFile: imageURL) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 80, height: 60)
            .cornerRadius(8)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                if !slide.caption.isEmpty {
                    Text(slide.caption)
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    Text("无描述")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Label("\(Int(slide.duration))s", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !slide.voiceText.isEmpty {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    
                    Image(systemName: slide.transition.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Slide Editor View
struct SlideEditorView: View {
    @Binding var slide: PPTSlide
    @Environment(\.dismiss) private var dismiss
    let onDelete: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                // 图片预览
                Section {
                    if let imageURL = slide.expandedImageURL ?? slide.imageURL,
                       let uiImage = UIImage(contentsOfFile: imageURL) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit
                            .cornerRadius(12)
                            .frame(maxHeight: 200)
                    }
                }
                
                // 描述/字幕
                Section(header: Text("字幕内容")) {
                    TextEditor(text: $slide.caption)
                        .frame(minHeight: 80)
                }
                
                // 配音文本
                Section(header: Text("配音文本")) {
                    TextEditor(text: $slide.voiceText)
                        .frame(minHeight: 80)
                    
                    if slide.voiceText.isEmpty && !slide.caption.isEmpty {
                        Button("使用字幕作为配音") {
                            slide.voiceText = slide.caption
                        }
                        .font(.caption)
                    }
                }
                
                // 时长
                Section(header: Text("显示时长: \(Int(slide.duration))秒")) {
                    Slider(value: $slide.duration, in: 2...30, step: 1)
                }
                
                // 转场效果
                Section(header: Text("转场效果")) {
                    Picker("转场", selection: $slide.transition) {
                        ForEach(SlideTransition.allCases, id: \.self) { transition in
                            Label(transition.rawValue, systemImage: transition.icon)
                                .tag(transition)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // 字幕样式
                Section(header: Text("字幕样式")) {
                    Stepper("字体大小: \(Int(slide.subtitleStyle.fontSize))", value: $slide.subtitleStyle.fontSize, in: 16...72)
                    
                    Picker("动画效果", selection: $slide.subtitleStyle.animation) {
                        ForEach(SubtitleAnimation.allCases, id: \.self) { animation in
                            Text(animation.rawValue).tag(animation)
                        }
                    }
                }
                
                // 删除按钮
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除此幻灯片", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("编辑幻灯片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Generation Progress View
struct GenerationProgressView: View {
    let progress: PPTGenerationProgress
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 进度圆环
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: progress.overallProgress)
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .purple, .pink, .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress.overallProgress)
                    
                    VStack {
                        Text("\(Int(progress.overallProgress * 100))%")
                            .font(.title2.bold())
                        Text(progress.currentStep.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 状态信息
                VStack(spacing: 8) {
                    Text(progress.message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("当前步骤: \(Int(progress.stepProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 取消按钮
                Button("取消") {
                    // 取消生成
                }
                .buttonStyle(.bordered)
                .padding(.top, 16)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
    }
}

// MARK: - Video Preview View
struct VideoPreviewView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VideoPlayerView(url: videoURL)
                .navigationTitle("视频预览")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: videoURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

// MARK: - Video Player View (Placeholder)
struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        // 使用 AVPlayerViewController
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        
        // 这里应该使用 AVPlayerViewController
        // 简化实现
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
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
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onSelect(uiImage)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct PPTVideoView_Previews: PreviewProvider {
    static var previews: some View {
        PPTVideoView()
    }
}
