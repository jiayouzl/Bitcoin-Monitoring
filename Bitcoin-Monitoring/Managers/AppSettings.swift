//
//  AppSettings.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/29.
//

import Foundation
import Combine
import ServiceManagement

/// Option+点击操作类型枚举
/// 定义用户按住Option键点击币种时可以执行的操作
enum OptionClickAction: String, CaseIterable, Codable {
    case copyPrice = "copyPrice"
    case openSpotTrading = "openSpotTrading"
    case openFuturesTrading = "openFuturesTrading"

    /// 获取操作的显示名称
    var displayName: String {
        switch self {
        case .copyPrice:
            return "复制价格"
        case .openSpotTrading:
            return "Binance现货交易"
        case .openFuturesTrading:
            return "Binance合约交易"
        }
    }
}

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

    // MARK: - 自定义币种相关属性

    /// 自定义币种列表（最多5个）
    @Published var customCryptoSymbols: [CustomCryptoSymbol] = []
    /// 当前选中的自定义币种索引（如果使用自定义币种）
    @Published var selectedCustomSymbolIndex: Int?
    /// 是否使用自定义币种
    @Published var useCustomSymbol: Bool = false

    // MARK: - 代理设置相关属性

    /// 是否启用代理
    @Published var proxyEnabled: Bool = false
    /// 代理服务器地址
    @Published var proxyHost: String = ""
    /// 代理服务器端口
    @Published var proxyPort: Int = 3128
    /// 代理认证用户名
    @Published var proxyUsername: String = ""
    /// 代理认证密码
    @Published var proxyPassword: String = ""

    // MARK: - Option+点击功能设置

    /// Option+左键点击的操作类型
    @Published var optionClickAction: OptionClickAction = .copyPrice

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let refreshIntervalKey = "BTCRefreshInterval"
    private let selectedSymbolKey = "SelectedCryptoSymbol"
    private let launchAtLoginKey = "LaunchAtLogin"

    // MARK: - 自定义币种配置键值

    private let customSymbolsKey = "CustomCryptoSymbols"
    private let selectedCustomSymbolIndexKey = "SelectedCustomSymbolIndex"
    private let useCustomSymbolKey = "UseCustomSymbol"

    // MARK: - 代理配置键值

    private let proxyEnabledKey = "ProxyEnabled"
    private let proxyHostKey = "ProxyHost"
    private let proxyPortKey = "ProxyPort"
    private let proxyUsernameKey = "ProxyUsername"
    private let proxyPasswordKey = "ProxyPassword"

    // MARK: - Option+点击功能配置键值

    private let optionClickActionKey = "OptionClickAction"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    /// 创建仅供代理测试使用的内存配置，不加载或写入正式设置。
    init(proxyTestHost: String, port: Int, username: String, password: String) {
        proxyEnabled = true
        proxyHost = proxyTestHost.trimmingCharacters(in: .whitespacesAndNewlines)
        proxyPort = port
        proxyUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        proxyPassword = password
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

        // 加载自定义币种设置
        if let customSymbolsData = defaults.data(forKey: customSymbolsKey),
           let customSymbols = try? JSONDecoder().decode([CustomCryptoSymbol].self, from: customSymbolsData) {
            customCryptoSymbols = customSymbols
            // 加载选中的自定义币种索引
            let savedIndex = defaults.integer(forKey: selectedCustomSymbolIndexKey)
            if savedIndex >= 0 && savedIndex < customSymbols.count {
                selectedCustomSymbolIndex = savedIndex
            }
            // 根据保存的状态决定是否使用自定义币种
            useCustomSymbol = defaults.bool(forKey: useCustomSymbolKey)
            #if DEBUG
            print("🔧 [AppSettings] ✅ 已加载 \(customSymbols.count) 个自定义币种，使用状态: \(useCustomSymbol)")
            if let index = selectedCustomSymbolIndex {
                print("🔧 [AppSettings] 当前选中自定义币种: \(customSymbols[index].displayName)")
            }
            #endif
        } else {
            customCryptoSymbols = []
            selectedCustomSymbolIndex = nil
            useCustomSymbol = false
            #if DEBUG
            print("🔧 [AppSettings] ℹ️ 未找到自定义币种数据")
            #endif
        }

        // 加载代理设置
        proxyEnabled = defaults.bool(forKey: proxyEnabledKey)
        proxyHost = defaults.string(forKey: proxyHostKey) ?? ""
        proxyPort = defaults.integer(forKey: proxyPortKey)
        if proxyPort == 0 { proxyPort = 3128 } // 默认端口
        proxyUsername = defaults.string(forKey: proxyUsernameKey) ?? ""
        proxyPassword = defaults.string(forKey: proxyPasswordKey) ?? ""

        // 加载Option+点击功能设置
        if let optionClickActionRaw = defaults.string(forKey: optionClickActionKey),
           let savedAction = OptionClickAction(rawValue: optionClickActionRaw) {
            optionClickAction = savedAction
            #if DEBUG
            print("🔧 [AppSettings] ✅ 已加载Option+点击功能: \(savedAction.displayName)")
            #endif
        } else {
            optionClickAction = .copyPrice
            #if DEBUG
            print("🔧 [AppSettings] ❌ 未找到有效Option+点击功能配置，使用默认值: \(optionClickAction.displayName)")
            #endif
        }

        // 检查实际的自启动状态并同步
        checkAndSyncLaunchAtLoginStatus()

        #if DEBUG
        let proxyInfo = proxyEnabled ? "\(proxyHost):\(proxyPort)" : "未启用"
        let authInfo = proxyEnabled && !proxyUsername.isEmpty ? " (认证: \(proxyUsername))" : ""
        let customInfo = useCustomSymbol && !customCryptoSymbols.isEmpty ? " (自定义: \(customCryptoSymbols.count)个)" : ""
        print("🔧 [AppSettings] 配置加载完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(getCurrentActiveDisplayName())\(customInfo), 开机自启动: \(launchAtLogin), 代理: \(proxyInfo)\(authInfo), Option+点击: \(optionClickAction.displayName)")
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

        // 重置自定义币种设置
        useCustomSymbol = false
        customCryptoSymbols = []
        selectedCustomSymbolIndex = nil
        defaults.set(false, forKey: useCustomSymbolKey)
        defaults.removeObject(forKey: customSymbolsKey)
        defaults.removeObject(forKey: selectedCustomSymbolIndexKey)

        // 重置代理设置
        proxyEnabled = false
        proxyHost = ""
        proxyPort = 3128
        proxyUsername = ""
        proxyPassword = ""
        defaults.set(false, forKey: proxyEnabledKey)
        defaults.set("", forKey: proxyHostKey)
        defaults.set(3128, forKey: proxyPortKey)
        defaults.set("", forKey: proxyUsernameKey)
        defaults.set("", forKey: proxyPasswordKey)

        // 重置Option+点击功能设置
        optionClickAction = .copyPrice
        defaults.set(optionClickAction.rawValue, forKey: optionClickActionKey)

        #if DEBUG
        print("🔧 [AppSettings] 重置完成 - 刷新间隔: \(refreshInterval.displayText), 币种: \(selectedSymbol.displayName), 自定义币种: 已清除, 代理: 已重置, Option+点击: \(optionClickAction.displayName)")
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

        // 如果当前正在使用自定义币种，只是切换使用状态，不删除数据
        if useCustomSymbol {
            useCustomSymbol = false
            selectedCustomSymbolIndex = nil
            defaults.set(false, forKey: useCustomSymbolKey)
            defaults.removeObject(forKey: selectedCustomSymbolIndexKey)

            #if DEBUG
            if !customCryptoSymbols.isEmpty {
                print("🔧 [AppSettings] ✅ 已切换到默认币种: \(symbol.displayName)，\(customCryptoSymbols.count) 个自定义币种保留")
            }
            #endif
        }

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

    // MARK: - Option+点击功能相关方法

    /// 保存Option+点击功能设置
    /// - Parameter action: 要保存的操作类型
    func saveOptionClickAction(_ action: OptionClickAction) {
        optionClickAction = action
        defaults.set(action.rawValue, forKey: optionClickActionKey)

        #if DEBUG
        print("🔧 [AppSettings] 保存Option+点击功能设置: \(action.displayName)")
        #endif
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

    // MARK: - 自定义币种相关方法

    /// 添加自定义币种
    /// - Parameter customSymbol: 要添加的自定义币种
    /// - Returns: 是否添加成功
    @discardableResult
    func addCustomCryptoSymbol(_ customSymbol: CustomCryptoSymbol) -> Bool {
        // 检查是否已达到最大数量限制
        guard customCryptoSymbols.count < 5 else {
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 已达到最大自定义币种数量限制 (5个)")
            #endif
            return false
        }

        // 检查是否已存在相同的币种
        guard !customCryptoSymbols.contains(customSymbol) else {
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 自定义币种已存在: \(customSymbol.displayName)")
            #endif
            return false
        }

        customCryptoSymbols.append(customSymbol)

        // 如果这是第一个自定义币种，自动选中并启用自定义币种模式
        if customCryptoSymbols.count == 1 {
            selectedCustomSymbolIndex = 0
            useCustomSymbol = true
            defaults.set(true, forKey: useCustomSymbolKey)
        }

        // 保存到 UserDefaults
        saveCustomCryptoSymbols()

        #if DEBUG
        print("🔧 [AppSettings] ✅ 已添加自定义币种: \(customSymbol.displayName)，当前总数: \(customCryptoSymbols.count)")
        #endif
        return true
    }

    /// 移除指定索引的自定义币种
    /// - Parameter index: 要移除的币种索引
    func removeCustomCryptoSymbol(at index: Int) {
        guard index >= 0 && index < customCryptoSymbols.count else {
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 无效的自定义币种索引: \(index)")
            #endif
            return
        }

        let removedSymbol = customCryptoSymbols[index]
        customCryptoSymbols.remove(at: index)

        // 如果移除的是当前选中的币种，需要调整选中状态
        if selectedCustomSymbolIndex == index {
            // 如果还有其他自定义币种，选中第一个；否则切换到系统默认币种
            if !customCryptoSymbols.isEmpty {
                selectedCustomSymbolIndex = 0
            } else {
                // 没有自定义币种了，切换到系统默认币种
                selectedCustomSymbolIndex = nil
                useCustomSymbol = false
                defaults.set(false, forKey: useCustomSymbolKey)
            }
        } else if let selectedIndex = selectedCustomSymbolIndex, selectedIndex > index {
            // 如果选中的币种在移除的币种之后，需要调整索引
            selectedCustomSymbolIndex = selectedIndex - 1
        }

        // 保存到 UserDefaults
        if let selectedIndex = selectedCustomSymbolIndex {
            defaults.set(selectedIndex, forKey: selectedCustomSymbolIndexKey)
        } else {
            defaults.removeObject(forKey: selectedCustomSymbolIndexKey)
        }
        saveCustomCryptoSymbols()

        #if DEBUG
        print("🔧 [AppSettings] ✅ 已移除自定义币种: \(removedSymbol.displayName)，剩余: \(customCryptoSymbols.count)")
        #endif
    }

    /// 选择指定的自定义币种
    /// - Parameter index: 要选中的币种索引
    func selectCustomCryptoSymbol(at index: Int) {
        guard index >= 0 && index < customCryptoSymbols.count else {
            #if DEBUG
            print("🔧 [AppSettings] ⚠️ 无效的自定义币种索引: \(index)")
            #endif
            return
        }

        selectedCustomSymbolIndex = index
        useCustomSymbol = true
        defaults.set(index, forKey: selectedCustomSymbolIndexKey)
        defaults.set(true, forKey: useCustomSymbolKey)

        #if DEBUG
        print("🔧 [AppSettings] ✅ 已选中自定义币种: \(customCryptoSymbols[index].displayName)")
        #endif
    }

    /// 获取当前选中的自定义币种
    /// - Returns: 当前选中的自定义币种，如果没有则返回nil
    func getCurrentSelectedCustomSymbol() -> CustomCryptoSymbol? {
        guard let index = selectedCustomSymbolIndex,
              index >= 0 && index < customCryptoSymbols.count else {
            return nil
        }
        return customCryptoSymbols[index]
    }

    /// 保存自定义币种列表到 UserDefaults
    private func saveCustomCryptoSymbols() {
        do {
            let data = try JSONEncoder().encode(customCryptoSymbols)
            defaults.set(data, forKey: customSymbolsKey)
        } catch {
            #if DEBUG
            print("🔧 [AppSettings] ❌ 保存自定义币种列表失败: \(error.localizedDescription)")
            #endif
        }
    }

    /// 获取当前活跃的币种API符号
    /// - Returns: 当前活跃币种的API符号
    func getCurrentActiveApiSymbol() -> String {
        if useCustomSymbol, let customSymbol = getCurrentSelectedCustomSymbol() {
            return customSymbol.apiSymbol
        } else {
            return selectedSymbol.apiSymbol
        }
    }

    /// 获取当前活跃的币种显示名称
    /// - Returns: 当前活跃币种的显示名称
    func getCurrentActiveDisplayName() -> String {
        if useCustomSymbol, let customSymbol = getCurrentSelectedCustomSymbol() {
            return customSymbol.displayName
        } else {
            return selectedSymbol.displayName
        }
    }

    /// 获取当前活跃的币种图标
    /// - Returns: 当前活跃币种的图标名称
    func getCurrentActiveSystemImageName() -> String {
        if useCustomSymbol, let customSymbol = getCurrentSelectedCustomSymbol() {
            return customSymbol.systemImageName
        } else {
            return selectedSymbol.systemImageName
        }
    }

    /// 获取当前活跃的币种交易对显示名称
    /// - Returns: 当前活跃币种的交易对显示名称
    func getCurrentActivePairDisplayName() -> String {
        if useCustomSymbol, let customSymbol = getCurrentSelectedCustomSymbol() {
            return customSymbol.pairDisplayName
        } else {
            return selectedSymbol.pairDisplayName
        }
    }

    /// 判断是否正在使用自定义币种
    /// - Returns: 是否正在使用自定义币种
    func isUsingCustomSymbol() -> Bool {
        return useCustomSymbol && !customCryptoSymbols.isEmpty && selectedCustomSymbolIndex != nil
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
