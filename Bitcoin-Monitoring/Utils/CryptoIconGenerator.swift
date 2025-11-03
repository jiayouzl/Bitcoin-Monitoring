//
//  CryptoIconGenerator.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/11/03.
//

import SwiftUI
import AppKit

/**
 * 加密货币图标生成器
 * 为自定义币种生成基于首字母的彩色图标
 */
class CryptoIconGenerator {

    /// 图标缓存，避免重复生成相同币种的图标
    private static var iconCache: [String: NSImage] = [:]

    /// 预定义的颜色数组，用于生成不同币种的背景色
    private static let backgroundColors: [NSColor] = [
        NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),  // 蓝色
        NSColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0),  // 红色
        NSColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0),  // 绿色
        NSColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0),  // 橙色
        NSColor(red: 0.7, green: 0.3, blue: 0.7, alpha: 1.0),  // 紫色
        NSColor(red: 0.2, green: 0.7, blue: 0.8, alpha: 1.0),  // 青色
        NSColor(red: 0.9, green: 0.4, blue: 0.6, alpha: 1.0),  // 粉色
        NSColor(red: 0.6, green: 0.6, blue: 0.2, alpha: 1.0),  // 黄色
        NSColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1.0),  // 薄荷绿
        NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0),  // 棕色
    ]

    /**
     * 为自定义币种生成基于首字母的图标
     * - Parameter symbol: 币种符号（如 BTC、ETH、ADA）
     * - Returns: 生成的NSImage图标
     */
    static func generateIcon(for symbol: String) -> NSImage {
        // 检查缓存
        if let cachedIcon = iconCache[symbol] {
            return cachedIcon
        }

        // 生成新图标
        let icon = createLetterIcon(symbol: symbol)

        // 缓存图标
        iconCache[symbol] = icon

        return icon
    }

    /**
     * 创建基于首字母的图标
     * - Parameter symbol: 币种符号
     * - Returns: 生成的NSImage图标
     */
    private static func createLetterIcon(symbol: String) -> NSImage {
        let size = NSSize(width: 64, height: 64) // 使用较大的尺寸生成，保证清晰度

        let image = NSImage(size: size)
        image.lockFocus()

        // 创建圆形背景
        let rect = NSRect(origin: .zero, size: size)
        let circlePath = NSBezierPath(ovalIn: rect)

        // 选择背景色
        let backgroundColor = selectBackgroundColor(for: symbol)
        backgroundColor.setFill()
        circlePath.fill()

        // 绘制首字母
        let firstLetter = String(symbol.prefix(1)).uppercased()
        let attributedString = NSAttributedString(
            string: firstLetter,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 28),
                .foregroundColor: NSColor.white
            ]
        )

        // 计算文字位置，使其居中
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)

        image.unlockFocus()

        // 设置图像属性，确保正确显示
        image.isTemplate = false

        return image
    }

    /**
     * 根据币种符号选择背景色
     * 使用哈希算法确保相同币种总是得到相同的颜色
     * - Parameter symbol: 币种符号
     * - Returns: 背景色
     */
    private static func selectBackgroundColor(for symbol: String) -> NSColor {
        // 使用简单的哈希算法
        var hash = 0
        for char in symbol {
            hash = hash * 31 + Int(char.unicodeScalars.first!.value)
        }

        // 取绝对值并使用颜色数组长度取模
        let colorIndex = abs(hash) % backgroundColors.count
        return backgroundColors[colorIndex]
    }

    /**
     * 生成系统符号样式的图标（兼容SF Symbols）
     * - Parameter symbol: 币种符号
     * - Returns: SF Symbols兼容的NSImage
     */
    static func generateSystemIcon(for symbol: String) -> NSImage {
        let icon = generateIcon(for: symbol)

        // 调整大小为标准SF Symbols尺寸
        let standardSize = NSSize(width: 16, height: 16)
        let resizedIcon = resizeImage(icon, to: standardSize)

        return resizedIcon
    }

    /**
     * 调整图像尺寸
     * - Parameters:
     *   - image: 原始图像
     *   - size: 目标尺寸
     * - Returns: 调整尺寸后的图像
     */
    private static func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()

        let drawingRect = NSRect(origin: .zero, size: size)
        image.draw(in: drawingRect)

        resizedImage.unlockFocus()
        resizedImage.isTemplate = false

        return resizedImage
    }

    /**
     * 清空图标缓存（用于测试或重置）
     */
    static func clearCache() {
        iconCache.removeAll()
    }

    /**
     * 获取缓存中的图标数量
     * - Returns: 缓存的图标数量
     */
    static func cacheCount() -> Int {
        return iconCache.count
    }
}

// MARK: - SwiftUI 兼容扩展

extension CryptoIconGenerator {

    /**
     * 为SwiftUI生成Image
     * - Parameter symbol: 币种符号
     * - Returns: SwiftUI Image
     */
    static func generateSwiftUIImage(for symbol: String) -> Image {
        let nsImage = generateSystemIcon(for: symbol)
        return Image(nsImage: nsImage)
    }
}