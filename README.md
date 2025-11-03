# BTC 价格监控器

<div align="center">

[![BTC Icon](https://img.shields.io/badge/BTC-Bitcoin-orange&logo=bitcoin&logoColor=white)](#)
[![platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)](#)
[![macOS](https://img.shields.io/badge/macOS-13.1+-blue&logo=apple)](#)
[![xcode](https://img.shields.io/badge/Xcode-16.2%2B-1575F9?logo=xcode&logoColor=white)](#)
[![swift](https://img.shields.io/badge/Swift-5.7%2B-FA7343?logo=swift&logoColor=white)](#)
[![ui](https://img.shields.io/badge/SwiftUI-%2B%20AppKit-43a047)](#)
[![license](https://img.shields.io/badge/License-GPL%20v3-44CC11)](#license)

</div>

一款 macOS 原生菜单栏应用，用于实时监控主流加密货币的价格，支持 BTC/ETH/BNB/SOL/DOGE 多种币种。基于 Swift 编写，致力于打造一款高性能、极简风格的应用APP，已经编译了`Intel`与`Apple Silicon`的通用应用，请至[releases](https://github.com/jiayouzl/Bitcoin-Monitoring/releases/latest)下载。

## 📖 如在macOS下无法运行，请执行以下步骤：
> 系统设置 → 隐私与安全性 → 安全性 → 已阻止“Bitcoin Monitoring.app”以保护Mac → 仍要打开

## 📷︎ 界面预览

![](./assets/iShot_2025-11-04_00.30.31.png)

## ✨ 功能特性

### 🚀 核心功能
- **多币种支持**: 支持 BTC/ETH/BNB/SOL/DOGE 主流虚拟货币价格监控
- **实时价格显示**: 在菜单栏实时显示选中币种的 USDT 价格
- **多种刷新机制**: 可选 5、10、30、60 秒自动获取最新价格数据
- **智能错误重试**: 网络异常时自动重试，最多 3 次
- **手动刷新**: 支持快捷键 `Cmd+R` 手动刷新价格
- **状态指示**: 直观显示加载、更新、错误状态
- **价格复制功能**: 支持一键复制当前价格到剪贴板
- **配置持久化**: 用户设置自动保存，重启后保持配置
- **开机自启动**: 可选是否开机自动启动APP

### 🎨 用户体验
- **中文界面**: 完整的中文用户界面
- **优雅动画**: 流畅的状态切换动画
- **轻量级设计**: 最小化系统资源占用
- **后台运行**: 不占用 Dock 空间，专注菜单栏
- **SF Symbols 图标**: 使用原生 macOS 图标系统
- **现代化偏好设置**: 采用 macOS 原生风格的偏好设置界面
- **精美开关控件**: 使用 macOS 系统风格的椭圆形 Switch 控件
- **响应式布局**: 智能适配不同窗口尺寸和显示设置

### 🛡️ 可靠性
- **网络容错**: 完善的网络异常处理机制
- **内存管理**: 避免循环引用，及时释放资源
- **线程安全**: UI 更新确保在主线程执行
- **错误恢复**: 自动从临时网络故障中恢复

## 📋 安装要求

### 系统要求
- **操作系统**: macOS 13.1 或更高版本
- **架构支持**: Intel 和 Apple Silicon (M1/M2/M3/M4/M5)

### 开发环境
- **开发工具**: Xcode 16.2 或更高版本
- **Swift 版本**: Swift 5.0
- **部署目标**: macOS 13.1

### 网络要求
- 需要稳定的互联网连接
- 访问币安 API (`https://api.binance.com`) 的网络权限

## 🚀 快速开始

### 直接运行

1. **克隆项目**
   ```bash
   git clone https://github.com/jiayouzl/Bitcoin-Monitoring.git
   cd Bitcoin-Monitoring
   ```

2. **在 Xcode 中打开**
   ```bash
   open "Bitcoin Monitoring.xcodeproj"
   ```

3. **运行应用**
   - 在 Xcode 中选择 "Bitcoin Monitoring" scheme
   - 点击运行按钮或使用快捷键： `Cmd+R`

### 构建命令

```bash
# 构建项目
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Debug build

# 归档应用
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Release archive

# 清理构建缓存
xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" clean
```

## 🏗️ 技术架构

### 设计模式

- **MVVM 架构**: SwiftUI + ObservableObject 模式
- **Combine 框架**: 响应式数据流和事件处理
- **依赖注入**: 服务层分离和松耦合设计
- **观察者模式**: 价格变化的响应式更新
- **策略模式**: 可配置的刷新间隔选项

### UI 组件架构

- **现代化界面设计**: 采用 macOS 原生设计语言
- **Switch 控件**: 使用 `.toggleStyle(.switch)` 和 `.controlSize(.mini)` 实现精美开关
- **响应式布局**: HStack + VStack 实现灵活的界面布局
- **分组视图**: 自定义 `SettingsGroupView` 组件实现功能分组
- **配置管理**: `AppSettings` 类统一管理用户偏好设置

### 并发处理

```swift
// 主线程 UI 更新
@MainActor
class BTCMenuBarApp: ObservableObject

// 异步网络请求
func fetchPrice() async throws -> Double

// Combine 响应式流
priceManager.$currentPrice
    .receive(on: DispatchQueue.main)
    .sink { [weak self] price in
        self?.updateMenuBarTitle(price: price)
    }
```

## 🔧 故障排除

### 常见问题

#### 1. 应用无法启动

**问题**: 双击应用图标无反应
**解决方案**:
```bash
# 检查系统完整性
xattr -d com.apple.quarantine "/Applications/Bitcoin Monitoring.app"

# 或者在系统偏好设置中允许应用运行
# 系统偏好设置 → 安全性与隐私 → 通用
```

#### 2. 网络连接失败

**问题**: 显示"错误"状态，无法获取价格
**诊断步骤**:

1. 检查网络连接
```bash
ping api.binance.com
```

2. 验证 API 可用性
```bash
# 测试同币种 API 的可用性
curl "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
```

3. 检查防火墙设置
```bash
# 确保允许出站 HTTPS 连接
```

## 🤝 贡献指南

我们欢迎所有形式的贡献！请阅读以下指南：

### 贡献方式

1. **报告 Bug**: 在 Issues 中提交详细的 Bug 报告
2. **功能建议**: 提出新功能的想法和建议
3. **代码贡献**: 提交 Pull Request 改进代码
4. **文档完善**: 改进 README 和代码注释

## 📄 许可证

本项目采用 **GNU General Public License v3.0** 许可证。

### 完整许可证文本

详见 [LICENSE](LICENSE) 文件。

## 👨‍💻 作者

**Mark**

- **GitHub**: [@jiayouzl](https://github.com/jiayouzl/)
- **项目主页**: [https://github.com/jiayouzl/Bitcoin-Monitoring](https://github.com/jiayouzl/Bitcoin-Monitoring)

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=jiayouzl/Bitcoin-Monitoring&type=date&legend=top-left)](https://www.star-history.com/#jiayouzl/Bitcoin-Monitoring&type=date&legend=top-left)

---
