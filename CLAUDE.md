# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个专业的 macOS 菜单栏应用，用于实时监控 BTC 价格。应用使用 SwiftUI + AppKit 混合架构，每30秒自动从币安API获取最新价格数据。

### 核心功能
- 实时显示 BTC/USDT 价格
- 30秒自动刷新机制
- 智能错误重试（最多3次）
- 手动刷新支持（Cmd+R）
- 优雅的 SF Symbols 图标系统
- 完整的中文界面

## 开发环境

### 技术栈
- **语言**: Swift 5.0
- **框架**: SwiftUI + AppKit
- **最低系统版本**: macOS 12.4
- **部署目标**: macOS 14.8
- **开发工具**: Xcode 16.2

### 构建命令
```bash
# 构建项目
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Debug build

# 归档应用
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Release archive

# 清理构建缓存
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" clean
```

### 运行方式
```bash
# 在Xcode中运行
# 1. 打开 Bitcoin Monitoring.xcodeproj
# 2. 选择 "Bitcoin Monitoring" scheme
# 3. 点击运行按钮或使用 Cmd+R

# 命令行运行（构建后）
open "build/Release/Bitcoin Monitoring.app"
```

## 架构设计

### 组件架构
```
test1App.swift (App入口)
├── AppDelegate (应用生命周期管理)
└── BTCMenuBarApp (菜单栏核心逻辑)
    ├── PriceManager (价格数据管理)
    │   └── PriceService (网络请求服务)
    └── BTCPriceResponse (数据模型)
```

### 核心类说明

**BTCMenuBarApp**:
- 菜单栏应用主控制器
- 负责UI状态管理和用户交互
- 处理菜单显示、图标更新

**PriceManager**:
- 价格数据管理器（@MainActor）
- 定时刷新机制（30秒间隔）
- 智能重试策略（最多3次，递增延迟）
- Combine 发布者模式

**PriceService**:
- 网络请求服务层
- 币安API集成
- 完整错误处理机制

**BTCPriceResponse**:
- API响应数据模型
- Codable 协议支持

### 设计模式
- **MVVM架构**: SwiftUI + ObservableObject
- **Combine框架**: 响应式数据流
- **依赖注入**: 服务层分离
- **错误处理**: 自定义错误类型 + LocalizedError

## API集成

### 币安API端点
```
GET https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT
```

### 响应格式
```json
{
  "symbol": "BTCUSDT",
  "price": "43250.50"
}
```

### 错误处理
- 网络连接失败
- API服务器错误
- 数据解析异常
- 无效价格格式

## 开发指南

### 添加新功能
1. **UI组件**: 在 BTCMenuBarApp 中添加菜单项
2. **数据服务**: 扩展 PriceService 类
3. **数据模型**: 创建新的 Codable 结构体
4. **状态管理**: 在 PriceManager 中添加 @Published 属性

### 调试技巧
- 查看控制台输出获取详细错误信息
- 使用 Xcode 调试器观察网络请求
- 检查菜单栏状态确认应用运行状态

### 代码规范
- 所有类和方法都有详细的中文注释
- 遵循 Swift 命名约定
- 使用 @MainActor 确保UI线程安全
- 弱引用避免循环引用

## 项目配置

### Bundle信息
- **Bundle Identifier**: com.mark.test1
- **版本**: 1.0.0 (Marketing Version)
- **Build**: 1 (Current Project Version)
- **应用分类**: public.app-category.finance

### 权限配置
- 网络访问权限（API调用）
- 自动代码签名
- 沙盒模式启用

## 测试建议

### 手动测试场景
1. **正常流程**: 启动应用，观察价格更新
2. **网络异常**: 断网测试重试机制
3. **API错误**: 模拟服务器错误响应
4. **用户交互**: 测试菜单项点击功能
5. **内存管理**: 长时间运行检查内存泄漏

### 性能优化
- 定时器使用 weak self 避免循环引用
- 网络请求异步处理
- UI更新在主线程执行
- 及时释放 Timer 资源