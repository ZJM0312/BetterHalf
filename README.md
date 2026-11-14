# BetterHalf ♥ 两个人的小宇宙

> 情侣专属空间：记录在一起的每一天，告别“吃什么都行”，把想说的话好好说给 TA 听。
> **无需注册 · 30 秒开始 · 数据只属于你们。**

## 为什么做 BetterHalf？

市面上的情侣 App 普遍有三个让人劝退的问题：**强制双方注册绑定**、**广告和会员墙**、**私密数据存在别人的服务器上**。
而情侣真正每天遇到的痛点其实很小、很具体：

| 真实痛点 | BetterHalf 的解法 |
| --- | --- |
| 忘记纪念日 / TA 的生日，后果很严重 | 纪念日自动倒数，在一起天数 + 第 100/520/1314 天里程碑 |
| “今天吃什么？”“都行。”——每天的死循环 | 🎡 **帮我选** 转盘：吃什么 / 去哪玩 / 谁洗碗，转一下就决定 |
| 在一起久了没话聊，重要的话说不出口 | 💬 **每日一问**：两人各自作答、都答完才揭晓，连续打卡 🔥 |
| 美好的瞬间散落在聊天记录和相册里 | 📸 **回忆时间线** + “那年今天”自动回顾 |
| 想一起做的事总是“以后再说” | ✅ **情侣清单**：一起列、一起打卡，进度看得见 |
| 想晒恩爱但没有好看的图 | ✨ 一键生成“我们在一起第 N 天”分享海报（朋友圈 / 小红书尺寸） |
| 不想把隐私交给陌生公司 | 🔒 本地优先：数据只存在你的设备，可随时导出 / 导入备份 |

## 快速开始

```bash
cd frontend
npm install
npm run dev
```

打开 <http://localhost:3000>，填两个名字和在一起的日子即可使用。
手机浏览器打开后可“添加到主屏幕”，像 App 一样使用（已配置 PWA manifest）。

> 前端目前**无需后端即可独立运行**（数据存在浏览器 localStorage）。
> 换设备时在「设置 → 导出备份」，再在新设备「导入备份」。

### iOS App（原生 SwiftUI）

```bash
open ios/BetterHalf.xcodeproj
```

在 Xcode 里选择模拟器或真机，按 ⌘R 运行。要求 Xcode 26+，最低支持 iOS 17。

- 功能与网页版一致：在一起天数、纪念日倒数、回忆时间线、每日一问、帮我选转盘、情侣清单、分享海报（一键存相册 / 系统分享）
- **桌面 & 锁屏小组件**
  - 「我们的天数」：小 / 中尺寸 + 锁屏圆形 / 矩形 / 单行。长按小组件 →「编辑小组件」可选择显示 **在一起天数 / 下一个里程碑 / 任意一个纪念日倒数**
  - 「我们的宠物」：桌面上直接点 🍖 喂食、🤚 摸摸（交互式小组件），会饿、晚上会睡觉、互动后有反应气泡
- **回忆升级**：每条最多 9 个附件，支持照片（JPG / PNG / HEIC / GIF）、视频、语音录制；宫格展示，点开全屏左右滑动、双击 / 双指缩放、视频内嵌播放
- **宠物模块**：上传宠物照片 → 用 Vision 自动抠图成贴纸（iOS 17 主体识别），变成会呼吸、会跳、会转身、会撒娇的小宠物；饱腹 / 心情 / 亲密度随时间变化，升级有庆祝动画，饿了会推送提醒；可以设置性格、随时编辑
- **和宠物聊天**：不配置 AI 也能聊（内置离线「小脑袋」，会根据饥饿、心情、性格和你说的话回应）；配置 AI 后 TA 会按自己的性格和当下状态用 AI 回复
- **AI 自带密钥（BYOK）**：「设置 → AI 设置」或宠物页菜单。对话模型预设 DeepSeek / OpenAI / Claude / 通义千问 / Kimi / 智谱 / 自定义 OpenAI 兼容（含本地 Ollama）；生图模型预设 OpenAI 图像 / 硅基流动 / 自定义。API Key 存在本机钥匙串，不同步、不进备份；首次向某个服务商发数据前会弹窗征得同意。App 不内置任何 Key、不产生任何费用
- **今天卡片**：首页按时间问候，并汇总今天该做的事（今日一问、宠物状态、临近纪念日、多久没记录回忆），点一下直接跳过去
- **点对点同步（私有存储）**：两部手机靠近即可同步（MultipeerConnectivity，Wi-Fi / 蓝牙，强制加密），**不经过任何服务器、无需账号**；照片视频语音一起传；首次需要对方确认，之后自动识别另一半；连接时可以互发「想你了」爱心动画
- **面容 ID 锁**：开启后每次回到 App 需验证，App 切换器里自动遮挡内容
- **主动提醒**：纪念日前一天 20:00 + 当天 9:00、第 N 天里程碑、每晚 21:00 每日一问、3 天没记录回忆、宠物饿了；打开「回忆」时发现相册新照片会提示一键记录
- **备份互通**：iOS 与网页版使用同一份 JSON 格式（iOS 备份额外内嵌照片 / 视频 / 语音），同一天两端出同一道「每日一问」
- **数据位置**：App Group 共享容器 `group.com.betterhalf.hxiz1q`（小组件需要读取），旧版本数据会自动迁移

