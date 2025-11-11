//
//  BinanceURLGenerator.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/11/11.
//

import Foundation
import AppKit

/**
 * 币安URL生成器
 * 负责生成币安现货和合约交易页面的URL
 */
struct BinanceURLGenerator {

    /// 生成币安现货交易页面URL
    /// - Parameter symbol: 币种符号（如 BTC、ETH）
    /// - Returns: 现货交易页面URL字符串
    static func generateSpotTradingURL(for symbol: String) -> String {
        return "https://www.binance.com/zh-CN/trade/\(symbol)_USDT?type=spot"
    }

    /// 生成币安合约交易页面URL
    /// - Parameter symbol: 币种符号（如 BTC、ETH）
    /// - Returns: 合约交易页面URL字符串
    static func generateFuturesTradingURL(for symbol: String) -> String {
        return "https://www.binance.com/zh-CN/futures/\(symbol)USDT"
    }

    /// 打开币安现货交易页面
    /// - Parameter symbol: 币种符号
    /// - Returns: 是否成功打开页面
    static func openSpotTradingPage(for symbol: String) -> Bool {
        let url = generateSpotTradingURL(for: symbol)
        return openURL(url)
    }

    /// 打开币安合约交易页面
    /// - Parameter symbol: 币种符号
    /// - Returns: 是否成功打开页面
    static func openFuturesTradingPage(for symbol: String) -> Bool {
        let url = generateFuturesTradingURL(for: symbol)
        return openURL(url)
    }

    /// 使用系统默认浏览器打开URL
    /// - Parameter urlString: URL字符串
    /// - Returns: 是否成功打开
    private static func openURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ [BinanceURLGenerator] 无效的URL: \(urlString)")
            #endif
            return false
        }

        // 使用NSWorkspace打开URL（macOS专用）
        if #available(macOS 10.15, *) {
            NSWorkspace.shared.open(url)
        } else {
            // 对于较老的macOS版本，使用NSWorkspace的旧API
            let workspace = NSWorkspace.shared
            workspace.open(url)
        }

        #if DEBUG
        print("✅ [BinanceURLGenerator] 已打开URL: \(urlString)")
        #endif
        return true
    }
}