# 星图目标管理 macOS 原生版工程方案

## Summary

目标是做一个不套壳的原生 macOS App：使用 SwiftUI 重建星图目标管理体验，不使用 Electron，也不把现有 Web 页面塞进 WKWebView。当前 Web 版保留在 `web/` 作为可用版本、产品原型和数据迁移来源；macOS 版从 `macos/StarfieldGoals/` 独立演进。

第一版优先保证长期可用：本地数据稳定、目标/routine/check-in 流程完整、星图体验清晰。视觉可以先做到“原生 2D 星图 + 侧栏详情”，后续再逐步追平 Web 版的 2.5D 动效。

## Architecture

- **App 技术栈**：SwiftUI macOS App，最低系统版本建议 macOS 14；数据先用本地 JSON 文件，位置放在 App Sandbox 的 Application Support。
- **数据模型**：复刻 Web 版核心结构：`Goal`、`Routine`、`OneOffTask`、`CheckIn`、`AppState`。字段名称尽量与 Web 备份一致，方便导入。
- **状态管理**：使用 `ObservableObject` / `@Observable` 的 `AppStore`，统一承载增删改、今日点亮、复盘、统计和导入导出。
- **存储服务**：`StorageService` 负责读写 `starfield-goals.json`，保存时写临时文件后原子替换，并维护 `last-good` 备份。
- **星图渲染**：SwiftUI `Canvas` 或轻量视图组合绘制恒星、轨道、行星和标签；点击恒星打开右侧详情，点击 routine 标签打开快捷信息。
- **迁移方案**：Web 版通过“数据舱 -> 导出备份”，macOS 版通过“导入备份”读取同一 JSON 备份格式。

## v1 Feature Set

- 创建、编辑、删除目标；设置开始日和可选期限；手动标记完成。
- 在目标下创建、编辑、删除 routine；支持 daily 和 weeklyCount。
- 今日点亮/取消点亮 routine；保留近 7 天补记复盘。
- 临时事项创建、完成、删除。
- 首页星图展示活跃/完成目标、routine 轨道和核心统计。
- 恒星详情侧栏展示目标统计、routine 列表、临时事项和完成操作。
- 数据舱支持本地保存状态、导入 Web 备份、导出 macOS 备份。

## Suggested File Boundaries

- `StarfieldGoals/App/StarfieldGoalsApp.swift`：App 入口、主窗口、依赖注入。
- `StarfieldGoals/Models/AppState.swift`：全部 Codable 数据模型。
- `StarfieldGoals/Services/AppStore.swift`：业务 action、统计计算、状态发布。
- `StarfieldGoals/Services/StorageService.swift`：JSON 读写、last-good 恢复、备份导入导出。
- `StarfieldGoals/Services/NotificationService.swift`：21:00 复盘通知，v1 可先留接口。
- `StarfieldGoals/Views/StarMapView.swift`：星图主界面和点击命中。
- `StarfieldGoals/Views/GoalDetailView.swift`：恒星档案详情。
- `StarfieldGoals/Views/DataVaultView.swift`：备份、恢复、本地保存状态。

## Milestones

1. **工程初始化**：已完成。当前使用 SwiftPM 工程，可直接用 Xcode 打开 `Package.swift`。
2. **数据核心**：已完成第一版。Codable 模型、AppStore、StorageService、BackupService、DomainLogic 已有单元测试覆盖。
3. **基础 UI**：已完成第一版。目标、routine、今日点亮、临时事项、复盘、统计和数据舱已接入 SwiftUI。
4. **星图 UI**：已完成第一版。已有全屏星图、恒星点击聚焦、行星轨道、公转、拖拽和平移缩放控件。
5. **备份迁移**：已完成第一版。支持 Web 兼容备份导入和 macOS 备份导出，存储层支持 last-good 恢复。
6. **原生增强**：部分完成。已补菜单命令、快捷键、21:00 通知调度、航行日志、今日复盘提示和删除确认；下一步继续做 App 图标、签名打包，以及更细腻的 2.5D 聚焦镜头。

## Test Plan

- 模型测试：频率计算、每周 N 次逻辑、补记 7 天限制、目标统计。
- 存储测试：首次启动、正常保存、JSON 损坏恢复、last-good 恢复、备份导入导出。
- UI 测试：创建目标 -> 添加 routine -> 今日点亮 -> 刷新后统计保留。
- 迁移测试：导入 Web 版 `starfield-goals` 备份后，目标/routine/check-in 完整出现。

## Assumptions

- macOS 原生版不复用 React 代码，只复用产品规则、数据结构和备份格式。
- v1 不做云同步、不做账号、不做跨设备共享。
- Web 版继续作为稳定可用版本保留，直到 macOS 版核心流程成熟。
- 当前 `ios/` 目录不纳入这次重构，避免影响已有实验工程。
