//
//  ProfileView.swift
//  MyStoryApp
//
//  个人中心视图
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var userService = UserService.shared
    @StateObject private var materialService = MaterialService.shared
    @State private var showLogin = false
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if userService.isAuthenticated, let user = userService.currentUser {
                        // 已登录状态
                        userInfoCard(user: user)
                        storageCard(user: user)
                        actionButtons
                    } else {
                        // 未登录状态
                        notLoggedInView
                    }
                }
                .padding()
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .alert("确认退出", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    userService.logout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }
    
    // MARK: - 用户信息卡片
    private func userInfoCard(user: User) -> some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if user.avatar.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.pink)
                } else {
                    AsyncImage(url: URL(string: user.avatar)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                }
            }
            
            // 用户名和昵称
            VStack(spacing: 4) {
                Text(user.nickname.isEmpty ? user.username : user.nickname)
                    .font(.title2.bold())
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 统计
            HStack(spacing: 32) {
                StatItem(title: "视频", value: user.totalVideos)
                StatItem(title: "图片", value: user.totalImages)
                StatItem(title: "存储", value: user.formattedStorage, isText: true)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 存储空间卡片
    private func storageCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                
                Text("存储空间")
                    .font(.headline)
                
                Spacer()
                
                Text(user.formattedStorage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(storageColor(used: Double(user.storageUsed)))
                        .frame(width: min(CGFloat(user.storageUsed) / 1_073_741_824 * geometry.size.width / 10, geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("已使用 \(user.formattedStorage)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func storageColor(used: Double) -> Color {
        let gb = used / 1_073_741_824
        if gb > 8 {
            return .red
        } else if gb > 5 {
            return .orange
        } else {
            return .green
        }
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            ProfileButton(
                title: "编辑资料",
                icon: "pencil",
                color: .blue
            ) {
                showEditProfile = true
            }
            
            ProfileButton(
                title: "修改密码",
                icon: "lock",
                color: .orange
            ) {
                showChangePassword = true
            }
            
            ProfileButton(
                title: "退出登录",
                icon: "arrow.right.square",
                color: .red
            ) {
                showLogoutConfirm = true
            }
        }
    }
    
    // MARK: - 未登录视图
    private var notLoggedInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.pink.opacity(0.5))
            
            Text("未登录")
                .font(.title2.bold())
            
            Text("登录后可以同步你的素材和视频")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showLogin = true }) {
                Text("立即登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .padding(.top, 60)
    }
}

// MARK: - 统计项
struct StatItem: View {
    let title: String
    let value: Int
    var isText: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            if isText {
                Text("\(value)")
                    .font(.title3.bold())
            } else {
                Text("\(value)")
                    .font(.title3.bold())
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 个人资料按钮
struct ProfileButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - 编辑资料视图
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userService = UserService.shared
    
    @State private var nickname = ""
    @State private var bio = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("昵称", text: $nickname)
                    TextField("简介", text: $bio)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveProfile() }
                        .disabled(nickname.isEmpty)
                }
            }
            .onAppear {
                if let user = userService.currentUser {
                    nickname = user.nickname
                    bio = user.bio
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if userService.isLoading {
                    LoadingOverlay(message: "保存中...")
                }
            }
        }
    }
    
    private func saveProfile() {
        userService.updateUser(nickname: nickname, bio: bio)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                },
                receiveValue: { _ in
                    dismiss()
                }
            )
            .store(in: &userService.cancellables)
    }
}

// MARK: - 预览
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
