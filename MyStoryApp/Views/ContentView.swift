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
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 创作页面
            CreateStoryView(storyManager: storyManager)
                .tabItem {
                    Label("创作", systemImage: "plus.circle.fill")
                }
                .tag(0)
            
            // 我的故事列表
            MyStoriesView(storyManager: storyManager)
                .tabItem {
                    Label("我的故事", systemImage: "film.fill")
                }
                .tag(1)
            
            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(.pink)
    }
}

#Preview {
    ContentView()
}
