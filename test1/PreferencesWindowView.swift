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
    @State private var tempLaunchAtLogin: Bool

    // 验证状态
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""

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
                            }

                            if tempProxyEnabled {
                                // 代理配置输入框
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("代理服务器配置")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 12) {
                                        // 服务器地址
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("服务器地址")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            TextField("例如: proxy.example.com", text: $tempProxyHost)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(maxWidth: .infinity)
                                        }

                                        // 端口
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("端口")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            TextField("8080", text: $tempProxyPort)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 80)
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .animation(.easeInOut(duration: 0.2), value: tempProxyEnabled)
                            }
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
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
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
        .frame(width: 480, height: 520)
        .alert("配置验证", isPresented: $showingValidationError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(validationErrorMessage)
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
            port: port
        )

        if tempProxyEnabled {
            print("✅ [Preferences] 已保存代理设置: \(tempProxyHost):\(port)")
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
        Button(action: onSelect) {
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PreferencesWindowView(
        appSettings: AppSettings(),
        onClose: {}
    )
}
