//
//  PreferencesWindowView.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/31.
//

import SwiftUI

/**
 * 偏好设置窗口视图组件
 * 使用 SwiftUI 实现的美观偏好设置界面，包含刷新设置和代理设置
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
        VStack(spacing: 0) {
            // 主要内容区域
            ScrollView {
                VStack(spacing: 24) {
                    // 刷新设置区域
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

                    // 开机启动设置区域
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

                    // 代理设置区域
                    SettingsGroupView(title: "代理设置", icon: "network") {
                        VStack(alignment: .leading, spacing: 16) {
                            // 代理开关
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

                            // 代理配置输入框 - 始终显示
                            VStack(alignment: .leading, spacing: 12) {
                                Text("代理服务器配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // 服务器地址和端口
                                HStack(spacing: 12) {
                                    // 服务器地址
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("服务器地址")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        TextField("例如: proxy.example.com", text: $tempProxyHost)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(maxWidth: .infinity)
                                            .disabled(!tempProxyEnabled)
                                    }

                                    // 端口
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("端口")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        TextField("8080", text: $tempProxyPort)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 80)
                                            .disabled(!tempProxyEnabled)
                                    }
                                }

                                // 认证配置
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("认证设置 (可选)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 12) {
                                        // 用户名
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("用户名")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            TextField("用户名", text: $tempProxyUsername)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(maxWidth: .infinity)
                                                .disabled(!tempProxyEnabled)
                                        }

                                        // 密码
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("密码")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            SecureField("密码", text: $tempProxyPassword)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(maxWidth: .infinity)
                                                .disabled(!tempProxyEnabled)
                                        }
                                    }
                                }

                                // 测试按钮
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
                            .opacity(tempProxyEnabled ? 1.0 : 0.6) // 视觉反馈显示开关状态
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(24)
            }

            Divider()

            // 底部按钮区域
            HStack {
                Spacer()

                // 取消按钮
                Button("取消") {
                    onClose()
                }
                .keyboardShortcut(.escape)

                // 保存按钮
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
        .frame(width: 480, height: 700)
        .alert("配置验证", isPresented: $showingValidationError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(validationErrorMessage)
        }
        .alert("代理测试结果", isPresented: $showingProxyTestResult) {
            Button("确定", role: .cancel) { }
        } message: {
            HStack {
                Image(systemName: proxyTestSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(proxyTestSucceeded ? .green : .red)
                Text(proxyTestResultMessage)
            }
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
