//
//  PriceManager.swift
//  test1
//
//  Created by Mark on 2025/10/28.
//

import Foundation
import Combine

// 价格管理器，负责定时刷新币种价格
@MainActor
class PriceManager: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var isFetching: Bool = false
    @Published var lastError: PriceError?
    @Published var selectedSymbol: CryptoSymbol

    private let priceService = PriceService()
    private var timer: Timer?
    private var currentRefreshInterval: TimeInterval = RefreshInterval.thirtySeconds.rawValue // 当前刷新间隔

    init(initialSymbol: CryptoSymbol = .btc) {
        selectedSymbol = initialSymbol
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
    print("⏰ [Price Manager] 启动定时器，刷新间隔: \(Int(currentRefreshInterval))秒 | 币种: \(selectedSymbol.displayName)")
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
    print("✅ [Price Manager] 定时器启动成功")
        #endif
    }

    // 停止价格更新
    @MainActor
    func stopPriceUpdates() {
        #if DEBUG
    print("⏹️ [Price Manager] 停止定时器")
        #endif

        timer?.invalidate()
        timer = nil

        #if DEBUG
    print("✅ [Price Manager] 定时器已停止")
        #endif
    }

    // 手动刷新价格
    func refreshPrice() async {
        #if DEBUG
    print("🔄 [Price Manager] 用户手动刷新价格 | 币种: \(selectedSymbol.displayName)")
        #endif

        await fetchPrice()
    }

    // 获取价格的核心方法（带重试机制）
    private func fetchPrice() async {
        isFetching = true
        lastError = nil
        let activeSymbol = selectedSymbol
        var didUpdatePrice = false

        #if DEBUG
        print("🔄 [Price Manager] 开始获取价格 | 币种: \(activeSymbol.displayName)")
        #endif

        defer {
            isFetching = false

            #if DEBUG
            if let error = lastError {
                print("⚠️ [Price Manager] 价格获取流程结束，最终失败: \(error.localizedDescription) | 币种: \(activeSymbol.displayName)")
            } else if didUpdatePrice {
                print("✅ [Price Manager] 价格获取流程结束，成功")
            } else {
                print("ℹ️ [Price Manager] 价格获取流程结束，结果已丢弃 | 币种已更新")
            }
            #endif
        }

        // 重试最多3次
        let maxRetries = 3

        for attempt in 1...maxRetries {
            #if DEBUG
            print("📡 [Price Manager] 尝试获取价格 (第\(attempt)次) | 币种: \(activeSymbol.displayName)")
            #endif

            do {
                let price = try await priceService.fetchPrice(for: activeSymbol)

                guard activeSymbol == selectedSymbol else {
                    #if DEBUG
                    print("ℹ️ [Price Manager] 币种已切换至 \(selectedSymbol.displayName)，丢弃旧结果")
                    #endif
                    return
                }

                currentPrice = price
                didUpdatePrice = true

                #if DEBUG
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                let currentTime = formatter.string(from: Date())
                print("✅ [Price Manager] 价格更新成功: \(activeSymbol.displayName)/USDT $\(String(format: "%.4f", price)) | 时间: \(currentTime)")
                #endif

                break // 成功获取价格，退出重试循环
            } catch let error as PriceError {
                #if DEBUG
                print("❌ [Price Manager] 价格获取失败 (第\(attempt)次): \(error.localizedDescription) | 币种: \(activeSymbol.displayName)")
                #endif

                if attempt == maxRetries {
                    lastError = error
                } else {
                    // 等待一段时间再重试
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000)) // 递增延迟
                }
            } catch {
                #if DEBUG
                print("❌ [Price Manager] 网络错误 (第\(attempt)次): \(error.localizedDescription) | 币种: \(activeSymbol.displayName)")
                #endif

                if attempt == maxRetries {
                    lastError = .networkError(error)
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }
    }

    // 格式化价格显示
    var formattedPrice: String {
        if isFetching {
            return "\(selectedSymbol.displayName): 更新中..."
        }

        if lastError != nil {
            return "\(selectedSymbol.displayName): 错误"
        }

        if currentPrice == 0.0 {
            return "\(selectedSymbol.displayName): 加载中..."
        }

        return "\(selectedSymbol.displayName): $\(formatPriceWithCommas(currentPrice))"
    }

    // 获取详细错误信息
    var errorMessage: String? {
        return lastError?.localizedDescription
    }

    // 格式化价格为千分位分隔形式
    private func formatPriceWithCommas(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.4f", price)
    }

    /// 更新当前币种
    /// - Parameter symbol: 用户选中的新币种
    func updateSymbol(_ symbol: CryptoSymbol) {
        guard symbol != selectedSymbol else { return }

        #if DEBUG
        print("🔁 [Price Manager] 更新币种: \(selectedSymbol.displayName) → \(symbol.displayName)")
        #endif

        selectedSymbol = symbol
        currentPrice = 0.0
        lastError = nil

        Task { [weak self] in
            await self?.fetchPrice()
        }
    }

    // MARK: - Refresh Interval Configuration

    /// 更新刷新间隔
    /// - Parameter interval: 新的刷新间隔
    func updateRefreshInterval(_ interval: RefreshInterval) {
        let oldInterval = RefreshInterval.allCases.first { $0.rawValue == currentRefreshInterval }?.displayText ?? "未知"

        #if DEBUG
        print("⏱️ [Price Manager] 刷新间隔变更: \(oldInterval) → \(interval.displayText)")
        #endif

        currentRefreshInterval = interval.rawValue

        // 如果定时器正在运行，重启它以应用新的间隔
        if timer != nil {
            #if DEBUG
            print("🔄 [Price Manager] 重启定时器以应用新的刷新间隔")
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
    
    /// 并发获取所有支持币种的价格（用于菜单一次性显示全部币种）
    nonisolated func fetchAllPrices() async -> [CryptoSymbol: (price: Double?, errorMessage: String?)] {
        var results = [CryptoSymbol: (Double?, String?)]()

        await withTaskGroup(of: (CryptoSymbol, Double?, String?).self) { group in
            for symbol in CryptoSymbol.allCases {
                group.addTask { [weak self] in
                    guard let self = self else { return (symbol, nil, "PriceManager已释放") }
                    do {
                        let price = try await self.priceService.fetchPrice(for: symbol)
                        return (symbol, price, nil)
                    } catch let error as PriceError {
                        return (symbol, nil, error.localizedDescription)
                    } catch {
                        return (symbol, nil, "网络错误：\(error.localizedDescription)")
                    }
                }
            }

            for await (symbol, price, errorMsg) in group {
                results[symbol] = (price, errorMsg)
            }
        }

        return results
    }
}
