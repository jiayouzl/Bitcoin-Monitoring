//
//  PriceManager.swift
//  test1
//
//  Created by Mark on 2025/10/28.
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
    private var currentRefreshInterval: TimeInterval = 30.0 // 当前刷新间隔

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
        #if DEBUG
        print("⏰ [BTC Price Manager] 启动定时器，刷新间隔: \(Int(currentRefreshInterval))秒")
        #endif

        // 立即获取一次价格
        Task {
            await fetchPrice()
        }

        // 设置定时器，使用weak self避免循环引用
        timer = Timer.scheduledTimer(withTimeInterval: currentRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchPrice()
            }
        }

        #if DEBUG
        print("✅ [BTC Price Manager] 定时器启动成功")
        #endif
    }

    // 停止价格更新
    @MainActor
    func stopPriceUpdates() {
        #if DEBUG
        print("⏹️ [BTC Price Manager] 停止定时器")
        #endif

        timer?.invalidate()
        timer = nil

        #if DEBUG
        print("✅ [BTC Price Manager] 定时器已停止")
        #endif
    }

    // 手动刷新价格
    func refreshPrice() async {
        #if DEBUG
        print("🔄 [BTC Price Manager] 用户手动刷新价格")
        #endif

        await fetchPrice()
    }

    // 获取价格的核心方法（带重试机制）
    private func fetchPrice() async {
        isFetching = true
        lastError = nil

        #if DEBUG
        print("🔄 [BTC Price Manager] 开始获取价格...")
        #endif

        // 重试最多3次
        let maxRetries = 3

        for attempt in 1...maxRetries {
            #if DEBUG
            print("📡 [BTC Price Manager] 尝试获取价格 (第\(attempt)次)")
            #endif

            do {
                let price = try await priceService.fetchBTCPrice()
                currentPrice = price

                #if DEBUG
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                let currentTime = formatter.string(from: Date())
                print("✅ [BTC Price Manager] 价格更新成功: $\(String(format: "%.2f", price)) | 时间: \(currentTime)")
                #endif

                break // 成功获取价格，退出重试循环
            } catch let error as PriceError {
                #if DEBUG
                print("❌ [BTC Price Manager] 价格获取失败 (第\(attempt)次): \(error.localizedDescription)")
                #endif

                if attempt == maxRetries {
                    lastError = error
                } else {
                    // 等待一段时间再重试
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000)) // 递增延迟
                }
            } catch {
                #if DEBUG
                print("❌ [BTC Price Manager] 网络错误 (第\(attempt)次): \(error.localizedDescription)")
                #endif

                if attempt == maxRetries {
                    lastError = .networkError(error)
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }

        isFetching = false

        #if DEBUG
        if let error = lastError {
            print("⚠️ [BTC Price Manager] 价格获取流程结束，最终失败: \(error.localizedDescription)")
        } else {
            print("✅ [BTC Price Manager] 价格获取流程结束，成功")
        }
        #endif
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

    // MARK: - Refresh Interval Configuration

    /// 更新刷新间隔
    /// - Parameter interval: 新的刷新间隔
    func updateRefreshInterval(_ interval: RefreshInterval) {
        let oldInterval = RefreshInterval.allCases.first { $0.rawValue == currentRefreshInterval }?.displayText ?? "未知"

        #if DEBUG
        print("⏱️ [BTC Price Manager] 刷新间隔变更: \(oldInterval) → \(interval.displayText)")
        #endif

        currentRefreshInterval = interval.rawValue

        // 如果定时器正在运行，重启它以应用新的间隔
        if timer != nil {
            #if DEBUG
            print("🔄 [BTC Price Manager] 重启定时器以应用新的刷新间隔")
            #endif

            stopPriceUpdates()
            startPriceUpdates()
        }
    }

    /// 获取当前刷新间隔
    /// - Returns: 当前的RefreshInterval枚举值
    func getCurrentRefreshInterval() -> RefreshInterval {
        return RefreshInterval.allCases.first { $0.rawValue == currentRefreshInterval } ?? .thirtySeconds
    }
}
