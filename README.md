# Dive into ocean

一款 iOS 海洋探索应用：浏览潜点和海洋生物图鉴，记录自己的潜水日志，收藏喜欢的潜点和物种。

An iOS app for exploring dive sites and marine life, keeping a dive log, and saving favorites.

## 功能

- **探索**：5 个潜点（Dauin、Apo Island、Moalboal、Anilao、Tulamben）、22 种海洋生物，支持列表和地图查看，每日一条精选发现。
- **日志**：记录潜水，标记见到的物种。日志初始为空，没有预置数据。
- **我的**：只统计日志里真正记录过的「发现」，收藏不计入。
- **认一认**：演示模式。识别结果是模拟的，不是真实识别，界面上有明确标注。

## 数据与隐私

- 纯本地：没有账号、没有服务器、没有第三方统计。
- 物种和潜点资料、照片都打包在 App 里（`DiveIntoOcean/Resources/seed.json` 和 `Resources/Images/`），运行时不联网下载。
- 日志、收藏用 SwiftData 存在本机。
- 地图使用苹果自带地图。
- 照片来自 Wikimedia Commons，署名和许可见 App 内「设置 → 图片来源」。

## 技术

- SwiftUI + SwiftData，iOS 26，Swift 6
- 中文优先，英文为辅
- Bundle ID：`com.yanglisa.diveintoocean-d7c4`

## 状态

- 物种资料尚待专业人士核对。
- 相机拍照尚未在真机上测试。
