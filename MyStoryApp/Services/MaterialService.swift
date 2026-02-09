//
//  MaterialService.swift
//  MyStoryApp
//
//  素材管理服务
//

import Foundation
import Combine
import UIKit

class MaterialService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var materials: [Material] = []
    @Published var videoTasks: [VideoTaskItem] = []
    @Published var isLoading: Bool = false
    @Published var totalCount: Int = 0
    @Published var currentPage: Int = 1
    
    // MARK: - Singleton
    static let shared = MaterialService()
    
    // MARK: - Private Properties
    private let baseURL: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(baseURL: String = "http://localhost:8000/api/v1") {
        self.baseURL = baseURL
    }
    
    // MARK: - API Helper
    private func getToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) -> AnyPublisher<T, Error> {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let token = getToken() else {
            return Fail(error: NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登录"])).eraseToAnyPublisher()
        }
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
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
    
    // MARK: - 素材列表
    
    /// 获取素材列表
    func fetchMaterials(
        type: String? = nil,
        page: Int = 1,
        pageSize: Int = 20,
        isFavorite: Bool? = nil
    ) -> AnyPublisher<MaterialListResponse, Error> {
        isLoading = true
        
        var components = URLComponents(string: "\(baseURL)/materials/list")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        if let type = type {
            queryItems.append(URLQueryItem(name: "material_type", value: type))
        }
        
        if let isFavorite = isFavorite {
            queryItems.append(URLQueryItem(name: "is_favorite", value: isFavorite ? "true" : "false"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(getToken() ?? "")", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: MaterialListResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveOutput: { [weak self] response in
                if page == 1 {
                    self?.materials = response.items
                } else {
                    self?.materials.append(contentsOf: response.items)
                }
                self?.totalCount = response.total
                self?.currentPage = page
            })
            .eraseToAnyPublisher()
    }
    
    /// 获取素材详情
    func fetchMaterialDetail(id: Int) -> AnyPublisher<Material, Error> {
        return makeRequest(endpoint: "/materials/\(id)")
    }
    
    /// 更新素材
    func updateMaterial(id: Int, title: String? = nil, description: String? = nil, tags: [String]? = nil, isFavorite: Bool? = nil) -> AnyPublisher<Material, Error> {
        let request = UpdateMaterialRequest(
            title: title,
            description: description,
            tags: tags,
            isFavorite: isFavorite
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            return Fail(error: URLError(.cannotEncodeContentData)).eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/materials/\(id)", method: "PUT", body: body)
    }
    
    /// 删除素材
    func deleteMaterial(id: Int) -> AnyPublisher<[String: String], Error> {
        return makeRequest(endpoint: "/materials/\(id)", method: "DELETE")
    }
    
    /// 切换收藏状态
    func toggleFavorite(material: Material) -> AnyPublisher<Material, Error> {
        return updateMaterial(id: material.id, isFavorite: !material.isFavorite)
    }
    
    // MARK: - 素材上传
    
    /// 上传素材
    func uploadMaterial(
        image: UIImage,
        title: String? = nil,
        description: String? = nil,
        type: String = "image",
        tags: [String] = []
    ) -> AnyPublisher<Material, Error> {
        
        guard let token = getToken() else {
            return Fail(error: NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登录"])).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "\(baseURL)/materials/upload") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            return Fail(error: NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片编码失败"])).eraseToAnyPublisher()
        }
        
        // 构建 multipart/form-data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // 添加文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加标题
        if let title = title {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
            body.append(title.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // 添加描述
        if let description = description {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
            body.append(description.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // 添加类型
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"material_type\"\r\n\r\n".data(using: .utf8)!)
        body.append(type.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加标签
        if !tags.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"tags\"\r\n\r\n".data(using: .utf8)!)
            body.append(tags.joined(separator: ",").data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: Material.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - 视频任务
    
    /// 获取视频任务列表
    func fetchVideoTasks(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<[VideoTaskItem], Error> {
        var components = URLComponents(string: "\(baseURL)/materials/tasks/list")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(getToken() ?? "")", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [VideoTaskItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] tasks in
                if page == 1 {
                    self?.videoTasks = tasks
                } else {
                    self?.videoTasks.append(contentsOf: tasks)
                }
            })
            .eraseToAnyPublisher()
    }
}
