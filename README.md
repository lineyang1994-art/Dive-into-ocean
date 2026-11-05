# Dive into ocean

一款 iOS 海洋探索应用：浏览潜点和海洋生物图鉴，记录自己的潜水日志，收藏喜欢的潜点和物种。

An iOS app for exploring dive sites and marine life, keeping a dive log, and saving favorites.

## 功能与数据规模

以下数量于 2026-11-05 从仓库内 JSON 直接统计，不代表现场调查覆盖率：

| 内容 | 精选数据 `seed.json` | 导入数据 `extra.json` | 合计 |
| --- | ---: | ---: | ---: |
| 潜点 | 5 | 638 | 643 |
| 物种 | 22 | 401 | 423 |
| 潜点—物种关联 | 36 | 9,485 | 9,521 |
| 图片署名条目 | 28 | 401 | 429 |

- **探索**：潜点列表与地图、物种图鉴、7 条轮换精选发现。精选潜点为 Dauin、Apo Island、Moalboal、Anilao、Tulamben。
- 导入潜点分布：Indonesia 376、Philippines 112、Thailand 72、Malaysia 57、Papua New Guinea 11、Vietnam 6、Cambodia 4。
- 638 个导入潜点中，434 个有本点物种关联，204 个没有本点物种记录。后者展示同国家其他潜点观测汇总中的最多 12 种物种，明确标为 **「区域观测，非本点」**，不能据此认定该物种在本点出现，也不是本点常见度结论。
- 导入物种的详细介绍仍有「资料待补充」，并不等同于 22 种精选物种的完整资料。
- **日志**：记录潜水与见到的物种，初始为空，没有预置日志。
- **我的**：统计日志中记录的发现，收藏不计入发现。
- **认一认**：明确标注的演示模式，结果为模拟，不是真实识别。

## 数据来源、许可与隐私

- 潜点来源：© [OpenDiveMap](https://www.opendivemap.org/) contributors 与 © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors，ODbL。
- 物种观测来源：[GBIF](https://www.gbif.org/)。App 内来源说明声明只使用 CC0 或 CC BY 观测记录；当前压缩 JSON 没有逐条原始观测的来源 URL/许可字段，不能把这一说明视作逐条溯源审计已完成。
- 学名核对来源：[WoRMS](https://www.marinespecies.org/)，App 内标示 CC BY 4.0。
- 图片来自 Wikimedia Commons。**图片许可与观测数据许可不同**：捆绑署名包含 CC BY 2.0/2.5/3.0/4.0、CC BY-SA 2.0/3.0/4.0 与 Public domain。作者、每张图片的具体许可和来源链接保存在两个 JSON 的 `credits` 中，也可在 App「我的 → 图片来源」查看。不得将全部图片概括为 CC0/CC BY。
- 目录数据与照片都随 App 打包，运行时不从 GBIF、WoRMS 或图片站下载；没有账号、应用服务器或第三方统计服务。
- 日志、收藏与已见物种状态由 SwiftData 保存在本机。地图使用 Apple MapKit，底图加载可能需要网络，因此不保证地图完全离线可用。

## 技术与运行

- SwiftUI + SwiftData，iOS 26，Swift 6；中文优先，英文为辅。
- Bundle ID：`com.yanglisa.diveintoocean-d7c4`。
- 用 Xcode 打开 `DiveIntoOcean.xcodeproj`，选择已安装的 iOS 26 或更新模拟器，运行 `DiveIntoOcean` scheme。无需密钥或额外服务配置。

## 目录结构

- `DiveIntoOcean/Models/`：目录读取、关联查询和 SwiftData 模型。
- `DiveIntoOcean/Views/`：探索、潜点、物种、日志、认一认、我的等页面。
- `DiveIntoOcean/Resources/`：`seed.json`、`extra.json` 和打包图片。
- `DiveIntoOceanTests/`：当前只有 App 元数据检查；不覆盖导入数据、持久化或地图交互。

## 验证状态（2026-11-05）

### 本轮实际完成

- 静态解析两个 JSON，确认上述数量，643 个潜点 ID 与 423 个物种 ID 均无重复。
- 校验导入关联的 9,485 个物种引用及正数计数，638 行关联与潜点一一对应。
- 检查 429 个署名条目的本地 JPG 均存在。
- 阅读区域回退逻辑：204 个无本点记录的导入潜点可获得同国家汇总，徽标文案为「区域观测，非本点」。这是代码/数据检查，不是屏幕验证。

### 尚未完成 / 已知限制

- **模拟器验证被额度阻断**：所有设备关闭；启动及一次重试都返回 `The simulator quota for this billing period is exhausted and the credit balance is empty.` 已提交平台反馈。本轮没有构建、安装、交互成功或新截图证据，不能宣称地图速度或选择成功。
- 待验证完整持久化流程：将导入物种 Yellow-beaded Grapedragon / Doto ussi（`g6788065`）标为已见，在 Abwonderdive House Reef（`odm-57mg36`）创建并保存日志，退出重启后重新读取已见状态与日志。
- 待取得真实区域回退截图：Acca Spot（`odm-c6mboe`，Indonesia）没有本点关联，是数据支持的验证候选，应显示「区域观测，非本点」。
- 地图当前按视口筛选并在拥挤时网格抽稀，但筛选变化后保留旧视口，可能让有效结果不显示；初始只取前 60 个点；经度差未处理跨 ±180° 情况。这些问题尚未修复，也未实机验证。
- 物种资料仍待专业核对；相机拍照尚未在真机测试。
