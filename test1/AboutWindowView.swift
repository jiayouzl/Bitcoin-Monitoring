//
//  AboutWindowView.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/31.
//

import SwiftUI

/**
 * GitHub版本信息模型
 * 用于解析GitHub API返回的版本数据
 */
struct GitHubRelease: Codable {
    let name: String
    let zipball_url: String
    let tarball_url: String
    let commit: GitHubCommit
}

struct GitHubCommit: Codable {
    let sha: String
    let url: String
}

/**
 * 更新错误类型
 */
enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noReleasesFound
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的API地址"
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "服务器错误 (HTTP \(code))"
        case .noReleasesFound:
            return "未找到发布版本"
        case .decodingError:
            return "版本数据解析失败"
        }
    }
}

/**
 * 关于窗口视图组件
 * 使用 SwiftUI 实现的美观关于界面，替代原有的 NSAlert 对话框
 */
struct AboutWindowView: View {
    // 窗口关闭回调
    let onClose: () -> Void

    // 当前刷新间隔
    let currentRefreshInterval: String

    // 应用版本
    let appVersion: String

    // 更新检测状态
    @State private var isCheckingForUpdates = false
    @State private var showingUpdateAlert = false
    @State private var updateAlertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和标题区域
            VStack(spacing: 16) {
                // 应用图标
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)

                // 应用标题和版本
                VStack(spacing: 4) {
                    Text("Bitcoin Monitoring")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("版本 \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 功能特性描述
            VStack(alignment: .leading, spacing: 12) {
                Text("功能特性")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "实时价格监控", description: "支持 BTC/ETH/BNB/SOL/DOGE")

                    FeatureRow(icon: "timer", title: "可自定义刷新间隔", description: "当前：\(currentRefreshInterval)")

                    FeatureRow(icon: "exclamationmark.triangle.fill", title: "智能重试机制", description: "网络错误自动恢复")

                }
            }

            Divider()

            // 使用提示
            VStack(alignment: .leading, spacing: 8) {
                Text("使用技巧")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 6) {
                    TipRow(text: "• 点击币种名称切换菜单栏显示")
                    TipRow(text: "• Option + 点击币种名称复制价格")
                }
            }

//            Spacer()
//                .frame(height: 10) // 减少间距，让按钮上移

            // 按钮区域
            HStack(spacing: 12) {
                // 检测更新按钮
                Button(action: checkForUpdates) {
                    HStack {
                        if isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isCheckingForUpdates ? "检测中..." : "检测更新")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingForUpdates)

                Spacer()

                // 关闭按钮
                Button(action: onClose) {
                    Text("确定")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 500)
        .alert("检测更新", isPresented: $showingUpdateAlert) {
            Button("确定", role: .cancel) {
                // 如果消息中包含"发现新版本"，则打开发布页面并关闭窗口
                if updateAlertMessage.contains("发现新版本") {
                    openReleasePage()
                    onClose()
                }
            }
        } message: {
            Text(updateAlertMessage)
        }
    }

    /**
     * 检测更新
     */
    private func checkForUpdates() {
        print("🔍 用户点击了检测更新按钮")

        isCheckingForUpdates = true

        // 在后台线程执行网络请求
        DispatchQueue.global(qos: .userInitiated).async {
            self.performUpdateCheck()
        }
    }

    /**
     * 执行更新检测
     */
    private func performUpdateCheck() {
        do {
            // 获取最新版本信息
            let latestVersion = try fetchLatestVersion()
            print("✅ 获取到最新版本: \(latestVersion)")

            // 比较版本号
            let comparisonResult = compareVersions(appVersion, latestVersion)
            print("📊 版本比较结果: \(comparisonResult)")

            // 回到主线程更新UI状态
            DispatchQueue.main.async {
                self.isCheckingForUpdates = false

                switch comparisonResult {
                case .orderedSame:
                    self.updateAlertMessage = "🎉 您已使用最新版本！"
                    self.showingUpdateAlert = true
                    print("✅ 已是最新版本")
                case .orderedAscending:
                    self.updateAlertMessage = "🆕 发现新版本！\n当前版本：\(self.appVersion)\n最新版本：\(latestVersion)\n\n点击确定后将自动打开GitHub发布页面。"
                    self.showingUpdateAlert = true
                    print("🆕 发现新版本: \(latestVersion)")
                case .orderedDescending:
                    self.updateAlertMessage = "🎉 您已使用最新版本！\n当前版本：\(self.appVersion)"
                    self.showingUpdateAlert = true
                    print("✅ 当前版本比发布版本更新")
                }
            }

        } catch {
            let errorMessage = error.localizedDescription
            print("❌ 检测更新失败: \(errorMessage)")

            DispatchQueue.main.async {
                self.isCheckingForUpdates = false
                self.updateAlertMessage = "❌ 检测更新失败\n\n错误信息：\(errorMessage)\n\n请检查网络连接后重试。"
                self.showingUpdateAlert = true
            }
        }
    }

    /**
     * 从GitHub API获取最新版本
     * - Returns: 最新版本号字符串
     * - Throws: 网络错误或解析错误
     */
    private func fetchLatestVersion() throws -> String {
        // GitHub API配置
        let gitHubAPIURL = "https://api.github.com/repos/jiayouzl/Bitcoin-Monitoring/tags"

        // 构建请求URL
        guard let url = URL(string: gitHubAPIURL) else {
            throw UpdateError.invalidURL
        }

        print("🌐 请求URL: \(url)")

        // 使用信号量实现同步网络请求
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?

        // 配置请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Bitcoin-Monitoring", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        // 发送网络请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                result = .failure(error)
                semaphore.signal()
                return
            }

            // 检查HTTP响应状态
            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(UpdateError.invalidResponse)
                semaphore.signal()
                return
            }

            guard httpResponse.statusCode == 200 else {
                result = .failure(UpdateError.httpError(httpResponse.statusCode))
                semaphore.signal()
                return
            }

            print("✅ API响应状态码: \(httpResponse.statusCode)")

            guard let data = data else {
                result = .failure(UpdateError.noReleasesFound)
                semaphore.signal()
                return
            }

            do {
                // 解析JSON数据
                let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

                guard let latestRelease = releases.first else {
                    result = .failure(UpdateError.noReleasesFound)
                    semaphore.signal()
                    return
                }

                // 提取版本号（去掉v前缀）
                let versionString = latestRelease.name
                let cleanVersion = versionString.hasPrefix("v") ?
                    String(versionString.dropFirst()) : versionString

                result = .success(cleanVersion)
            } catch {
                result = .failure(UpdateError.decodingError)
            }

            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        // 处理结果
        guard let result = result else {
            throw UpdateError.noReleasesFound
        }

        switch result {
        case .success(let version):
            return version
        case .failure(let error):
            throw error
        }
    }

    /**
     * 比较版本号
     * - Parameters:
     *   - version1: 版本号1
     *   - version2: 版本号2
     * - Returns: 比较结果
     */
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        // 处理版本号格式，移除非数字字符（除点外）
        let cleanV1 = version1.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        let cleanV2 = version2.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        let v1Components = cleanV1.split(separator: ".").compactMap { Int($0) }
        let v2Components = cleanV2.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(v1Components.count, v2Components.count)

        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0

            if v1Value < v2Value {
                return .orderedAscending
            } else if v1Value > v2Value {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    /**
     * 打开发布页面
     */
    private func openReleasePage() {
        let releasePageURL = "https://github.com/jiayouzl/Bitcoin-Monitoring/releases/latest"
        guard let url = URL(string: releasePageURL) else {
            print("❌ 无效的发布页面URL: \(releasePageURL)")
            return
        }

        NSWorkspace.shared.open(url)
        print("✅ 已在浏览器中打开发布页面: \(releasePageURL)")
    }
}

