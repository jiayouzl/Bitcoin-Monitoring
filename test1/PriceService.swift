//
//  PriceService.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/28.
//

import Foundation

// 网络服务类，负责从币安API获取币种价格
class PriceService: ObservableObject {
    private let baseURL = "https://api.binance.com/api/v3/ticker/price"
    private var session: URLSession // 改为 var 以便重新创建
    private let appSettings: AppSettings

    @MainActor
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        self.session = Self.createURLSession(
            proxyEnabled: appSettings.proxyEnabled,
            proxyHost: appSettings.proxyHost,
            proxyPort: appSettings.proxyPort
        )
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
     * - Returns: 配置好的URLSession
     */
    private static func createURLSession(proxyEnabled: Bool, proxyHost: String, proxyPort: Int) -> URLSession {
        let configuration = URLSessionConfiguration.default

        // 如果启用了代理，配置代理设置
        if proxyEnabled {
            let proxyDict = createProxyDictionary(
                host: proxyHost,
                port: proxyPort
            )
            configuration.connectionProxyDictionary = proxyDict

            #if DEBUG
            print("🌐 [PriceService] 已配置代理: \(proxyHost):\(proxyPort)")
            #endif
        }

        // 设置请求超时时间
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0

        return URLSession(configuration: configuration)
    }

    /**
     * 创建代理配置字典
     * - Parameters:
     *   - host: 代理服务器地址
     *   - port: 代理服务器端口
     * - Returns: 代理配置字典
     */
    private static func createProxyDictionary(host: String, port: Int) -> [AnyHashable: Any] {
        return [
            kCFNetworkProxiesHTTPEnable: 1,
            kCFNetworkProxiesHTTPProxy: host,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPSEnable: 1,
            kCFNetworkProxiesHTTPSProxy: host,
            kCFNetworkProxiesHTTPSPort: port
        ]
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

        // 重新创建 URLSession 以应用新的代理设置
        let newSession = Self.createURLSession(
            proxyEnabled: proxyEnabled,
            proxyHost: proxyHost,
            proxyPort: proxyPort
        )

        self.session = newSession

        #if DEBUG
        print("🔄 [PriceService] 网络配置已更新 - 代理: \(proxyEnabled ? "\(proxyHost):\(proxyPort)" : "未启用")")
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

        do {
            // 尝试获取一个测试币种的价格来验证代理连接
            _ = try await fetchPrice(for: .btc)
            #if DEBUG
            print("✅ [PriceService] 代理连接测试成功")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ [PriceService] 代理连接测试失败: \(error.localizedDescription)")
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
