//
//  PreferencesWindowView.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/31.
//

import SwiftUI

/**
 * 设置标签页枚举
 * 定义偏好设置中的主要分类标签
 */
enum SettingsTab: String, CaseIterable {
    case general = "通用"
    case custom = "自定义币种"
    case proxy = "代理设置"

    /// 标签对应的SF Symbols图标
    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .custom:
            return "plus.circle"
        case .proxy:
            return "network"
        }
    }

    /// 标签显示文本
    var displayText: String {
        return self.rawValue
    }
}

/**
 * 偏好设置窗口视图组件
 * 使用现代化顶部标签栏导航的SwiftUI偏好设置界面
 */
struct PreferencesWindowView: View {
    // 窗口关闭回调
    let onClose: () -> Void

    // 应用设置
    @ObservedObject var appSettings: AppSettings

    // 临时配置状态（用于编辑但未保存的状态）
    @State private var tempRefreshInterval: RefreshInterval
    @State private var tempProxyEnabled: Bool
    @State private var tempProxyHost: String
    @State private var tempProxyPort: String
    @State private var tempProxyUsername: String
    @State private var tempProxyPassword: String
    @State private var tempLaunchAtLogin: Bool

    // 验证状态
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""

    // 代理测试状态
    @State private var isTestingProxy = false
    @State private var showingProxyTestResult = false
    @State private var proxyTestResultMessage = ""
    @State private var proxyTestSucceeded = false

    // 保存状态
    @State private var isSaving = false

    // 自定义币种相关状态
    @State private var customSymbolInput: String = ""
    @State private var isCustomSymbolValid: Bool = false
    @State private var customSymbolErrorMessage: String?
    @State private var showingCustomSymbolDeleteConfirmation: Bool = false

    // 导航状态 - 当前选中的标签页
    @State private var selectedTab: SettingsTab = .general

    // 悬停状态
    @State private var hoveredTab: SettingsTab? = nil

    init(appSettings: AppSettings, onClose: @escaping () -> Void) {
        self.appSettings = appSettings
        self.onClose = onClose

        // 初始化临时状态
        self._tempRefreshInterval = State(initialValue: appSettings.refreshInterval)
        self._tempProxyEnabled = State(initialValue: appSettings.proxyEnabled)
        self._tempProxyHost = State(initialValue: appSettings.proxyHost)
        self._tempProxyPort = State(initialValue: String(appSettings.proxyPort))
        self._tempProxyUsername = State(initialValue: appSettings.proxyUsername)
        self._tempProxyPassword = State(initialValue: appSettings.proxyPassword)
        self._tempLaunchAtLogin = State(initialValue: appSettings.launchAtLogin)
    }

    var body: some View {
        mainContentView
            .frame(width: 480, height: 500)
            .alert("配置验证", isPresented: $showingValidationError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
            .alert("代理测试结果", isPresented: $showingProxyTestResult) {
                Button("确定", role: .cancel) { }
            } message: {
                proxyTestAlertContent
            }
            .alert("删除自定义币种", isPresented: $showingCustomSymbolDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteCustomSymbol()
                }
            } message: {
                deleteCustomSymbolMessage
            }
    }

    // 主要内容视图
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 顶部标签栏导航
            topTabBarView

            Divider()

            // 内容区域
            ScrollView {
                settingsContentView
                    .padding(24)
            }

            Divider()

