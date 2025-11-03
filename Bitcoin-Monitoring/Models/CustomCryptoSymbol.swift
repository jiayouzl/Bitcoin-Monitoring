//
//  CustomCryptoSymbol.swift
//  Bitcoin Monitoring
//
//  Created by Claude on 2025/11/03.
//

import Foundation

/// 自定义加密货币数据模型
/// 支持用户定义的3-5字符币种符号，使用统一的BTC图标
struct CustomCryptoSymbol: Codable, Equatable, Hashable {
    /// 币种符号（如 ADA、DOGE、SHIB）
    let symbol: String

    /// 创建自定义币种实例
    /// - Parameter symbol: 币种符号，3-5个大写字母
    init(symbol: String) throws {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 验证币种符号格式
        try CustomCryptoSymbol.validateSymbol(trimmedSymbol)

        self.symbol = trimmedSymbol
    }

    /// 从字符串创建自定义币种（可能失败）
    /// - Parameter rawValue: 原始字符串
    /// - Returns: 自定义币种实例，如果格式无效则返回nil
    static func fromString(_ rawValue: String) -> CustomCryptoSymbol? {
        do {
            return try CustomCryptoSymbol(symbol: rawValue)
        } catch {
            return nil
        }
    }

    /// 验证币种符号格式
    /// - Parameter symbol: 待验证的币种符号
    /// - Throws: ValidationError 如果格式不符合要求
    private static func validateSymbol(_ symbol: String) throws {
        // 验证长度：3-5个字符
        guard symbol.count >= 3, symbol.count <= 5 else {
            throw ValidationError.invalidLength
        }

        // 验证格式：只包含大写字母
        guard symbol.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
            throw ValidationError.invalidFormat
        }

        // 验证不与默认币种重复
        let defaultSymbols = CryptoSymbol.allCases.map { $0.displayName.uppercased() }
        guard !defaultSymbols.contains(symbol) else {
            throw ValidationError.duplicateWithDefault
        }
    }

    /// 验证币种符号的有效性（不创建实例）
    /// - Parameter symbol: 待验证的币种符号
    /// - Returns: 验证结果和错误信息
    static func isValidSymbol(_ symbol: String) -> (isValid: Bool, errorMessage: String?) {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查长度
        guard trimmedSymbol.count >= 3, trimmedSymbol.count <= 5 else {
            return (false, "币种符号需要3-5个大写字母")
        }

        // 检查格式
        guard trimmedSymbol.allSatisfy({ $0.isLetter }) else {
            return (false, "币种符号只能包含字母")
        }

        // 转换为大写进行验证
        let uppercasedSymbol = trimmedSymbol.uppercased()

        // 检查是否与默认币种重复
        let defaultSymbols = CryptoSymbol.allCases.map { $0.displayName.uppercased() }
        if defaultSymbols.contains(uppercasedSymbol) {
            return (false, "该币种已在默认列表中")
        }

        return (true, nil)
    }

    /// 自定义币种验证错误类型
    enum ValidationError: Error, LocalizedError {
        case invalidLength
        case invalidFormat
        case duplicateWithDefault

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "币种符号需要3-5个大写字母"
            case .invalidFormat:
                return "币种符号只能包含大写字母"
            case .duplicateWithDefault:
                return "该币种已在默认列表中"
            }
        }
    }
}

// MARK: - Display Properties

extension CustomCryptoSymbol {
    /// 用于展示的币种简称
    var displayName: String {
        return symbol
    }

    /// 币安API使用的交易对符号
    var apiSymbol: String {
        return "\(symbol)USDT"
    }

    /// 菜单中展示的交易对名称
    var pairDisplayName: String {
        return "\(symbol)/USDT"
    }

    /// 对应的SF Symbols图标名称（统一使用BTC图标）
    var systemImageName: String {
        return "bitcoinsign.circle.fill"
    }

    /// 菜单标题（带勾选标记和自定义标识）
    /// - Parameter isCurrent: 是否为当前选中币种
    /// - Returns: 菜单展示文本
    func menuTitle(isCurrent: Bool) -> String {
        let checkmark = isCurrent ? "✓" : "  "
        return "\(checkmark) \(pairDisplayName) (自定义)"
    }

    /// 判断是否为当前选中的币种
    /// - Parameter currentSymbol: 当前选中的币种字符串
    /// - Returns: 是否为当前选中币种
    func isCurrentSymbol(_ currentSymbol: String) -> Bool {
        return apiSymbol == currentSymbol || symbol.uppercased() == currentSymbol.uppercased()
    }
}

// MARK: - Equatable and Hashable Implementation

extension CustomCryptoSymbol {
    /// 相等性比较（基于币种符号）
    static func == (lhs: CustomCryptoSymbol, rhs: CustomCryptoSymbol) -> Bool {
        return lhs.symbol.uppercased() == rhs.symbol.uppercased()
    }

    /// 哈希值计算（基于币种符号）
    func hash(into hasher: inout Hasher) {
        hasher.combine(symbol.uppercased())
    }
}

// MARK: - CryptoRepresentable Protocol

/// 加密货币可表示协议
/// 统一CryptoSymbol和CustomCryptoSymbol的接口
protocol CryptoRepresentable {
    var displayName: String { get }
    var apiSymbol: String { get }
    var pairDisplayName: String { get }
    var systemImageName: String { get }

    func menuTitle(isCurrent: Bool) -> String
}

// MARK: - CryptoSymbol Protocol Conformance

extension CryptoSymbol: CryptoRepresentable {}

extension CustomCryptoSymbol: CryptoRepresentable {}

// MARK: - Type Identification

extension CryptoRepresentable {
    /// 是否为默认币种
    var isDefaultCrypto: Bool {
        return self is CryptoSymbol
    }

    /// 是否为自定义币种
    var isCustomCrypto: Bool {
        return self is CustomCryptoSymbol
    }
}