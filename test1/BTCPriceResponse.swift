//
//  BTCPriceResponse.swift
//  test1
//
//  Created by Mark on 2025/10/28.
//

import Foundation

// BTC价格响应数据模型
struct BTCPriceResponse: Codable {
    let symbol: String
    let price: String
}
