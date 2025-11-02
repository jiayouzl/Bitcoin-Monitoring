//
//  BitcoinMonitoringApp.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/28.
//

import SwiftUI
import AppKit

@main
struct BitcoinMonitoringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarApp: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置应用为后台应用（不显示在Dock中）
        NSApp.setActivationPolicy(.accessory)

        // 隐藏默认窗口（如果存在）
        if let window = NSApp.windows.first {
            window.setIsVisible(false)
        }

        // 创建菜单栏应用
        menuBarApp = MenuBarManager()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 清理资源
        menuBarApp = nil
        return .terminateNow
    }
}
