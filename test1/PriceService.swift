//
//  PriceService.swift
//  test1
//
//  Created by Mark on 2025/10/28.
//

import Foundation

// 网络服务类，负责从币安API获取BTC价格
class PriceService: ObservableObject {
    private let baseURL = "https://api.binance.com/api/v3/ticker/price"
    private let session = URLSession.shared

    // 获取BTC价格
    func fetchBTCPrice() async throws -> Double {
        let urlString = "\(baseURL)?symbol=BTCUSDT"
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
        let priceResponse = try decoder.decode(BTCPriceResponse.self, from: data)

        // 转换价格为Double类型
        guard let price = Double(priceResponse.price) else {
            throw PriceError.invalidPrice
        }

        return price
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
