//
//  LoginView.swift
//  MyStoryApp
//
//  登录/注册视图
//

import SwiftUI
import Combine

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userService = UserService.shared
    
    @State private var isLogin = true
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    logoSection
                    
                    // 表单
                    formSection
                    
                    // 操作按钮
                    actionButton
                    
                    // 切换登录/注册
                    toggleButton
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
            }
            .navigationTitle(isLogin ? "登录" : "注册")
            .navigationBarTitleDisplayMode(.large)
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if userService.isLoading {
                    LoadingOverlay(message: isLogin ? "登录中..." : "注册中...")
                }
            }
        }
    }
    
    // MARK: - Logo
    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)
            
            Text("我的故事")
                .font(.largeTitle.bold())
            
            Text(isLogin ? "欢迎回来" : "创建新账号")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 表单
    private var formSection: some View {
        VStack(spacing: 16) {
            // 邮箱
            TextField("邮箱", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            
            // 用户名（仅注册）
            if !isLogin {
                TextField("用户名", text: $username)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                
                TextField("昵称（可选）", text: $nickname)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            // 密码
            SecureField("密码", text: $password)
                .textContentType(isLogin ? .password : .newPassword)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            
            // 确认密码（仅注册）
            if !isLogin {
                SecureField("确认密码", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 操作按钮
    private var actionButton: some View {
        Button(action: handleAction) {
            Text(isLogin ? "登录" : "注册")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .cornerRadius(12)
        }
        .disabled(!isFormValid || userService.isLoading)
        .opacity(isFormValid ? 1 : 0.6)
    }
    
    // MARK: - 切换按钮
    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                isLogin.toggle()
                clearFields()
            }
        }) {
            Text(isLogin ? "还没有账号？立即注册" : "已有账号？立即登录")
                .font(.subheadline)
                .foregroundColor(.pink)
        }
    }
    
    // MARK: - 表单验证
    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty {
            return false
        }
        
        if !isLogin {
            if username.isEmpty || confirmPassword.isEmpty {
                return false
            }
            if password != confirmPassword {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - 处理操作
    private func handleAction() {
        if isLogin {
            login()
        } else {
            register()
        }
    }
    
    private func login() {
        userService.login(email: email, password: password)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                },
                receiveValue: { response in
                    dismiss()
                }
            )
            .store(in: &userService.cancellables)
    }
    
    private func register() {
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            showError = true
            return
        }
        
        userService.register(
            email: email,
            username: username,
            password: password,
            nickname: nickname.isEmpty ? username : nickname
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            },
            receiveValue: { response in
                dismiss()
            }
        )
        .store(in: &userService.cancellables)
    }
    
    private func clearFields() {
        password = ""
        confirmPassword = ""
        errorMessage = ""
    }
}

// MARK: - 加载遮罩
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - 预览
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