**真机运行**：在 Xcode → Signing & Capabilities 里给 `BetterHalf` 和 `BetterHalfWidgetExtension` 两个 target 都选上你的 Team，把 Bundle ID（当前为 `com.betterhalf.hxiz1q`）和 App Group（`group.com.betterhalf.hxiz1q`，在 `ios/Config/*.entitlements` 与 `ios/Shared/SharedContainer.swift`）保持全网唯一即可。宠物自动抠图需要真机（模拟器没有神经网络引擎，会退回圆形头像）。

> 命令行构建时如果项目在 iCloud 同步的「文稿」目录下，codesign 可能报 `resource fork, Finder information, or similar detritus not allowed`。
> 用 Xcode 直接运行，或给 `xcodebuild` 加上 `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/BetterHalf` 即可。

## 增长设计

- **零门槛**：不注册、不绑定，打开即用——先让用户爱上，再谈账号。
- **天然传播点**：分享海报自带 `BetterHalf` 水印；第 100 / 520 / 1000 / 1314 天是情侣主动晒图的高峰。
- **每日回访理由**：每日一问 + 连续打卡、纪念日倒数、那年今天。
- **两人协作**：每日一问必须两个人都答完才揭晓，自然把另一半拉进来。

## 上架

- 上架清单：[docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)
- 商店文案 / 关键词 / 审核备注 / 隐私申报：[docs/appstore/listing.md](docs/appstore/listing.md)
- 截图（1320 × 2868）：[docs/appstore/screenshots](docs/appstore/screenshots)
- 隐私政策与支持页（可直接用 GitHub Pages 托管 `docs/`）：[docs/privacy.html](docs/privacy.html)、[docs/support.html](docs/support.html)

## Roadmap

- [x] 两部手机点对点同步（iOS，面对面 / 同一网络）
- [ ] **异地实时同步**：接入现有 Spring Boot 后端（auth / couple / invites 模块），不在身边也能互通；可选端到端加密
- [ ] 纪念日提醒推送（Web Push / 小程序订阅消息）
- [x] iOS 原生 App（SwiftUI）
- [x] iOS 桌面 / 锁屏小组件（天数、纪念日、互动宠物）
- [x] 宠物 AI：自带密钥的 AI 对话 + AI 生成卡通形象
- [ ] 宠物 AI 进阶：根据照片图生图（image-to-image）、更多动作帧
- [ ] 灵动岛 / 实时活动：纪念日当天倒计时
- [ ] 微信小程序版本（国内情侣最主要的入口）
- [ ] 更多问题卡包（初识期 / 热恋期 / 异地恋 / 婚后）
- [ ] 年度回忆报告（“我们的 2026”），年底传播节点
- [ ] 照片上云（复用 `betterhalf-media` 的预签名上传）

## 项目结构

```
frontend/   Next.js 14 前端（当前产品主体，本地优先）
  src/app/page.tsx          应用壳 + 底部导航
  src/components/           我们 / 回忆 / 每日一问 / 帮我选 / 清单 / 设置
  src/lib/store.ts          本地数据存储（localStorage + useSyncExternalStore）
  src/lib/content.ts        每日问题、清单灵感、转盘预设
  src/lib/media.ts          图片压缩、分享海报生成
ios/        SwiftUI 原生 App（iOS 17+）
  Shared/                   App 与小组件共用：数据模型（与网页版同格式）、App Group 存储、日期计算、宠物逻辑与交互 Intent
  BetterHalf/Views/         各功能页面、分享海报
  BetterHalf/Media/         照片 / 视频 / 语音的选择、录制、缩略图与全屏查看
  BetterHalf/Pet/           宠物页面、编辑器、聊天、离线小脑袋、Vision 抠图
  BetterHalf/AI/            AI 设置（多服务商 + 钥匙串）、AI 请求客户端
  scripts/screenshots.sh    一键生成 App Store 截图（6.9 英寸）
  BetterHalf/Sync/          点对点同步（MultipeerConnectivity）
  BetterHalf/Support/       通知提醒、面容 ID 锁、新照片发现
  BetterHalfWidget/         桌面 / 锁屏小组件
  Config/                   Info.plist 补充项与 App Group entitlements
backend/    Spring Boot 模块化单体（为双人同步准备，详见下方）
```

## 后端架构（为同步与规模化准备）

- **Backend**: Spring Boot modular monolith (auth, couple, content, media, sharing, public, audit, moderation)
- **Database**: PostgreSQL + Flyway migrations, strict tenant isolation (`couple_id` everywhere)
- **Cache**: Redis (sessions, rate limiting)
- **Storage**: S3/R2 with signed URLs
- **Security**: cookie auth with refresh rotation, ABAC policy engine, CSRF, rate limiting

```bash
cd backend
./mvnw spring-boot:run
```

详见 [API_ENDPOINTS.md](API_ENDPOINTS.md)、[IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)、[QUICK_START.md](QUICK_START.md)。
