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
    /// 当前选中的币种
    @Published var selectedSymbol: CryptoSymbol = .btc

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "BTCRefreshInterval"
    private let selectedSymbolKey = "SelectedCryptoSymbol"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Configuration Methods

    /// 从UserDefaults加载保存的配置
    /// 如果没有保存的配置，使用默认值（30秒）
    func loadSettings() {
        let savedIntervalValue = defaults.double(forKey: refreshIntervalKey)
        if let savedInterval = RefreshInterval.allCases.first(where: { $0.rawValue == savedIntervalValue }) {
            refreshInterval = savedInterval
        } else {
            refreshInterval = .thirtySeconds
            saveRefreshInterval(.thirtySeconds)
        }

        if let savedSymbolRaw = defaults.string(forKey: selectedSymbolKey),
           let savedSymbol = CryptoSymbol(rawValue: savedSymbolRaw) {
            selectedSymbol = savedSymbol
        } else {
            selectedSymbol = .btc
            saveSelectedSymbol(.btc)
        }
    }

    /// 保存用户选择的刷新间隔
    /// - Parameter interval: 要保存的刷新间隔
    func saveRefreshInterval(_ interval: RefreshInterval) {
        refreshInterval = interval
        defaults.set(interval.rawValue, forKey: refreshIntervalKey)
    }

    /// 保存用户选择的币种
    /// - Parameter symbol: 要保存的币种
    func saveSelectedSymbol(_ symbol: CryptoSymbol) {
        selectedSymbol = symbol
        defaults.set(symbol.rawValue, forKey: selectedSymbolKey)
    }
}
