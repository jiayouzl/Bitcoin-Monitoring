//
//  CryptoSymbol.swift
//  Bitcoin Monitoring
//
//  Created by GitHub Copilot on 2025/10/29.
//

import Foundation

/// 支持的主流虚拟货币枚举
/// 提供API符号、展示名称和图标信息
enum CryptoSymbol: String, CaseIterable, Codable {
    case btc = "BTCUSDT"
    case eth = "ETHUSDT"
    case doge = "DOGEUSDT"

    /// 用于展示的币种简称
    var displayName: String {
        switch self {
        case .btc:
            return "BTC"
        case .eth:
            return "ETH"
        case .doge:
            return "DOGE"
        }
    }

    /// 币安API使用的交易对符号
    var apiSymbol: String {
        return rawValue
    }

    /// 菜单中展示的交易对名称
    var pairDisplayName: String {
        return "\(displayName)/USDT"
    }

    /// 对应的SF Symbols图标名称
    var systemImageName: String {
        switch self {
        case .btc:
            return "bitcoinsign.circle.fill"
        case .eth:
            return "hexagon.fill"
        case .doge:
            return "pawprint.circle.fill"
        }
    }

    /// 菜单标题（带勾选标记）
    /// - Parameter isCurrent: 是否为当前选中币种
    /// - Returns: 菜单展示文本
    func menuTitle(isCurrent: Bool) -> String {
        return isCurrent ? "✓ \(pairDisplayName)" : "  \(pairDisplayName)"
    }
}