/**
 * 功能特性行组件
 */
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

/**
 * 使用技巧行组件
 */
struct TipRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

/**
 * 关于窗口管理器
 * 负责创建和管理关于窗口的显示
 */
class AboutWindowManager: ObservableObject {
    private var aboutWindow: NSWindow?

    /**
     * 显示关于窗口
     * - Parameters:
     *   - currentRefreshInterval: 当前刷新间隔显示文本
     *   - appVersion: 应用版本号
     */
    func showAboutWindow(currentRefreshInterval: String, appVersion: String) {
        // 如果窗口已存在，则将其带到前台
        if let existingWindow = aboutWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // 创建新的关于窗口
        let aboutView = AboutWindowView(
            onClose: { [weak self] in
                self?.closeAboutWindow()
            },
            currentRefreshInterval: currentRefreshInterval,
            appVersion: appVersion
        )

        let hostingView = NSHostingView(rootView: aboutView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 540), // 与视图高度保持一致
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "关于"
        window.contentViewController = NSViewController()
        window.contentViewController?.view = hostingView

        // 强制窗口布局完成后再设置居中位置
        window.layoutIfNeeded()

        // 设置窗口在屏幕垂直居中显示
        centerWindowInScreen(window)

        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        // 设置窗口级别，确保显示在最前面
        window.level = .floating

        // 保存窗口引用
        self.aboutWindow = window

        // 显示窗口
        window.makeKeyAndOrderFront(nil)

        print("✅ 已显示关于窗口")
    }

    /**
     * 将窗口在屏幕中垂直居中显示
     * - Parameter window: 要居中的窗口
     */
    private func centerWindowInScreen(_ window: NSWindow) {
        guard let screen = NSScreen.main else {
            // 如果无法获取主屏幕信息，使用默认的 center() 方法
            window.center()
            return
        }

        // 先使用系统的 center() 方法进行基础居中
        window.center()

        // 获取居中后的窗口位置
        let currentFrame = window.frame
        let screenFrame = screen.visibleFrame

        // 计算理想的垂直居中位置
        let idealCenterY = screenFrame.origin.y + (screenFrame.height - currentFrame.height) / 2

        // 如果当前Y位置不等于理想的Y位置，进行调整
        if abs(currentFrame.origin.y - idealCenterY) > 1 {
            var adjustedFrame = currentFrame
            adjustedFrame.origin.y = idealCenterY
            window.setFrame(adjustedFrame, display: false)

            print("✅ 窗口位置已调整到垂直居中")
            print("📐 原始Y位置: \(currentFrame.origin.y)")
            print("📐 调整后Y位置: \(idealCenterY)")
        } else {
            print("✅ 窗口已经在垂直居中位置")
        }

        print("📐 屏幕可见区域: \(screenFrame)")
        print("📐 最终窗口位置: \(window.frame)")
    }

    /**
     * 关闭关于窗口
     */
    private func closeAboutWindow() {
        aboutWindow?.close()
        aboutWindow = nil
        print("✅ 已关闭关于窗口")
    }
}

#Preview {
    AboutWindowView(
        onClose: {},
        currentRefreshInterval: "30秒",
        appVersion: "1.0.0"
    )
}
