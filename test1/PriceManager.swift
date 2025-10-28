//
//  PriceManager.swift
//  test1
//
//  Created by zl_vm on 2025/10/28.
//

import Foundation
import Combine

// 价格管理器，负责定时刷新BTC价格
@MainActor
class PriceManager: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var isFetching: Bool = false
    @Published var lastError: PriceError?

    private let priceService = PriceService()
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 30.0 // 30秒刷新一次

    init() {
        startPriceUpdates()
    }

    deinit {
        // 在deinit中不能直接调用@MainActor方法
        timer?.invalidate()
        timer = nil
    }

    // 开始定时更新价格
    func startPriceUpdates() {
        // 立即获取一次价格
        Task {
            await fetchPrice()
        }

        // 设置定时器，使用weak self避免循环引用
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchPrice()
            }
        }
    }

    // 停止价格更新
    @MainActor
    func stopPriceUpdates() {
        timer?.invalidate()
        timer = nil
    }

    // 手动刷新价格
    func refreshPrice() async {
        await fetchPrice()
    }

    // 获取价格的核心方法（带重试机制）
    private func fetchPrice() async {
        isFetching = true
        lastError = nil

        // 重试最多3次
        let maxRetries = 3

        for attempt in 1...maxRetries {
            do {
                let price = try await priceService.fetchBTCPrice()
                currentPrice = price
                break // 成功获取价格，退出重试循环
            } catch let error as PriceError {
                if attempt == maxRetries {
                    lastError = error
                } else {
                    // 等待一段时间再重试
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000)) // 递增延迟
                }
            } catch {
                if attempt == maxRetries {
                    lastError = .networkError(error)
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }

        isFetching = false
    }

    // 格式化价格显示
    var formattedPrice: String {
        if isFetching {
            return "BTC: 更新中..."
        }

        if lastError != nil {
            return "BTC: 错误"
        }

        if currentPrice == 0.0 {
            return "BTC: 加载中..."
        }

        return String(format: "BTC: $%.2f", currentPrice)
    }

    // 获取详细错误信息
    var errorMessage: String? {
        return lastError?.localizedDescription
    }
}