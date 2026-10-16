//
//  MenuBarManager.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/28.
//

import SwiftUI
import AppKit
import Combine

// macOS菜单栏应用主类
@MainActor
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appSettings: AppSettings
    private let priceManager: PriceManager
    private var cancellables = Set<AnyCancellable>()

    // 关于窗口管理器
    private let aboutWindowManager = AboutWindowManager()

    // 偏好设置窗口管理器
    private var preferencesWindowManager: PreferencesWindowManager!

    override init() {
        // 先创建 AppSettings 实例
        let settings = AppSettings()
        self.appSettings = settings
        self.priceManager = PriceManager(initialSymbol: settings.selectedSymbol, appSettings: settings)

        // 现在初始化偏好设置窗口管理器，使用相同的 appSettings 实例
        self.preferencesWindowManager = PreferencesWindowManager(appSettings: settings)

        super.init()
        setupMenuBar()
        setupConfigurationObservers()
    }

    // 设置配置观察者
    private func setupConfigurationObservers() {
        // 监听刷新间隔配置变化
        appSettings.$refreshInterval
            .sink { [weak self] newInterval in
                self?.priceManager.updateRefreshInterval(newInterval)
            }
            .store(in: &cancellables)

        // 监听默认币种配置变化
        appSettings.$selectedSymbol
            .sink { [weak self] newSymbol in
                guard let self = self else { return }
                if !self.appSettings.isUsingCustomSymbol() {
                    self.priceManager.updateSymbol(newSymbol)
                    self.updateMenuBarTitle(price: self.priceManager.currentPrice)
                }
            }
            .store(in: &cancellables)

        // 监听自定义币种配置变化
        appSettings.$customCryptoSymbols
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.priceManager.updateCryptoSymbolSettings()
                self.updateMenuBarTitle(price: self.priceManager.currentPrice)
            }
            .store(in: &cancellables)

        // 监听是否使用自定义币种的变化
        appSettings.$useCustomSymbol
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.priceManager.updateCryptoSymbolSettings()
                self.updateMenuBarTitle(price: self.priceManager.currentPrice)
            }
            .store(in: &cancellables)

        // 监听代理设置变化
        appSettings.$proxyEnabled
            .sink { [weak self] _ in
                self?.updateProxyConfiguration()
            }
            .store(in: &cancellables)

        // 监听代理主机变化
        appSettings.$proxyHost
            .sink { [weak self] _ in
                self?.updateProxyConfiguration()
            }
            .store(in: &cancellables)

        // 监听代理端口变化
        appSettings.$proxyPort
            .sink { [weak self] _ in
                self?.updateProxyConfiguration()
            }
            .store(in: &cancellables)
    }

    // 设置菜单栏
    private func setupMenuBar() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else {
            print("❌ 无法创建状态栏项目")
            return
        }

        guard let button = statusItem.button else {
            print("❌ 无法获取状态栏按钮")
            return
        }

        // 设置初始图标和标题
        updateMenuBarTitle(price: 0.0)
        button.action = #selector(menuBarClicked)
        button.target = self

        // 监听价格变化
        priceManager.$currentPrice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] price in
                self?.updateMenuBarTitle(price: price)
            }
            .store(in: &cancellables)

        // 监听币种变化以更新UI
        priceManager.$selectedSymbol
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuBarTitle(price: self.priceManager.currentPrice)
            }
            .store(in: &cancellables)
    }

    // 更新菜单栏标题（显示当前选中币种价格）
    private func updateMenuBarTitle(price: Double) {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }

            // 获取当前活跃的币种信息
            let displayName = self.appSettings.getCurrentActiveDisplayName()
            let symbolImage: NSImage?

            if self.appSettings.isUsingCustomSymbol() {
                // 自定义币种：使用自定义图标
                symbolImage = self.customSymbolImage()
            } else {
                // 默认币种：直接从AppSettings获取当前选中的币种，避免依赖可能尚未更新的priceManager
                symbolImage = self.symbolImage(for: self.appSettings.selectedSymbol)
            }
            symbolImage?.size = NSSize(width: 16, height: 16)

            // 设置图标
            button.image = symbolImage

            // 根据状态设置标题
            if price == 0.0 {
                if self.priceManager.isFetching {
                    button.title = " \(displayName) 更新中..."
                } else if self.priceManager.lastError != nil {
                    button.title = " \(displayName) 错误"
                } else {
                    button.title = " \(displayName) 加载中..."
                }
            } else {
                button.title = " \(displayName) $\(self.formatPriceWithCommas(price))"
            }
        }
    }

    // 获取币种对应的图标
    private func symbolImage(for symbol: CryptoSymbol) -> NSImage? {
        if let image = NSImage(systemSymbolName: symbol.systemImageName, accessibilityDescription: symbol.displayName) {
            return image
        }
        return NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "Crypto")
    }

    // 获取自定义币种的图标（基于首字母生成）
    private func customSymbolImage() -> NSImage? {
        if appSettings.isUsingCustomSymbol(),
           let index = appSettings.selectedCustomSymbolIndex,
           index >= 0 && index < appSettings.customCryptoSymbols.count {
            let customSymbol = appSettings.customCryptoSymbols[index]
            return customSymbol.customIcon()
        }
        return NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "自定义币种")
    }

    // 获取指定自定义币种的图标
    private func customSymbolImage(for customSymbol: CustomCryptoSymbol) -> NSImage? {
        return customSymbol.customIcon()
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

    // 更新代理配置
    private func updateProxyConfiguration() {
        #if DEBUG
        print("🔄 [BTCMenuBarApp] 检测到代理设置变化，正在更新网络配置...")
        #endif

        // 更新 PriceService 的网络配置
        priceManager.updateNetworkConfiguration()

        #if DEBUG
        let proxyStatus = appSettings.proxyEnabled ? "已启用 (\(appSettings.proxyHost):\(appSettings.proxyPort))" : "已禁用"
        print("✅ [BTCMenuBarApp] 代理配置更新完成: \(proxyStatus)")
        #endif
    }

    // 菜单栏点击事件
    @objc private func menuBarClicked() {
        guard let button = statusItem?.button else {
            print("❌ 无法获取状态栏按钮")
            return
        }
        showMenu(from: button)
    }

    // 显示菜单
    private func showMenu(from view: NSView) {
        let menu = NSMenu()

        // 添加价格信息项（带币种图标和选中状态）
        // 首先添加所有默认币种
        var symbolMenuItems: [CryptoSymbol: NSMenuItem] = [:]
        let currentApiSymbol = appSettings.getCurrentActiveApiSymbol()

        // 添加默认币种菜单项
        for symbol in CryptoSymbol.allCases {
            let isCurrent = symbol.isCurrentSymbol(currentApiSymbol)
            let placeholderTitle = isCurrent ? "✓ \(symbol.displayName): 加载中..." : "  \(symbol.displayName): 加载中..."
            let item = NSMenuItem(title: placeholderTitle, action: #selector(self.selectOrCopySymbol(_:)), keyEquivalent: "")
            item.target = self // 关键：必须设置target
            if let icon = symbolImage(for: symbol) {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
                // macOS 27 默认可能隐藏菜单图标，显式请求显示币种图标。
                if #available(macOS 27.0, *) {
                    item.preferredImageVisibility = .visible
                }
            }
            item.isEnabled = true // 立即启用菜单项，允许用户交互
            item.representedObject = ["symbol": symbol, "price": 0.0, "isCustom": false]
            menu.addItem(item)
            symbolMenuItems[symbol] = item
        }

        // 添加自定义币种菜单项（如果存在）- 显示在最后
        var customSymbolMenuItems: [NSMenuItem] = []
        for customSymbol in appSettings.customCryptoSymbols {
            let isCurrent = customSymbol.isCurrentSymbol(currentApiSymbol)
            let placeholderTitle = isCurrent ? "✓ \(customSymbol.displayName) (自定义): 加载中..." : "  \(customSymbol.displayName) (自定义): 加载中..."
            let item = NSMenuItem(title: placeholderTitle, action: #selector(self.selectOrCopySymbol(_:)), keyEquivalent: "")
            item.target = self
            if let icon = customSymbolImage(for: customSymbol) {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
                // macOS 27 默认可能隐藏菜单图标，显式请求显示币种图标。
                if #available(macOS 27.0, *) {
                    item.preferredImageVisibility = .visible
                }
            }
            item.isEnabled = true
            item.representedObject = ["customSymbol": customSymbol, "price": 0.0, "isCustom": true]
            menu.addItem(item)
            customSymbolMenuItems.append(item)
        }

        // 异步并发获取所有币种价格并更新对应的菜单项
        Task { @MainActor in
            let results = await self.priceManager.fetchAllPrices()
            let currentSymbolAfter = self.appSettings.getCurrentActiveApiSymbol()

            // 更新默认币种菜单项
            for symbol in CryptoSymbol.allCases {
                guard let (priceOpt, errorOpt) = results[symbol], let menuItem = symbolMenuItems[symbol] else { continue }
                let isCurrent = symbol.isCurrentSymbol(currentSymbolAfter)

                if let price = priceOpt {
                    let title = isCurrent ? "✓ \(symbol.displayName): $\(self.formatPriceWithCommas(price))" : "  \(symbol.displayName): $\(self.formatPriceWithCommas(price))"
                    menuItem.title = title
                    menuItem.isEnabled = true // 启用菜单项，允许用户交互
                    menuItem.target = self // 确保target正确设置
                    menuItem.representedObject = ["symbol": symbol, "price": price, "isCustom": false]
                } else if errorOpt != nil {
                    let title = isCurrent ? "✓ \(symbol.displayName): 错误" : "  \(symbol.displayName): 错误"
                    menuItem.title = title
                    // 已删除悬浮提示，避免网络错误时显示悬浮提示
                    menuItem.isEnabled = false // 有错误时禁用交互
                    menuItem.target = self // 确保target正确设置
                    menuItem.representedObject = ["symbol": symbol, "price": 0.0, "isCustom": false]
                } else {
                    let title = isCurrent ? "✓ \(symbol.displayName): 加载中..." : "  \(symbol.displayName): 加载中..."
                    menuItem.title = title
                    menuItem.target = self // 确保target正确设置
                    menuItem.representedObject = ["symbol": symbol, "price": 0.0, "isCustom": false]
                    // 保持启用状态，允许用户交互
                }
            }

            // 更新自定义币种菜单项
            for (index, customSymbol) in self.appSettings.customCryptoSymbols.enumerated() {
                if index < customSymbolMenuItems.count {
                    let menuItem = customSymbolMenuItems[index]
                    let isCurrent = customSymbol.isCurrentSymbol(currentSymbolAfter)

                    if let price = await self.priceManager.fetchCustomSymbolPrice(forApiSymbol: customSymbol.apiSymbol) {
                        let title = isCurrent ? "✓ \(customSymbol.displayName) (自定义): $\(self.formatPriceWithCommas(price))" : "  \(customSymbol.displayName) (自定义): $\(self.formatPriceWithCommas(price))"
                        menuItem.title = title
                        menuItem.isEnabled = true
                        menuItem.target = self
                        menuItem.representedObject = ["customSymbol": customSymbol, "price": price, "isCustom": true]
                    } else {
                        let title = isCurrent ? "✓ \(customSymbol.displayName) (自定义): 错误" : "  \(customSymbol.displayName) (自定义): 错误"
                        menuItem.title = title
                        menuItem.isEnabled = false
                        menuItem.target = self
                        menuItem.representedObject = ["customSymbol": customSymbol, "price": 0.0, "isCustom": true]
                    }
                }
            }
        }

        // 添加使用提示
//        let hintItem = NSMenuItem(title: "💡 点击切换币种，Option+点击复制价格", action: nil, keyEquivalent: "")
//        hintItem.isEnabled = false
//        menu.addItem(hintItem)
        menu.addItem(NSMenuItem.separator())

        // 如果有错误，显示错误信息（带错误图标）
        if let errorMessage = priceManager.errorMessage {
            let errorItem = NSMenuItem(title: "错误: \(errorMessage)", action: nil, keyEquivalent: "")
            if let errorImage = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "错误") {
                errorImage.size = NSSize(width: 16, height: 16)
                errorItem.image = errorImage
            }
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        // 添加最后更新时间（带时钟图标）
        let timeItem = NSMenuItem(title: "上次更新: \(getCurrentTime())", action: nil, keyEquivalent: "")
        if let clockImage = NSImage(systemSymbolName: "clock", accessibilityDescription: "时间") {
            clockImage.size = NSSize(width: 16, height: 16)
            timeItem.image = clockImage
        }
        timeItem.isEnabled = false
        menu.addItem(timeItem)

        menu.addItem(NSMenuItem.separator())

  
        // 添加刷新按钮（带刷新图标）
        let refreshTitle = priceManager.isFetching ? "刷新中..." : "刷新价格"
        let refreshItem = NSMenuItem(title: refreshTitle, action: #selector(refreshPrice), keyEquivalent: "r")
        if let refreshImage = NSImage(systemSymbolName: priceManager.isFetching ? "hourglass" : "arrow.clockwise", accessibilityDescription: "刷新") {
            refreshImage.size = NSSize(width: 16, height: 16)
            refreshItem.image = refreshImage
        }
        refreshItem.target = self
        refreshItem.isEnabled = !priceManager.isFetching
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())

        // 添加偏好设置菜单项（支持 Cmd+, 快捷键）
        let preferencesItem = NSMenuItem(title: "偏好设置", action: #selector(showPreferences), keyEquivalent: ",")
        if let preferencesImage = NSImage(systemSymbolName: "gear", accessibilityDescription: "偏好设置") {
            preferencesImage.size = NSSize(width: 16, height: 16)
            preferencesItem.image = preferencesImage
        }
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())

        #if DEBUG
        // 添加重置设置按钮（仅在 Debug 模式下显示）
        let resetItem = NSMenuItem(title: "重置设置", action: #selector(resetSettings), keyEquivalent: "")
        if let resetImage = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "重置设置") {
            resetImage.size = NSSize(width: 16, height: 16)
            resetItem.image = resetImage
        }
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())
        #endif

        // 添加GitHub按钮（带GitHub图标）
        let checkUpdateItem = NSMenuItem(title: "GitHub", action: #selector(checkForUpdates), keyEquivalent: "")
        if let updateImage = NSImage(systemSymbolName: "star.circle", accessibilityDescription: "GitHub") {
            updateImage.size = NSSize(width: 16, height: 16)
            checkUpdateItem.image = updateImage
        }
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

        // 添加关于按钮（带信息图标）
        let aboutItem = NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: "")
        if let infoImage = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "关于") {
            infoImage.size = NSSize(width: 16, height: 16)
            aboutItem.image = infoImage
        }
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 添加退出按钮（带退出图标）
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        if let quitImage = NSImage(systemSymbolName: "power", accessibilityDescription: "退出") {
            quitImage.size = NSSize(width: 16, height: 16)
            quitItem.image = quitImage
        }
        quitItem.target = self
        menu.addItem(quitItem)

        // 安全显示菜单
        guard let statusItem = statusItem,
              let button = statusItem.button else {
            print("❌ 无法显示菜单 - 状态栏项目不可用")
            return
        }

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    // 获取当前时间字符串
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }

    // 刷新价格
    @objc private func refreshPrice() {
        Task {
            await priceManager.refreshPrice()
        }
    }

  
    // 选择币种或执行Option+点击功能
    @objc private func selectOrCopySymbol(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any] else {
            print("❌ 无法获取菜单项数据")
            return
        }

        // 检查是否按住了 Option 键
        let currentEvent = NSApp.currentEvent
        let isOptionPressed = currentEvent?.modifierFlags.contains(.option) ?? false
        let isCustom = data["isCustom"] as? Bool ?? false

        // 获取币种信息
        let displayName: String
        let symbolForURL: String // 用于生成币安URL的币种符号

        if isCustom {
            guard let customSymbol = data["customSymbol"] as? CustomCryptoSymbol else {
                print("❌ 无法获取自定义币种数据")
                return
            }
            displayName = customSymbol.displayName
            symbolForURL = customSymbol.symbol // 自定义币种的符号（如BTC, ETH）
        } else {
            guard let symbol = data["symbol"] as? CryptoSymbol else {
                print("❌ 无法获取默认币种数据")
                return
            }
            displayName = symbol.displayName
            symbolForURL = symbol.displayName // 使用displayName获取币种基础符号（如BTC, ETH）
        }

        if isOptionPressed {
            // 根据用户设置的Option+点击功能执行相应操作
            let optionAction = appSettings.optionClickAction

            switch optionAction {
            case .copyPrice:
                // 复制价格到剪贴板
                copyPriceToClipboard(symbol: displayName, data: data, isCustom: isCustom)

            case .openSpotTrading:
                // 打开币安现货交易页面
                let spotSuccess = BinanceURLGenerator.openSpotTradingPage(for: symbolForURL)
                if spotSuccess {
                    print("✅ 已打开 \(displayName) 币安现货交易页面")
                } else {
                    print("❌ 打开 \(displayName) 币安现货交易页面失败")
                }

            case .openFuturesTrading:
                // 打开币安合约交易页面
                let futuresSuccess = BinanceURLGenerator.openFuturesTradingPage(for: symbolForURL)
                if futuresSuccess {
                    print("✅ 已打开 \(displayName) 币安合约交易页面")
                } else {
                    print("❌ 打开 \(displayName) 币安合约交易页面失败")
                }
            }
        } else {
            // 正常点击：选择该币种
            selectSymbol(data: data, isCustom: isCustom, displayName: displayName)
        }
    }

    // 复制价格到剪贴板的辅助方法
    private func copyPriceToClipboard(symbol: String, data: [String: Any], isCustom: Bool) {
        let price = data["price"] as? Double ?? 0.0

        // 如果价格还没加载完成，先获取价格再复制
        if price == 0.0 {
            Task { @MainActor in
                print("🔄 价格未加载，正在获取 \(symbol) 价格...")
                var newPrice: Double?

                if isCustom, let customSymbol = data["customSymbol"] as? CustomCryptoSymbol {
                    newPrice = await self.priceManager.fetchCustomSymbolPrice(forApiSymbol: customSymbol.apiSymbol)
                } else if let symbol = data["symbol"] as? CryptoSymbol {
                    newPrice = await self.priceManager.fetchSinglePrice(for: symbol)
                }

                if let priceToCopy = newPrice {
                    let priceString = self.formatPriceWithCommas(priceToCopy)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("$\(priceString)", forType: .string)

                    print("✅ 已复制 \(symbol) 价格到剪贴板: $\(priceString)")
                } else {
                    print("❌ 无法获取 \(symbol) 价格")
                }
            }
        } else {
            let priceString = formatPriceWithCommas(price)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("$\(priceString)", forType: .string)

            print("✅ 已复制 \(symbol) 价格到剪贴板: $\(priceString)")
        }
    }

    // 选择币种的辅助方法
    private func selectSymbol(data: [String: Any], isCustom: Bool, displayName: String) {
        if isCustom, let customSymbol = data["customSymbol"] as? CustomCryptoSymbol {
            // 选择自定义币种 - 找到对应的索引并选择
            if let index = appSettings.customCryptoSymbols.firstIndex(of: customSymbol) {
                appSettings.selectCustomCryptoSymbol(at: index)
                print("✅ 已切换到自定义币种: \(displayName)")
            }

            // 立即更新价格管理器和UI
            self.priceManager.updateCryptoSymbolSettings()
            // 使用0.0价格强制更新显示状态，确保图标和文字都正确更新
            self.updateMenuBarTitle(price: 0.0)
        } else if let symbol = data["symbol"] as? CryptoSymbol {
            // 选择默认币种
            appSettings.saveSelectedSymbol(symbol)
            print("✅ 已切换到默认币种: \(displayName)")

            // 立即更新价格管理器和UI
            self.priceManager.updateCryptoSymbolSettings()
            // 使用0.0价格强制更新显示状态，确保图标和文字都正确更新
            self.updateMenuBarTitle(price: 0.0)
        }
    }

    // 显示偏好设置窗口
    @objc private func showPreferences() {
        print("⚙️ [BTCMenuBarApp] 用户打开偏好设置")
        preferencesWindowManager.showPreferencesWindow()
    }

    // 显示关于窗口
    @objc private func showAbout() {
        let currentInterval = priceManager.getCurrentRefreshInterval()
        let version = getAppVersion()

        // 使用新的关于窗口替代 NSAlert
        aboutWindowManager.showAboutWindow(
            currentRefreshInterval: currentInterval.displayText,
            appVersion: version,
            appSettings: appSettings
        )
    }

    // 重置设置为默认值（仅在 Debug 模式下可用）
    @objc private func resetSettings() {
        #if DEBUG
        let alert = NSAlert()
        alert.messageText = "重置设置"
        alert.informativeText = "确定要将所有设置重置为默认值吗？\n\n将重置以下所有设置：\n• 币种：BTC\n• 刷新间隔：30秒\n• 自定义币种：清空所有自定义币种\n• 代理设置：关闭代理，清空配置\n• 开机自启动：关闭开机自启动"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 重置设置
            appSettings.resetToDefaults()

            // 显示确认消息
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "重置完成"
            confirmAlert.informativeText = "所有设置已重置为默认值，应用将立即生效。"
            confirmAlert.alertStyle = .informational
            confirmAlert.addButton(withTitle: "确定")
            confirmAlert.runModal()

            print("🔧 [BTCMenuBarApp] 用户手动重置了所有设置")
        }
        #endif
    }

    // 打开GitHub页面
    @objc private func checkForUpdates() {
        let githubURL = "https://github.com/jiayouzl/Bitcoin-Monitoring"

        // 确保URL有效
        guard let url = URL(string: githubURL) else {
            print("❌ 无效的URL: \(githubURL)")
            return
        }

        // 使用默认浏览器打开URL
        NSWorkspace.shared.open(url)

        print("✅ 已在浏览器中打开GitHub页面: \(githubURL)")
    }

    // 获取应用版本信息
    /// - Returns: 版本号字符串，格式为 "主版本号.次版本号.修订号"
    private func getAppVersion() -> String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "未知版本"
        }

        return version
    }

    
    
    // 退出应用
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
