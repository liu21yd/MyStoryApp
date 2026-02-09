//
//  SettingsView.swift
//  MyStoryApp
//
//  设置页面
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("selectedAPI") private var selectedAPI = "kling"
    @AppStorage("autoSaveDraft") private var autoSaveDraft = true
    @AppStorage("highQuality") private var highQuality = true
    @State private var showClearCacheConfirmation = false
    @State private var showAboutSheet = false
    
    let apiOptions = [
        ("kling", "可灵 AI (快手)"),
        ("dreamina", "即梦 AI (字节跳动)"),
        ("runway", "Runway ML"),
        ("pika", "Pika Labs")
    ]
    
    var body: some View {
        NavigationView {
            List {
                // API 配置
                Section(header: Text("AI 视频生成配置")) {
                    Picker("选择 API", selection: $selectedAPI) {
                        ForEach(apiOptions, id: \.0) { key, name in
                            Text(name).tag(key)
                        }
                    }
                    
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    Button("测试连接") {
                        testAPIConnection()
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                // 视频质量设置
                Section(header: Text("视频设置")) {
                    Toggle("高清模式", isOn: $highQuality)
                    
                    if highQuality {
                        Text("生成更高质量的视频，但耗时更长")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 草稿设置
                Section(header: Text("草稿设置")) {
                    Toggle("自动保存草稿", isOn: $autoSaveDraft)
                    
                    if autoSaveDraft {
                        Text("退出应用时自动保存未完成的创作")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 存储管理
                Section(header: Text("存储管理")) {
                    HStack {
                        Text("已用空间")
                        Spacer()
                        Text(calculateStorageSize())
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showClearCacheConfirmation = true
                    } label: {
                        Text("清除缓存")
                    }
                }
                
                // 关于
                Section(header: Text("关于")) {
                    Button {
                        showAboutSheet = true
                    } label: {
                        HStack {
                            Text("关于我的故事")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .alert("清除缓存", isPresented: $showClearCacheConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("这将删除所有缓存的视频预览和临时文件，但不会删除已生成的视频。")
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
        }
    }
    
    private func testAPIConnection() {
        // 测试API连接
        print("测试 \(selectedAPI) API 连接...")
        // 实际实现需要调用API测试接口
    }
    
    private func calculateStorageSize() -> String {
        // 计算存储空间
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let path = paths.first?.path else { return "0 MB" }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            var totalSize: UInt64 = 0
            
            for file in contents {
                let filePath = (path as NSString).appendingPathComponent(file)
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                if let size = attributes[.size] as? UInt64 {
                    totalSize += size
                }
            }
            
            let mb = Double(totalSize) / 1024 / 1024
            return String(format: "%.1f MB", mb)
        } catch {
            return "未知"
        }
    }
    
    private func clearCache() {
        // 清除缓存文件
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cachePath = paths.first else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: nil)
            for file in contents {
                try FileManager.default.removeItem(at: file)
            }
            print("缓存已清除")
        } catch {
            print("清除缓存失败: \(error)")
        }
    }
}

// MARK: - 关于页面
struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App 图标
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.pink.opacity(0.1))
                        )
                    
                    // 标题
                    VStack(spacing: 8) {
                        Text("我的故事")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 描述
                    Text("用AI将您的照片和文字转化为生动的短视频。记录生活中的美好瞬间，创造属于您的独特故事。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // 功能列表
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "wand.and.stars", title: "AI视频生成", description: "智能将照片转化为流畅视频")
                        FeatureRow(icon: "paintbrush", title: "多种风格", description: "电影感、动漫、复古等多种风格")
                        FeatureRow(icon: "text.bubble", title: "智能配文", description: "根据情感自动生成视频配文")
                        FeatureRow(icon: "share", title: "一键分享", description: "快速分享到社交媒体")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // 开发者信息
                    VStack(spacing: 8) {
                        Text("开发者")
                            .font(.headline)
                        
                        Text("OpenClaw AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    // 版权信息
                    Text("© 2026 我的故事. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .navigationTitle("关于")
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
}

// MARK: - 功能行
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.pink)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
