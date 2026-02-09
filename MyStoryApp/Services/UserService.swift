//
//  UserService.swift
//  MyStoryApp
//
//  用户服务 - 处理认证和用户管理
//

import Foundation
import Combine

class UserService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Singleton
    static let shared = UserService()
    
    // MARK: - Private Properties
    private let baseURL: String
    private var cancellables = Set<AnyCancellable>()
    private let tokenKey = "auth_token"
    private let userKey = "current_user"
    
    // MARK: - Initialization
    init(baseURL: String = "http://localhost:8000/api/v1") {
        self.baseURL = baseURL
        loadSavedUser()
    }
    
    // MARK: - Token Management
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    private func loadToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    private func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
    
    private func loadSavedUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = loadToken() != nil
        }
    }
    
    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - API Helper
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requireAuth: Bool = true
    ) -> AnyPublisher<T, Error> {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证 Token
        if requireAuth, let token = loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 401 {
                    // Token 过期，清除登录状态
                    DispatchQueue.main.async {
                        self.logout()
                    }
                    throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新登录"])
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorJson["detail"] as? String {
                        throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                    }
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Authentication
    
    /// 用户注册
    func register(email: String, username: String, password: String, nickname: String = "") -> AnyPublisher<AuthResponse, Error> {
        isLoading = true
        errorMessage = nil
        
        let request = RegisterRequest(
            email: email,
            username: username,
            password: password,
            nickname: nickname.isEmpty ? username : nickname
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            return Fail(error: URLError(.cannotEncodeContentData)).eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/register", method: "POST", body: body, requireAuth: false)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveOutput: { [weak self] (response: AuthResponse) in
                self?.saveToken(response.accessToken)
                self?.saveUser(response.user)
                self?.currentUser = response.user
                self?.isAuthenticated = true
            })
            .eraseToAnyPublisher()
    }
    
    /// 用户登录
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        isLoading = true
        errorMessage = nil
        
        let request = LoginRequest(email: email, password: password)
        
        guard let body = try? JSONEncoder().encode(request) else {
            return Fail(error: URLError(.cannotEncodeContentData)).eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/login", method: "POST", body: body, requireAuth: false)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveOutput: { [weak self] (response: AuthResponse) in
                self?.saveToken(response.accessToken)
                self?.saveUser(response.user)
                self?.currentUser = response.user
                self?.isAuthenticated = true
            })
            .eraseToAnyPublisher()
    }
    
    /// 登出
    func logout() {
        clearToken()
        clearUser()
    }
    
    /// 获取当前用户信息
    func fetchCurrentUser() -> AnyPublisher<User, Error> {
        return makeRequest(endpoint: "/auth/me")
            .handleEvents(receiveOutput: { [weak self] user in
                self?.saveUser(user)
                self?.currentUser = user
            })
            .eraseToAnyPublisher()
    }
    
    /// 更新用户信息
    func updateUser(nickname: String? = nil, avatar: String? = nil, bio: String? = nil) -> AnyPublisher<User, Error> {
        let request = UpdateUserRequest(nickname: nickname, avatar: avatar, bio: bio)
        
        guard let body = try? JSONEncoder().encode(request) else {
            return Fail(error: URLError(.cannotEncodeContentData)).eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/me", method: "PUT", body: body)
            .handleEvents(receiveOutput: { [weak self] user in
                self?.saveUser(user)
                self?.currentUser = user
            })
            .eraseToAnyPublisher()
    }
    
    /// 修改密码
    func changePassword(oldPassword: String, newPassword: String) -> AnyPublisher<[String: String], Error> {
        let request = ChangePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        
        guard let body = try? JSONEncoder().encode(request) else {
            return Fail(error: URLError(.cannotEncodeContentData)).eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/change-password", method: "POST", body: body)
    }
}
