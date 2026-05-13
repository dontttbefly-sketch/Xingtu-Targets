# StarfieldGoals macOS

这是星图目标管理的原生 macOS 版本工程目录。它不是 Electron，也不是 WKWebView 套壳，而是 SwiftUI + SwiftPM 的原生 macOS App。

## 如何打开

用 Xcode 打开这个目录下的 `.xcodeproj`：

```sh
open macos/StarfieldGoals/StarfieldGoals.xcodeproj
```

选择 `StarfieldGoals` scheme 后按 `Cmd + R`，会运行真正的 macOS `.app` 窗口。

命令行验证：

```sh
cd macos/StarfieldGoals
xcodebuild -project StarfieldGoals.xcodeproj -scheme StarfieldGoals -configuration Debug build CODE_SIGNING_ALLOWED=NO
swift build
swift test
```

## 当前状态

- 已建立可构建、可用 Xcode 运行的原生 macOS SwiftUI App 工程。
- 已实现 `StarfieldGoalsCore`：模型、频率/统计规则、AppStore、本地 JSON 存储、last-good 恢复、Web 兼容备份导入导出、通知服务接口。
- 已实现基础原生 UI：全屏星图、HUD、恒星档案、routine 今日点亮、临时事项、复盘面板、数据舱、导入/导出备份、编辑表单。
- 已加入体验增强：今日点亮进度 HUD、航行日志、复盘轻提示、原生菜单命令、删除确认、21:00 通知调度、完成状态影响星图亮度和轨道光。
- 当前主存储位置：`Application Support/StarfieldGoals/starfield-goals.json`。
- Web 版继续保留在仓库 `web/`，可从 Web 数据舱导出 JSON 后导入 macOS 数据舱。

## Directory Layout

- `StarfieldGoals.xcodeproj`：正式 macOS App 工程入口，用它运行窗口。
- `Package.swift`：SwiftPM 测试/命令行验证入口。
- `StarfieldGoals/`：macOS App 目标，包含 SwiftUI App 入口和界面。
- `StarfieldGoalsCore/`：可测试业务核心，包含模型、规则、存储、备份、通知接口。
- `StarfieldGoalsTests/`：模型、统计、存储、备份解析测试。

## 产品原则

macOS 版会继续遵循“整个软件就是星图”的方向：恒星是目标，行星是 routine，复盘和数据舱是悬浮 HUD。v1 先保证长期使用的核心闭环，后续再继续加强 2.5D 镜头、视差和更细腻的聚焦动画。
