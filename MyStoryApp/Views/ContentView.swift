//
//  ContentView.swift
//  MyStoryApp
//
//  主界面 - 故事创作流程
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var storyManager = StoryManager()
    @StateObject private var userService = UserService.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 创作页面
            CreateStoryView(storyManager: storyManager)
                .tabItem {
                    Label("创作", systemImage: "plus.circle.fill")
                }
                .tag(0)
            
            // PPT视频生成
            PPTVideoView()
                .tabItem {
                    Label("PPT视频", systemImage: "photo.stack.fill")
                }
                .tag(1)
            
            // 素材库
            MaterialLibraryView()
                .tabItem {
                    Label("素材库", systemImage: "folder.fill")
                }
                .tag(2)
            
            // 我的故事列表
            MyStoriesView(storyManager: storyManager)
                .tabItem {
                    Label("我的故事", systemImage: "film.fill")
                }
                .tag(3)
            
            // 个人中心
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.pink)
    }
}

#Preview {
    ContentView()
}
