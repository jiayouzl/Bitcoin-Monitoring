//
//  RefreshInterval.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/29.
//

import Foundation

/// 刷新间隔选项枚举
/// 定义用户可以选择的价格刷新间隔
enum RefreshInterval: Double, CaseIterable, Codable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case sixtySeconds = 60

    /// 获取刷新间隔的显示文本
    /// - Returns: 用于在菜单中显示的中文文本
    var displayText: String {
        switch self {
        case .fiveSeconds:
            return "5秒"
        case .tenSeconds:
            return "10秒"
        case .thirtySeconds:
            return "30秒"
        case .sixtySeconds:
            return "60秒"
        }
    }

    /// 获取包含当前标记的显示文本
    /// - Parameter isCurrent: 是否为当前选中的间隔
    /// - Returns: 带有当前标记的显示文本
    func displayTextWithMark(isCurrent: Bool) -> String {
        return isCurrent ? "✓ \(displayText)" : "  \(displayText)"
    }
}
