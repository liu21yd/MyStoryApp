//
//  MaterialLibraryView.swift
//  MyStoryApp
//
//  素材库视图
//

import SwiftUI

struct MaterialLibraryView: View {
    @StateObject private var materialService = MaterialService.shared
    @StateObject private var userService = UserService.shared
    
    @State private var selectedType: MaterialTypeFilter = .all
    @State private var showUploadSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showLoginAlert = false
    @State private var selectedMaterial: Material?
    @State private var showMaterialDetail = false
    
    enum MaterialTypeFilter: String, CaseIterable {
        case all = "全部"
        case image = "图片"
        case video = "视频"
        case audio = "音频"
        
        var apiValue: String? {
            switch self {
            case .all: return nil
            case .image: return "image"
            case .video: return "video"
            case .audio: return "audio"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 类型筛选
                typeFilterBar
                
                // 素材列表
                if materialService.materials.isEmpty && !materialService.isLoading {
                    emptyView
                } else {
                    materialGrid
                }
            }
            .navigationTitle("素材库")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleUpload) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    selectedImage = image
                    showUploadSheet = true
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                if let image = selectedImage {
                    UploadMaterialView(image: image) { material in
                        // 上传成功后刷新列表
                        loadMaterials()
                    }
                }
            }
            .alert("需要登录", isPresented: $showLoginAlert) {
                Button("取消", role: .cancel) {}
                Button("去登录") {
                    // 可以在这里导航到登录页面
                }
            } message: {
                Text("请先登录后再使用素材库功能")
            }
            .onAppear {
                loadMaterials()
            }
            .onChange(of: selectedType) { _ in
                loadMaterials()
            }
        }
    }
    
    // MARK: - 类型筛选栏
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MaterialTypeFilter.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue,
                        isSelected: selectedType == type
                    ) {
                        withAnimation {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 素材网格
    private var materialGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(materialService.materials) { material in
                    MaterialCard(material: material)
                        .onTapGesture {
                            selectedMaterial = material
                            showMaterialDetail = true
                        }
                        .contextMenu {
                            Button {
                                toggleFavorite(material)
                            } label: {
                                Label(
                                    material.isFavorite ? "取消收藏" : "收藏",
                                    systemImage: material.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            
                            Button(role: .destructive) {
                                deleteMaterial(material)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
        .sheet(item: $selectedMaterial) { material in
            MaterialDetailView(material: material)
        }
    }
    
    // MARK: - 空视图
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("暂无素材")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 上传你的第一张图片")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - 加载素材
    private func loadMaterials() {
        guard userService.isAuthenticated else { return }
        
        materialService.fetchMaterials(
            type: selectedType.apiValue,
            page: 1
        )
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )
        .store(in: &materialService.cancellables)
    }
    
    // MARK: - 处理上传
    private func handleUpload() {
        if !userService.isAuthenticated {
            showLoginAlert = true
            return
        }
        showImagePicker = true
    }
    
    // MARK: - 收藏/取消收藏
    private func toggleFavorite(_ material: Material) {
        materialService.toggleFavorite(material: material)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    loadMaterials()
                }
            )
            .store(in: &materialService.cancellables)
    }
    
    // MARK: - 删除素材
    private func deleteMaterial(_ material: Material) {
        materialService.deleteMaterial(id: material.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    loadMaterials()
                }
            )
            .store(in: &materialService.cancellables)
    }
}

// MARK: - 筛选芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.pink : Color(.secondarySystemBackground))
                .cornerRadius(20)
        }
    }
}

// MARK: - 素材卡片
struct MaterialCard: View {
    let material: Material
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 缩略图
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(1, contentMode: .fill)
                
                if material.materialType == "image" || material.materialType == "expanded_image" {
                    AsyncImage(url: URL(string: material.fileUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: material.icon)
                        .font(.largeTitle)
                        .foregroundColor(.pink)
                }
                
                // 收藏标记
                if material.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(material.title)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(material.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 上传素材视图
struct UploadMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onComplete: (Material) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var tags = ""
    @StateObject private var materialService = MaterialService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("预览")) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
                
                Section(header: Text("信息")) {
                    TextField("标题", text: $title)
                    TextField("描述（可选）", text: $description)
                    TextField("标签（用逗号分隔）", text: $tags)
                }
            }
            .navigationTitle("上传素材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("上传") { upload() }
                        .disabled(title.isEmpty || materialService.isLoading)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if materialService.isLoading {
                    LoadingOverlay(message: "上传中...")
                }
            }
        }
    }
    
    private func upload() {
        let tagArray = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        materialService.uploadMaterial(
            image: image,
            title: title,
            description: description,
            tags: tagArray
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            },
            receiveValue: { material in
                onComplete(material)
                dismiss()
            }
        )
        .store(in: &materialService.cancellables)
    }
}

// MARK: - 素材详情视图
struct MaterialDetailView: View {
    let material: Material
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 大图预览
                    if material.materialType == "image" {
                        AsyncImage(url: URL(string: material.fileUrl)) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxHeight: 400)
                    }
                    
                    // 信息卡片
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(title: "标题", value: material.title)
                        InfoRow(title: "类型", value: material.materialType)
                        InfoRow(title: "大小", value: material.formattedSize)
                        InfoRow(title: "格式", value: material.fileFormat)
                        InfoRow(title: "上传时间", value: formatDate(material.createdAt))
                        
                        if !material.tags.isEmpty {
                            Text("标签")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(material.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.pink.opacity(0.2))
                                        .foregroundColor(.pink)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("素材详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 信息流布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - 预览
struct MaterialLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        MaterialLibraryView()
    }
}
