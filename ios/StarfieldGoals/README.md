# StarfieldGoals iOS

SwiftUI 原生 iPhone 首版，使用 SwiftData + CloudKit 私有数据库同步 App 自有数据。

## Local Core Verification

当前仓库内的纯 Swift 规则层可以通过 SwiftPM runner 验证：

```bash
cd ios/StarfieldGoals
swift run StarfieldGoalsCoreChecks
```

覆盖行为：

- 日期区间、7 天补打窗口
- 每日/每周 routine 展示和周目标限制
- 目标统计、完成率、剩余天数
- Web PWA `AppState version: 1` JSON 导入/导出

## Xcode Setup

1. 用 Xcode 打开 `ios/StarfieldGoals/StarfieldGoals.xcodeproj`。
2. 在 target `StarfieldGoals` 的 Signing & Capabilities 中设置 Apple Developer Team。
3. 确认 Bundle Identifier 为 `com.bottom.starfieldgoals`，或改成账号下可用的标识。
4. 在 Apple Developer 后台创建并启用 iCloud container：`iCloud.com.bottom.starfieldgoals`。
5. 确认 capabilities：
   - iCloud / CloudKit
   - Background Modes / Remote notifications
   - Push Notifications
6. 为 `Assets.xcassets/AppIcon.appiconset` 补齐真实 1024x1024 App Icon 后再归档。

## TestFlight Checklist

- 同一 Apple ID 两台设备：创建目标、添加 routine、打卡，等待 CloudKit 同步后另一台可见。
- 离线修改后联网：修改不丢失，并在联网后同步。
- 未登录 iCloud：App 可本地使用，并显示“本机可用，登录 iCloud 后同步”。
- Web JSON 迁移：导入当前 PWA 的 `localStorage` JSON 后，目标、routine、任务、打卡、提醒日期都保留。
- 通知：授权后每天 21:00 产生“今晚复盘”本地通知，点击后进入 App 并切换到复盘页。