            bottomButtonsView
        }
    }

    // 顶部标签栏导航视图
    private var topTabBarView: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                // 使用整个标签区域作为可点击区域
                HStack(spacing: 8) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)

                    Text(tab.displayText)
                        .font(.system(size: 13))
                        .fontWeight(selectedTab == tab ? .medium : .regular)
                        .foregroundColor(selectedTab == tab ? .blue : .primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 填充整个可用空间
                .contentShape(Rectangle()) // 确保整个矩形区域都可点击
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(selectedTab == tab ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
                )
                .background(
                    // 悬停效果
                    RoundedRectangle(cornerRadius: 0)
                        .fill(hoveredTab == tab && selectedTab != tab ? Color(NSColor.controlAccentColor).opacity(0.05) : Color.clear)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                        hoveredTab = tab
                    } else {
                        NSCursor.arrow.set()
                        if hoveredTab == tab {
                            hoveredTab = nil
                        }
                    }
                }

                // 在标签之间添加分隔线（除了最后一个）
                if tab != SettingsTab.allCases.last {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 44)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // 设置内容视图 - 根据选中的标签显示对应内容
    private var settingsContentView: some View {
        VStack(spacing: 24) {
            // 根据选中的标签显示对应内容
            Group {
                switch selectedTab {
                case .general:
                    generalSettingsView
                case .custom:
                    customCryptoSettingsView
                case .proxy:
                    proxySettingsView
                }
            }

            Spacer(minLength: 20)
        }
    }

    // 通用设置视图（刷新间隔 + 启动设置）
    private var generalSettingsView: some View {
        VStack(spacing: 24) {
            refreshSettingsView
            launchSettingsView
        }
    }

    
    // 刷新设置视图
    private var refreshSettingsView: some View {
        SettingsGroupView(title: "刷新设置", icon: "timer") {
            VStack(alignment: .leading, spacing: 12) {
                Text("选择价格刷新间隔")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach(RefreshInterval.allCases, id: \.self) { interval in
                        IntervalSelectionButton(
                            interval: interval,
                            isSelected: tempRefreshInterval == interval,
                            onSelect: { tempRefreshInterval = interval }
                        )
                    }
                }
            }
        }
    }

    // 启动设置视图
    private var launchSettingsView: some View {
        SettingsGroupView(title: "启动设置", icon: "power") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开机自动启动")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Text("应用将在系统启动时自动运行")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $tempLaunchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
        }
    }

    // 代理设置视图
    private var proxySettingsView: some View {
        SettingsGroupView(title: "代理设置", icon: "network") {
            VStack(alignment: .leading, spacing: 16) {
                proxyToggleView
                proxyConfigView
            }
            .opacity(tempProxyEnabled ? 1.0 : 0.6)
        }
    }

    // 代理开关视图
    private var proxyToggleView: some View {
        HStack {
            Text("启用HTTP代理")
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $tempProxyEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    // 代理配置视图
    private var proxyConfigView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("代理服务器配置")
                .font(.caption)
                .foregroundColor(.secondary)

            proxyServerConfigView
            proxyAuthConfigView
            proxyTestButtonView
        }
    }

    // 代理服务器配置视图
    private var proxyServerConfigView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("服务器地址")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("ip or proxy.example.com", text: $tempProxyHost)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!tempProxyEnabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("端口")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("3128", text: $tempProxyPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .disabled(!tempProxyEnabled)
            }
        }
    }

    // 代理认证配置视图
    private var proxyAuthConfigView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("认证设置 (可选)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("用户名")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("user", text: $tempProxyUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(!tempProxyEnabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("密码")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SecureField("password", text: $tempProxyPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(!tempProxyEnabled)
                }
            }
        }
    }

    // 代理测试按钮视图
    private var proxyTestButtonView: some View {
        HStack {
            Spacer()

            Button(action: testProxyConnection) {
                HStack {
                    if isTestingProxy {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 8, height: 8)
                    } else {
                        Image(systemName: "network")
                            .font(.system(size: 12))
                    }
                    Text(isTestingProxy ? "测试中..." : "测试连接")
                }
                .frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!tempProxyEnabled || isTestingProxy || isSaving)
        }
    }

    // 自定义币种设置视图
    private var customCryptoSettingsView: some View {
        SettingsGroupView(title: "自定义币种", icon: "plus.circle") {
            VStack(alignment: .leading, spacing: 16) {
                if appSettings.isUsingCustomSymbol() {
                    currentCustomSymbolView
                } else {
                    addCustomSymbolView
                }
            }
        }
    }

    // 当前自定义币种视图
    private var currentCustomSymbolView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: appSettings.getCurrentActiveSystemImageName())
                    .foregroundColor(.orange)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("当前自定义币种")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(appSettings.getCurrentActivePairDisplayName())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("删除") {
                    showingCustomSymbolDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
    }

    // 添加自定义币种视图
    private var addCustomSymbolView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加自定义币种")
                .font(.subheadline)
                .foregroundColor(.primary)

            Text("输入3-5个大写字母的币种符号（如 ADA、DOGE、SHIB）")
                .font(.caption)
                .foregroundColor(.secondary)

            customSymbolInputView
        }
    }

    // 自定义币种输入视图
    private var customSymbolInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("币种符号")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                TextField("例如: ADA", text: Binding(
                    get: { customSymbolInput },
                    set: { newValue in
                        let filteredValue = newValue.filter { $0.isLetter }.uppercased()
                        customSymbolInput = String(filteredValue.prefix(5))

                        let validation = CustomCryptoSymbol.isValidSymbol(customSymbolInput)
                        isCustomSymbolValid = validation.isValid
                        customSymbolErrorMessage = validation.errorMessage
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)

                Button("添加") {
                    addCustomSymbol()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isCustomSymbolValid || isSaving)
            }

            if !isCustomSymbolValid && !customSymbolInput.isEmpty {
                Text(customSymbolErrorMessage ?? "输入格式不正确")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }

            if customSymbolInput.isEmpty {
                Text("输入币种符号后将自动验证")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
            }
        }
    }

    // 底部按钮视图
    private var bottomButtonsView: some View {
        HStack {
            Spacer()

            Button("取消") {
                onClose()
            }
            .keyboardShortcut(.escape)

            Button(action: saveSettings) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 8, height: 8)
                    }
                    Text("保存")
                }
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // 代理测试警告内容
    private var proxyTestAlertContent: some View {
        HStack {
            Image(systemName: proxyTestSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(proxyTestSucceeded ? .green : .red)
            Text(proxyTestResultMessage)
        }
    }

    // 删除自定义币种确认消息
    private var deleteCustomSymbolMessage: Text {
        if let customSymbol = appSettings.customCryptoSymbol {
            return Text("确定要删除自定义币种 \"\(customSymbol.displayName)\" 吗？删除后将无法恢复。")
        } else {
            return Text("确定要删除自定义币种吗？删除后将无法恢复。")
        }
    }

    /**
     * 保存设置
     */
    private func saveSettings() {
        print("🔧 [Preferences] 用户点击了保存按钮")

        // 验证代理设置
        if tempProxyEnabled {
            let validation = validateProxyInput()
            if !validation.isValid {
                validationErrorMessage = validation.errorMessage ?? "配置验证失败"
                showingValidationError = true
                return
            }
        }

        isSaving = true

        // 保存刷新间隔设置
        appSettings.saveRefreshInterval(tempRefreshInterval)
        print("✅ [Preferences] 已保存刷新间隔: \(tempRefreshInterval.displayText)")

        // 保存开机启动设置
        if tempLaunchAtLogin != appSettings.launchAtLogin {
            appSettings.toggleLoginItem(enabled: tempLaunchAtLogin)
            print("✅ [Preferences] 已设置开机自启动: \(tempLaunchAtLogin)")
        }

        // 保存代理设置
        let port = Int(tempProxyPort) ?? 8080
        appSettings.saveProxySettings(
            enabled: tempProxyEnabled,
            host: tempProxyHost,
            port: port,
            username: tempProxyUsername,
            password: tempProxyPassword
        )

        if tempProxyEnabled {
            let authInfo = !tempProxyUsername.isEmpty ? " (认证: \(tempProxyUsername))" : ""
            print("✅ [Preferences] 已保存代理设置: \(tempProxyHost):\(port)\(authInfo)")
        } else {
            print("✅ [Preferences] 已禁用代理设置")
        }

        // 短暂延迟后关闭窗口，让用户看到保存状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            onClose()
        }
    }

    /**
     * 测试代理连接
     */
    private func testProxyConnection() {
        print("🔧 [Preferences] 开始测试代理连接...")

        // 首先验证输入
        let validation = validateProxyInput()
        if !validation.isValid {
            proxyTestResultMessage = validation.errorMessage ?? "配置验证失败"
            proxyTestSucceeded = false
            showingProxyTestResult = true
            return
        }

        isTestingProxy = true

        Task {
            // 创建临时价格服务实例进行测试
            let tempAppSettings = AppSettings()
            tempAppSettings.saveProxySettings(
                enabled: true,
                host: tempProxyHost.trimmingCharacters(in: .whitespacesAndNewlines),
                port: Int(tempProxyPort) ?? 8080,
                username: tempProxyUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                password: tempProxyPassword
            )

            let tempPriceService = PriceService(appSettings: tempAppSettings)
            let success = await tempPriceService.testProxyConnection()

            await MainActor.run {
                isTestingProxy = false

                if success {
                    proxyTestResultMessage = "代理连接测试成功！可以正常访问币安API。"
                    proxyTestSucceeded = true
                    print("✅ [Preferences] 代理连接测试成功")
                } else {
                    proxyTestResultMessage = "代理连接测试失败，请检查代理配置或网络连接。"
                    proxyTestSucceeded = false
                    print("❌ [Preferences] 代理连接测试失败")
                }

                showingProxyTestResult = true
            }
        }
    }

    /**
     * 验证代理输入
     * - Returns: 验证结果
     */
    private func validateProxyInput() -> (isValid: Bool, errorMessage: String?) {
        let trimmedHost = tempProxyHost.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证服务器地址
        if trimmedHost.isEmpty {
            return (false, "代理服务器地址不能为空")
        }

        // 验证端口
        guard let port = Int(tempProxyPort), port > 0, port <= 65535 else {
            return (false, "代理端口必须在 1-65535 范围内")
        }

        return (true, nil)
    }

    // MARK: - 自定义币种相关方法

    /**
     * 添加自定义币种
     */
    private func addCustomSymbol() {
        guard isCustomSymbolValid, !customSymbolInput.isEmpty else {
            return
        }

        do {
            let customSymbol = try CustomCryptoSymbol(symbol: customSymbolInput)
            appSettings.saveCustomCryptoSymbol(customSymbol)

            // 清空输入状态
            customSymbolInput = ""
            isCustomSymbolValid = false
            customSymbolErrorMessage = nil

            print("✅ [Preferences] 已添加自定义币种: \(customSymbol.displayName)")
        } catch {
            // 这种情况理论上不会发生，因为我们在onChange中已经验证了
            print("❌ [Preferences] 添加自定义币种失败: \(error.localizedDescription)")
        }
    }

    /**
     * 删除自定义币种
     */
    private func deleteCustomSymbol() {
        appSettings.removeCustomCryptoSymbol()
        print("✅ [Preferences] 已删除自定义币种")
    }
}

/**
 * 设置分组视图组件
 */
struct SettingsGroupView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分组标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            // 分组内容
            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}



/**
 * 刷新间隔选择按钮组件
 */
struct IntervalSelectionButton: View {
    let interval: RefreshInterval
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .blue : .secondary)

            Text(interval.displayText)
                .font(.system(size: 13))
                .fontWeight(isSelected ? .medium : .regular)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color(NSColor.separatorColor), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6)) // 确保整个区域可点击
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    PreferencesWindowView(
        appSettings: AppSettings(),
        onClose: {}
    )
}
