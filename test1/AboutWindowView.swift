//
//  AboutWindowView.swift
//  test1
//
//  Created by Mark on 2025/10/31.
//

import SwiftUI

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
                // GitHub 按钮
                Button(action: openGitHub) {
                    HStack {
                        Image(systemName: "star.circle")
                        Text("GitHub")
                    }
                }
                .buttonStyle(.bordered)

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
    }

    /**
     * 打开 GitHub 页面
     */
    private func openGitHub() {
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
