//
//  PreferencesWindowManager.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/31.
//

import SwiftUI

/**
 * 偏好设置窗口管理器
 * 负责创建和管理偏好设置窗口的显示
 */
class PreferencesWindowManager: ObservableObject {
    private var preferencesWindow: NSWindow?
    private var appSettings: AppSettings

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }

    /**
     * 显示偏好设置窗口
     */
    func showPreferencesWindow() {
        // 如果窗口已存在，则将其带到前台
        if let existingWindow = preferencesWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // 创建新的偏好设置窗口
        let preferencesView = PreferencesWindowView(
            appSettings: appSettings,
            onClose: { [weak self] in
                self?.closePreferencesWindow()
            }
        )

        let hostingView = NSHostingView(rootView: preferencesView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "偏好设置"
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
        self.preferencesWindow = window

        // 显示窗口
        window.makeKeyAndOrderFront(nil)

        print("✅ 已显示偏好设置窗口")
    }

    /**
     * 关闭偏好设置窗口
     */
    private func closePreferencesWindow() {
        preferencesWindow?.close()
        preferencesWindow = nil
        print("✅ 已关闭偏好设置窗口")
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

            print("✅ 偏好设置窗口位置已调整到垂直居中")
        } else {
            print("✅ 偏好设置窗口已经在垂直居中位置")
        }
    }

    /**
     * 检查偏好设置窗口是否已显示
     * - Returns: 窗口是否正在显示
     */
    func isWindowVisible() -> Bool {
        return preferencesWindow?.isVisible ?? false
    }

    /**
     * 关闭偏好设置窗口（公共方法）
     * 可以被外部调用来强制关闭窗口
     */
    func closeWindow() {
        closePreferencesWindow()
    }
}