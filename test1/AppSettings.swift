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

    // MARK: - 代理设置相关属性

    /// 是否启用代理
    @Published var proxyEnabled: Bool = false
    /// 代理服务器地址
    @Published var proxyHost: String = ""
    /// 代理服务器端口
    @Published var proxyPort: Int = 8080
    /// 代理认证用户名
    @Published var proxyUsername: String = ""
    /// 代理认证密码
    @Published var proxyPassword: String = ""

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "BTCRefreshInterval"
    private let selectedSymbolKey = "SelectedCryptoSymbol"
    private let launchAtLoginKey = "LaunchAtLogin"

    // MARK: - 代理配置键值

    private let proxyEnabledKey = "ProxyEnabled"
    private let proxyHostKey = "ProxyHost"
    private let proxyPortKey = "ProxyPort"
    private let proxyUsernameKey = "ProxyUsername"
    private let proxyPasswordKey = "ProxyPassword"

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

        // 加载代理设置
        proxyEnabled = defaults.bool(forKey: proxyEnabledKey)
        proxyHost = defaults.string(forKey: proxyHostKey) ?? ""
        proxyPort = defaults.integer(forKey: proxyPortKey)
        if proxyPort == 0 { proxyPort = 8080 } // 默认端口
        proxyUsername = defaults.string(forKey: proxyUsernameKey) ?? ""
        proxyPassword = defaults.string(forKey: proxyPasswordKey) ?? ""

        // 检查实际的自启动状态并同步
        checkAndSyncLaunchAtLoginStatus()

        #if DEBUG
        let proxyInfo = proxyEnabled ? "\(proxyHost):\(proxyPort)" : "未启用"
        let authInfo = proxyEnabled && !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
        print("🔧 [AppSettings] 配置加载完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(selectedSymbol.displayName), 开机自启动: \(launchAtLogin), 代理: \(proxyInfo)\(authInfo)")
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

        // 重置代理设置
        proxyEnabled = false
        proxyHost = ""
        proxyPort = 8080
        proxyUsername = ""
        proxyPassword = ""
        defaults.set(false, forKey: proxyEnabledKey)
        defaults.set("", forKey: proxyHostKey)
        defaults.set(8080, forKey: proxyPortKey)
        defaults.set("", forKey: proxyUsernameKey)
        defaults.set("", forKey: proxyPasswordKey)

        #if DEBUG
        print("🔧 [AppSettings] 重置完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(selectedSymbol.displayName), 代理: 已重置")
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

    // MARK: - 代理设置相关方法

    /// 保存代理设置
    /// - Parameters:
    ///   - enabled: 是否启用代理
    ///   - host: 代理服务器地址
    ///   - port: 代理服务器端口
    ///   - username: 代理认证用户名
    ///   - password: 代理认证密码
    func saveProxySettings(enabled: Bool, host: String, port: Int, username: String = "", password: String = "") {
        proxyEnabled = enabled
        proxyHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        proxyPort = port
        proxyUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        proxyPassword = password

        // 保存到 UserDefaults
        defaults.set(enabled, forKey: proxyEnabledKey)
        defaults.set(proxyHost, forKey: proxyHostKey)
        defaults.set(port, forKey: proxyPortKey)
        defaults.set(proxyUsername, forKey: proxyUsernameKey)
        defaults.set(proxyPassword, forKey: proxyPasswordKey)

        #if DEBUG
        if enabled {
            let authInfo = !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
            print("🔧 [AppSettings] 保存代理设置: \(proxyHost):\(proxyPort)\(authInfo)")
        } else {
            print("🔧 [AppSettings] 保存代理设置: 已禁用")
        }
        #endif
    }

    /// 验证代理设置是否有效
    /// - Returns: 验证结果和错误信息
    func validateProxySettings() -> (isValid: Bool, errorMessage: String?) {
        guard proxyEnabled else {
            return (true, nil) // 代理未启用，无需验证
        }

        let trimmedHost = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证服务器地址
        if trimmedHost.isEmpty {
            return (false, "代理服务器地址不能为空")
        }

        // 简单的IP地址或域名格式验证
        if !isValidHost(trimmedHost) {
            return (false, "代理服务器地址格式不正确")
        }

        // 验证端口范围
        if proxyPort < 1 || proxyPort > 65535 {
            return (false, "代理端口必须在 1-65535 范围内")
        }

        return (true, nil)
    }

    /// 验证主机地址格式
    /// - Parameter host: 主机地址
    /// - Returns: 是否为有效格式
    private func isValidHost(_ host: String) -> Bool {
        // 简单的IP地址验证
        if host.matches(pattern: #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#) {
            return true
        }

        // 简单的域名验证
        if host.matches(pattern: #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#) {
            return true
        }

        return false
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

// MARK: - String Extension for Regex Matching

extension String {
    /// 检查字符串是否匹配给定的正则表达式模式
    /// - Parameter pattern: 正则表达式模式
    /// - Returns: 是否匹配
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
