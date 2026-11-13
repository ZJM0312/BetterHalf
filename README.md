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

- 功能与网页版一致：在一起天数、纪念日倒数、回忆时间线（相册选图）、每日一问、帮我选转盘、情侣清单、分享海报（一键存相册 / 系统分享）
- **iOS 独有**：本地通知提醒（纪念日前一天 20:00 + 当天 9:00、第 N 天里程碑、每晚 21:00 每日一问），触感反馈，深色模式
- **备份互通**：iOS 与网页版使用同一份 JSON 格式，同一天也会出现同一道“每日一问”
- 数据保存在 App 沙盒 `Documents/betterhalf.json`，开启了文件加密保护（`completeFileProtection`）
- 真机运行：在 Xcode → Signing & Capabilities 里选择你的 Team，并把 Bundle ID `com.betterhalf.app` 改成你自己的

> 命令行构建时如果项目在 iCloud 同步的「文稿」目录下，codesign 可能报 `resource fork, Finder information, or similar detritus not allowed`。
> 用 Xcode 直接运行，或给 `xcodebuild` 加上 `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/BetterHalf` 即可。

## 增长设计

- **零门槛**：不注册、不绑定，打开即用——先让用户爱上，再谈账号。
- **天然传播点**：分享海报自带 `BetterHalf` 水印；第 100 / 520 / 1000 / 1314 天是情侣主动晒图的高峰。
- **每日回访理由**：每日一问 + 连续打卡、纪念日倒数、那年今天。
- **两人协作**：每日一问必须两个人都答完才揭晓，自然把另一半拉进来。

## Roadmap

- [ ] **双人实时同步**：接入现有 Spring Boot 后端（auth / couple / invites 模块），邀请码配对，两台手机数据互通
- [ ] 纪念日提醒推送（Web Push / 小程序订阅消息）
- [x] iOS 原生 App（SwiftUI）
- [ ] iOS 桌面小组件：“在一起第 N 天” + 下一个纪念日倒数
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
  BetterHalf/Model/         数据模型（与网页版同格式）、存储、日期计算、问题库
  BetterHalf/Views/         各功能页面、分享海报
  BetterHalf/Support/       主题样式、本地通知提醒
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
