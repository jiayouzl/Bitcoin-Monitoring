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

                    #if DEBUG
                    print("🔐 [PriceService] 使用代理认证: \(username)")
                    #endif
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
            // 这里我们保存认证信息，可能需要使用其他方式处理认证

            #if DEBUG
            print("🔐 [PriceService] 代理认证信息已记录: \(username)")
            print("⚠️ [PriceService] 注意：macOS 代理认证可能需要系统级别配置")
            #endif
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

        #if DEBUG
        let proxyInfo = proxyEnabled ? "\(proxyHost):\(proxyPort)" : "未启用"
        let authInfo = proxyEnabled && !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
        print("🔄 [PriceService] 网络配置已更新 - 代理: \(proxyInfo)\(authInfo)")
        #endif
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
            #if DEBUG
            print("🌐 [PriceService] 代理未启用，无需测试连接")
            #endif
            return true
        }

        // 首先尝试简单的 HTTP 连接测试
        let httpTestResult = await testBasicHTTPConnection()
        if httpTestResult {
            // 如果 HTTP 连接成功，再尝试币安 API 测试
            return await testBinanceAPIConnection()
        }

        return false
    }

    /**
     * 测试基础 HTTP 连接
     * - Returns: 测试结果
     */
    private func testBasicHTTPConnection() async -> Bool {
        do {
            // 使用 httpbin.org 作为测试目标，这是一个简单的 HTTP 测试服务
            guard let testURL = URL(string: "http://httpbin.org/ip") else {
                #if DEBUG
                print("❌ [PriceService] 测试URL无效")
                #endif
                return false
            }

            var request = URLRequest(url: testURL)
            request.timeoutInterval = 10.0
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ [PriceService] 无效的HTTP响应")
                #endif
                return false
            }

            if httpResponse.statusCode == 200 {
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    print("✅ [PriceService] HTTP连接测试成功，响应: \(responseString)")
                } else {
                    print("✅ [PriceService] HTTP连接测试成功")
                }
                #endif
                return true
            } else {
                #if DEBUG
                print("❌ [PriceService] HTTP连接测试失败，状态码: \(httpResponse.statusCode)")
                #endif
                return false
            }
        } catch {
            #if DEBUG
            print("❌ [PriceService] HTTP连接测试失败: \(error.localizedDescription)")

            // 提供更详细的错误信息
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    print("🔍 [PriceService] 详细错误: 无网络连接")
                case .timedOut:
                    print("🔍 [PriceService] 详细错误: 请求超时")
                case .cannotConnectToHost:
                    print("🔍 [PriceService] 详细错误: 无法连接到代理服务器")
                case .cannotFindHost:
                    print("🔍 [PriceService] 详细错误: 找不到代理服务器地址")
                case .networkConnectionLost:
                    print("🔍 [PriceService] 详细错误: 网络连接丢失")
                case .userAuthenticationRequired:
                    print("🔍 [PriceService] 详细错误: 代理认证失败，请检查用户名和密码")
                case .secureConnectionFailed:
                    print("🔍 [PriceService] 详细错误: 安全连接失败")
                default:
                    print("🔍 [PriceService] 详细错误: \(urlError.localizedDescription)")
                }
            }
            #endif
            return false
        }
    }

    /**
     * 测试币安API连接
     * - Returns: 测试结果
     */
    private func testBinanceAPIConnection() async -> Bool {
        do {
            // 尝试获取一个测试币种的价格来验证代理连接
            _ = try await fetchPrice(for: .btc)
            #if DEBUG
            print("✅ [PriceService] 币安API连接测试成功")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ [PriceService] 币安API连接测试失败: \(error.localizedDescription)")
            #endif
            return false
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
