//
//  BTCPriceResponse.swift
//  Bitcoin Monitoring
//
//  Created by Mark on 2025/10/28.
//

import Foundation

// 币安Ticker价格响应数据模型
struct TickerPriceResponse: Codable {
    let symbol: String
    let price: String
}
