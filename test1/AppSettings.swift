//
//  AppSettings.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/29.
//

import Foundation
import Combine
import ServiceManagement

/// 应用配置管理类
/// 负责管理用户的刷新间隔设置和其他应用配置
@MainActor
class AppSettings: ObservableObject {

    // MARK: - Published Properties

    /// 当前选中的刷新间隔
    @Published var refreshInterval: RefreshInterval = .thirtySeconds
    /// 当前选中的币种
    @Published var selectedSymbol: CryptoSymbol = .btc
    /// 是否开机自启动
    @Published var launchAtLogin: Bool = false
    
    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "BTCRefreshInterval"
    private let selectedSymbolKey = "SelectedCryptoSymbol"
    private let launchAtLoginKey = "LaunchAtLogin"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Configuration Methods

    /// 从UserDefaults加载保存的配置
    /// 如果没有保存的配置，使用默认值（30秒 + BTC）
    func loadSettings() {
        #if DEBUG
        print("🔧 [AppSettings] 开始加载配置...")
        #endif

        let hasRefreshIntervalKey = defaults.object(forKey: refreshIntervalKey) != nil
        let savedIntervalValue = defaults.double(forKey: refreshIntervalKey)
        #if DEBUG
        print("🔧 [AppSettings] 刷新间隔键是否存在: \(hasRefreshIntervalKey)")
        print("🔧 [AppSettings] 从 UserDefaults 读取刷新间隔: \(savedIntervalValue)")
        #endif

        if hasRefreshIntervalKey,
           let savedInterval = RefreshInterval.allCases.first(where: { $0.rawValue == savedIntervalValue }) {
            refreshInterval = savedInterval
            #if DEBUG
            print("🔧 [AppSettings] ✅ 使用保存的刷新间隔: \(savedInterval.displayText)")
            #endif
        } else {
            refreshInterval = .thirtySeconds
            #if DEBUG
            print("🔧 [AppSettings] ❌ 未找到有效刷新间隔，使用默认值: \(refreshInterval.displayText)")
            #endif
            saveRefreshInterval(.thirtySeconds)
        }

        let hasSymbolKey = defaults.object(forKey: selectedSymbolKey) != nil
        let savedSymbolRaw = defaults.string(forKey: selectedSymbolKey)

        #if DEBUG
        print("🔧 [AppSettings] 币种键是否存在: \(hasSymbolKey)")
        if let symbol = savedSymbolRaw {
            print("🔧 [AppSettings] 从 UserDefaults 读取币种: \(symbol)")
        } else {
            print("🔧 [AppSettings] 从 UserDefaults 读取币种: nil")
        }
        #endif

        // 改进的币种配置验证逻辑
        if hasSymbolKey,
           let savedSymbolRaw = savedSymbolRaw,
           !savedSymbolRaw.isEmpty, // 确保不是空字符串
           let savedSymbol = CryptoSymbol(rawValue: savedSymbolRaw) {
            // 额外验证：确保读取的币种在支持列表中
            if CryptoSymbol.allCases.contains(savedSymbol) {
                selectedSymbol = savedSymbol
                #if DEBUG
                print("🔧 [AppSettings] ✅ 使用保存的币种: \(savedSymbol.displayName)")
                #endif
            } else {
                // 如果保存的币种不在支持列表中，重置为默认值
                selectedSymbol = .btc
                #if DEBUG
                print("🔧 [AppSettings] ⚠️ 保存的币种不在支持列表中，重置为默认值: \(selectedSymbol.displayName)")
                #endif
                saveSelectedSymbol(.btc)
            }
        } else {
            selectedSymbol = .btc
            #if DEBUG
            print("🔧 [AppSettings] ❌ 未找到有效币种配置，使用默认值: \(selectedSymbol.displayName)")
            #endif
            saveSelectedSymbol(.btc)
        }

        // 加载开机自启动设置
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)

        // 检查实际的自启动状态并同步
        checkAndSyncLaunchAtLoginStatus()

        #if DEBUG
        print("🔧 [AppSettings] 配置加载完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(selectedSymbol.displayName), 开机自启动: \(launchAtLogin)")
        #endif
    }

    /// 重置所有设置为默认值
    /// 用于调试或故障排除
    func resetToDefaults() {
        #if DEBUG
        print("🔧 [AppSettings] 重置所有设置为默认值")
        #endif

        refreshInterval = .thirtySeconds
        selectedSymbol = .btc

        // 保存默认值
        saveRefreshInterval(.thirtySeconds)
        saveSelectedSymbol(.btc)

        #if DEBUG
        print("🔧 [AppSettings] 重置完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(selectedSymbol.displayName)")
        #endif

        // 重置开机自启动设置
        launchAtLogin = false
        defaults.set(false, forKey: launchAtLoginKey)

        // 禁用开机自启动
        toggleLoginItem(enabled: false)
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
        #if DEBUG
        print("🔧 [AppSettings] 保存币种配置: \(symbol.displayName) (\(symbol.rawValue))")
        #endif
        defaults.set(symbol.rawValue, forKey: selectedSymbolKey)
    }

    // MARK: - 开机自启动相关方法

    /// 切换开机自启动状态
    /// - Parameter enabled: 是否启用开机自启动
    func toggleLoginItem(enabled: Bool) {
        // 检查 macOS 版本是否支持 SMAppService (macOS 13+)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    #if DEBUG
                    print("🔧 [AppSettings] ✅ 开机自启动已启用")
                    #endif
                } else {
                    try SMAppService.mainApp.unregister()
                    #if DEBUG
                    print("🔧 [AppSettings] ❌ 开机自启动已禁用")
                    #endif
                }

                // 保存到 UserDefaults
                launchAtLogin = enabled
                defaults.set(enabled, forKey: launchAtLoginKey)

            } catch {
                #if DEBUG
                print("🔧 [AppSettings] ⚠️ 设置开机自启动失败: \(error.localizedDescription)")
                #endif

                // 如果操作失败，恢复到之前的状态
                let actualStatus = SMAppService.mainApp.status
                launchAtLogin = (actualStatus == .enabled)
                defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            }
        } else {
            // 对于低于 macOS 13 的版本，显示警告信息
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 当前 macOS 版本不支持 SMAppService，无法设置开机自启动")
            #endif
        }
    }

    /// 检查并同步开机自启动状态
    /// 确保应用内部状态与系统实际状态保持一致
    private func checkAndSyncLaunchAtLoginStatus() {
        guard #available(macOS 13.0, *) else {
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 当前 macOS 版本不支持 SMAppService")
            #endif
            return
        }

        let actualStatus = SMAppService.mainApp.status
        let isEnabled = (actualStatus == .enabled)

        // 如果系统状态与应用内部状态不一致，则同步
        if isEnabled != launchAtLogin {
            launchAtLogin = isEnabled
            defaults.set(isEnabled, forKey: launchAtLoginKey)

            #if DEBUG
            print("🔧 [AppSettings] 🔄 已同步开机自启动状态: \(isEnabled)")
            #endif
        }
    }

    /// 获取当前开机自启动状态
    /// - Returns: 是否已启用开机自启动
    func isLaunchAtLoginEnabled() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        let actualStatus = SMAppService.mainApp.status
        return actualStatus == .enabled
    }
}
