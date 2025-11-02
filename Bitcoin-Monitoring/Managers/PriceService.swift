//
//  PriceService.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/28.
//

import Foundation
import AuthenticationServices

// 网络服务类，负责从币安API获取币种价格
class PriceService: NSObject, ObservableObject, URLSessionTaskDelegate {
    private let baseURL = "https://api.binance.com/api/v3/ticker/price"
    private var session: URLSession! // 改为 var 以便重新创建
    private let appSettings: AppSettings

    @MainActor
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        super.init()
        self.session = createURLSessionWithDelegate(
            proxyEnabled: appSettings.proxyEnabled,
            proxyHost: appSettings.proxyHost,
            proxyPort: appSettings.proxyPort,
            proxyUsername: appSettings.proxyUsername,
            proxyPassword: appSettings.proxyPassword
        )
    }

    /**
     * 创建带有代理认证的 URLSession（实例方法）
     * - Parameters:
     *   - proxyEnabled: 是否启用代理
     *   - proxyHost: 代理服务器地址
     *   - proxyPort: 代理服务器端口
     *   - proxyUsername: 代理认证用户名
     *   - proxyPassword: 代理认证密码
     * - Returns: 配置好的URLSession
     */
    @MainActor
    private func createURLSessionWithDelegate(proxyEnabled: Bool, proxyHost: String, proxyPort: Int, proxyUsername: String, proxyPassword: String) -> URLSession {
        let configuration = URLSessionConfiguration.default

        // 如果启用了代理，配置代理设置
        if proxyEnabled {
            let proxyDict = Self.createProxyDictionary(
                host: proxyHost,
                port: proxyPort,
                username: proxyUsername,
                password: proxyPassword
            )
            configuration.connectionProxyDictionary = proxyDict

            #if DEBUG
            let authInfo = !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
            print("🌐 [PriceService] 已配置代理: \(proxyHost):\(proxyPort)\(authInfo)")
            #endif
        }

        // 设置请求超时时间
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0

        // 创建代理认证凭证存储
        if proxyEnabled && !proxyUsername.isEmpty && !proxyPassword.isEmpty {
            let credential = URLCredential(user: proxyUsername, password: proxyPassword, persistence: .forSession)
            let protectionSpace = URLProtectionSpace(
                host: proxyHost,
                port: proxyPort,
                protocol: "http",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: protectionSpace)

            // 为HTTPS也设置
            let httpsProtectionSpace = URLProtectionSpace(
                host: proxyHost,
                port: proxyPort,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: httpsProtectionSpace)

            #if DEBUG
            print("🔐 [PriceService] 已设置代理认证凭证")
            #endif
        }

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /**
     * 创建专门的测试 URLSession
     * - Returns: 配置好的测试 URLSession
     */
    @MainActor
    private func createTestURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 15.0

        // 配置代理设置
        if appSettings.proxyEnabled {
            let proxyDict = Self.createProxyDictionary(
                host: appSettings.proxyHost,
                port: appSettings.proxyPort,
                username: appSettings.proxyUsername,
                password: appSettings.proxyPassword
            )
            configuration.connectionProxyDictionary = proxyDict
        }

        // 创建代理认证凭证存储
        if appSettings.proxyEnabled && !appSettings.proxyUsername.isEmpty && !appSettings.proxyPassword.isEmpty {
            let credential = URLCredential(user: appSettings.proxyUsername, password: appSettings.proxyPassword, persistence: .forSession)
            let protectionSpace = URLProtectionSpace(
                host: appSettings.proxyHost,
                port: appSettings.proxyPort,
                protocol: "http",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: protectionSpace)

            // 为HTTPS也设置
            let httpsProtectionSpace = URLProtectionSpace(
                host: appSettings.proxyHost,
                port: appSettings.proxyPort,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: httpsProtectionSpace)
        }

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - URLSessionTaskDelegate

    /**
     * 处理代理认证挑战
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {

            // 获取代理认证信息
            Task { @MainActor in
                let username = appSettings.proxyUsername
                let password = appSettings.proxyPassword

                if !username.isEmpty && !password.isEmpty {
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    completionHandler(.useCredential, credential)
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // 获取指定币种价格
    func fetchPrice(for symbol: CryptoSymbol) async throws -> Double {
        let urlString = "\(baseURL)?symbol=\(symbol.apiSymbol)"
        guard let url = URL(string: urlString) else {
            throw PriceError.invalidURL
        }

        // 发送网络请求
        let (data, response) = try await session.data(from: url)

        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PriceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PriceError.serverError(httpResponse.statusCode)
        }

        // 解析JSON数据
        let decoder = JSONDecoder()
        let priceResponse = try decoder.decode(TickerPriceResponse.self, from: data)

        // 转换价格为Double类型
        guard let price = Double(priceResponse.price) else {
            throw PriceError.invalidPrice
        }

        return price
    }

    // MARK: - 代理配置相关方法

    /**
     * 根据应用设置创建配置了代理的URLSession
     * - Parameters:
     *   - proxyEnabled: 是否启用代理
     *   - proxyHost: 代理服务器地址
     *   - proxyPort: 代理服务器端口
     *   - proxyUsername: 代理认证用户名
     *   - proxyPassword: 代理认证密码
     * - Returns: 配置好的URLSession
     */
    private static func createURLSession(proxyEnabled: Bool, proxyHost: String, proxyPort: Int, proxyUsername: String, proxyPassword: String) -> URLSession {
        let configuration = URLSessionConfiguration.default

        // 如果启用了代理，配置代理设置
        if proxyEnabled {
            let proxyDict = createProxyDictionary(
                host: proxyHost,
                port: proxyPort,
                username: proxyUsername,
                password: proxyPassword
            )
            configuration.connectionProxyDictionary = proxyDict

            #if DEBUG
            let authInfo = !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
            print("🌐 [PriceService] 已配置代理: \(proxyHost):\(proxyPort)\(authInfo)")
            #endif
        }

        // 设置请求超时时间
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0

        // 创建代理认证凭证存储
        if proxyEnabled && !proxyUsername.isEmpty && !proxyPassword.isEmpty {
            let credential = URLCredential(user: proxyUsername, password: proxyPassword, persistence: .forSession)
            let protectionSpace = URLProtectionSpace(
                host: proxyHost,
                port: proxyPort,
                protocol: "http",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: protectionSpace)

            // 为HTTPS也设置
            let httpsProtectionSpace = URLProtectionSpace(
                host: proxyHost,
                port: proxyPort,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            URLCredentialStorage.shared.setDefaultCredential(credential, for: httpsProtectionSpace)

            #if DEBUG
            print("🔐 [PriceService] 已设置代理认证凭证")
            #endif
        }

        // 注意：由于需要使用 delegate，我们需要在实例方法中创建 URLSession
        // 这里返回一个临时的配置，实际的 URLSession 将在 updateNetworkConfiguration 中创建
        return URLSession(configuration: configuration)
    }

    /**
     * 创建代理配置字典
     * - Parameters:
     *   - host: 代理服务器地址
     *   - port: 代理服务器端口
     *   - username: 代理认证用户名
     *   - password: 代理认证密码
     * - Returns: 代理配置字典
     */
    private static func createProxyDictionary(host: String, port: Int, username: String, password: String) -> [AnyHashable: Any] {
        let proxyDict: [AnyHashable: Any] = [
            kCFNetworkProxiesHTTPEnable: 1,
            kCFNetworkProxiesHTTPProxy: host,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPSEnable: 1,
            kCFNetworkProxiesHTTPSProxy: host,
            kCFNetworkProxiesHTTPSPort: port
        ]

        // 如果提供了用户名和密码，添加认证信息
        if !username.isEmpty && !password.isEmpty {
            // 注意：macOS 系统级别的代理认证需要通过系统偏好设置处理
            // URLSession 的代理字典主要用于配置代理服务器，认证信息通常由系统管理
        }

        return proxyDict
    }

    /**
     * 更新网络配置（当代理设置发生变化时调用）
     */
    @MainActor
    func updateNetworkConfiguration() {
        // 获取代理设置值（在 MainActor 上下文中）
        let proxyEnabled = appSettings.proxyEnabled
        let proxyHost = appSettings.proxyHost
        let proxyPort = appSettings.proxyPort
        let proxyUsername = appSettings.proxyUsername
        let proxyPassword = appSettings.proxyPassword

        // 重新创建 URLSession 以应用新的代理设置
        let newSession = createURLSessionWithDelegate(
            proxyEnabled: proxyEnabled,
            proxyHost: proxyHost,
            proxyPort: proxyPort,
            proxyUsername: proxyUsername,
            proxyPassword: proxyPassword
        )

        self.session = newSession

            }

    /**
     * 测试代理连接
     * - Returns: 测试结果
     */
    func testProxyConnection() async -> Bool {
        let proxyEnabled = await MainActor.run {
            return appSettings.proxyEnabled
        }

        guard proxyEnabled else {
            return true
        }

        // 直接测试币安API，简化流程
        return await testBinanceAPIConnection()
    }

    
    /**
     * 测试币安API连接
     * - Returns: 测试结果
     */
    @MainActor
    private func testBinanceAPIConnection() async -> Bool {
        return await withCheckedContinuation { continuation in
            // 使用专门的测试会话
            let testSession = createTestURLSession()

            guard let testURL = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT") else {
                continuation.resume(returning: false)
                return
            }

            var request = URLRequest(url: testURL)
            request.timeoutInterval = 10.0
            request.httpMethod = "GET"

            let task = testSession.dataTask(with: request) { data, response, error in
                if error != nil {
                    continuation.resume(returning: false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(returning: false)
                    return
                }

                if httpResponse.statusCode == 200 {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }

            task.resume()
        }
    }
}

// 价格服务错误类型
enum PriceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case invalidPrice
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .serverError(let code):
            return "服务器错误，状态码：\(code)"
        case .invalidPrice:
            return "无效的价格数据"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
