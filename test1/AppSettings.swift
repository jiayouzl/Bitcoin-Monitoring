//
//  AppSettings.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/29.
//

import Foundation
import Combine

/// 应用配置管理类
/// 负责管理用户的刷新间隔设置和其他应用配置
@MainActor
class AppSettings: ObservableObject {

    // MARK: - Published Properties

    /// 当前选中的刷新间隔
    @Published var refreshInterval: RefreshInterval = .thirtySeconds

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "BTCRefreshInterval"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Configuration Methods

    /// 从UserDefaults加载保存的配置
    /// 如果没有保存的配置，使用默认值（30秒）
    func loadSettings() {
        let savedValue = defaults.double(forKey: refreshIntervalKey)

        // 查找匹配的刷新间隔，如果没有匹配的则使用默认值
        if let savedInterval = RefreshInterval.allCases.first(where: { $0.rawValue == savedValue }) {
            refreshInterval = savedInterval
        } else {
            refreshInterval = .thirtySeconds
            // 保存默认值，确保下次启动时有正确的配置
            saveRefreshInterval(.thirtySeconds)
        }
    }

    /// 保存用户选择的刷新间隔
    /// - Parameter interval: 要保存的刷新间隔
    func saveRefreshInterval(_ interval: RefreshInterval) {
        refreshInterval = interval
        defaults.set(interval.rawValue, forKey: refreshIntervalKey)
    }
}
