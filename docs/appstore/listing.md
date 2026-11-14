# App Store 上架资料（可直接复制到 App Store Connect）

> 带 ⚠️ 的地方需要你确认或替换。

## 基本信息

| 字段 | 内容 |
|---|---|
| App 名称（30 字内） | ⚠️ 首选「BetterHalf - 情侣纪念日」；被占用可用「BetterHalf 两个人的小宇宙」「BetterHalf 情侣空间」 |
| 副标题（30 字内） | 纪念日倒数·回忆·情侣宠物 |
| 主要类别 | 生活（Lifestyle） |
| 次要类别 | 社交（Social Networking） |
| 价格 | 免费 |
| 年龄分级 | 4+（问卷全部选「无」；不含 UGC 公开分享、无网页浏览）。⚠️ 如果审核认为 AI 聊天属于「不受限制的网页内容/UGC」，改选 12+ |
| 版权 | ⚠️ 2026 你的名字 |
| 隐私政策网址 | ⚠️ https://你的GitHub用户名.github.io/BetterHalf/privacy.html （见下方「托管网页」） |
| 支持网址 | ⚠️ https://你的GitHub用户名.github.io/BetterHalf/support.html |

## 推广文本（170 字内，可随时修改，不需审核）

把在一起的每一天都好好收藏。纪念日自动倒数、回忆时间线、每日一问，还有一只会撒娇的情侣宠物陪你们——不用注册，数据只属于你们俩。

## 描述（4000 字内）

BetterHalf 是只属于你们两个人的小宇宙。

不用注册账号，不上传任何服务器，打开就能用。你们的回忆，只存在你们自己的手机里。

【在一起的每一天】
· 我们在一起第 N 天，第 100 / 520 / 1314 天里程碑提醒
· 纪念日自动倒数：生日、第一次旅行、领证日……前一天提醒你准备惊喜
· 一键生成「我们在一起第 N 天」分享海报

【桌面和锁屏小组件】
· 把天数放到桌面，长按即可切换显示：在一起天数 / 下一个里程碑 / 任意纪念日
· 锁屏也能看到你们的天数

【回忆时间线】
· 照片、视频、语音，一条回忆最多 9 个
· 「那年今天」自动回顾
· 发现相册里新拍的照片，提醒你一键记录

【每日一问】
· 每天一个走心问题，两人都答完才揭晓
· 连续打卡，聊出平时说不出口的话

【情侣宠物】
· 上传你们宠物的照片，自动抠图，变成会呼吸、会跳、会撒娇的小宠物
· 会饿、会想你们、晚上会睡觉；喂食、摸摸、玩耍，亲密度一起升级
· 放到桌面，直接在小组件上喂食
· 可以和 TA 聊天；也可以填写你自己的 AI 账号（DeepSeek、OpenAI、Claude 等），让 TA 更聪明，或生成专属卡通形象

【帮我选 & 情侣清单】
· 「今天吃什么」「周末去哪」转盘，告别「都行」
· 一起列下想做的 100 件事，一件件打勾

【两个人，各用各的手机】
· 异地同步：通过你们自己的 iCloud 私密共享，TA 回答了今日一问、记录了回忆、让宠物带话，你马上收到通知
· 面对面同步：两部手机靠近即可同步，不需要网络，不经过任何服务器
· 两人同时编辑也不怕：各自的补充互不覆盖

【每日一问 · 开宝箱】
· 两人各答各的，都答完才能一起开宝箱，看看 TA 写了什么
· 没开的宝箱、TA 答了你还没答的题，都会提醒你补上
· 随时给 TA 发一个「想你了」

【隐私】
· 无广告、无追踪、无统计 SDK
· 可开启面容 ID 锁
· 备份文件随时导出，换手机也能带走

## 关键词（100 字符内，英文逗号分隔）

情侣,纪念日,恋爱,倒数日,在一起,天数,情侣空间,宠物,小组件,回忆,日记,异地恋,男朋友,女朋友,老公,老婆

## 「此版本的新功能」

首个版本上线 🎉 纪念日倒数、回忆时间线、每日一问、情侣宠物、桌面小组件、两部手机点对点同步。

## App 隐私（App Store Connect → App 隐私）

- 「你或你的第三方合作伙伴是否会从此 App 收集数据？」→ **否，不收集数据**。
  - 理由：开发者没有服务器，也没有第三方 SDK；数据保存在本机，开启异地同步时保存在用户自己的 iCloud（开发者无法访问，按 Apple 规则不算"收集"）。
  - AI 功能是用户自行填写自己的第三方账号密钥，数据由用户的设备直接发送给用户选择的服务商，开发者及其合作伙伴无法访问。⚠️ 这一点属于判断题，如果你不放心，可以保守地申报「用户内容 → 其他用户内容（不用于追踪、不与身份关联）」。
- 隐私清单（PrivacyInfo.xcprivacy）已包含在 App 和小组件里。

## 出口合规（加密）

- 已在 Info.plist 设置 `ITSAppUsesNonExemptEncryption = NO`（只使用 Apple 系统提供的标准加密：HTTPS、MultipeerConnectivity），上传后不会再被询问。
- ⚠️ 如果上架**法国**区，需要额外声明；不上法国区可忽略。

## 给审核员的备注（App Review Information → Notes，英文）

```
BetterHalf is a private space for couples. No account or login is required — tap through onboarding by entering any two names and a date.

How to test key features:
• Home: days-together counter, anniversary countdown, "Today" card, share poster ("生成分享卡片").
• Memories (回忆): add text/photos/videos/voice notes.
• Pets (宠物): tap + to add a pet from a photo (the background is removed on-device with Vision). Feed/pet/play buttons animate the pet. "和 TA 聊天" opens a chat that replies offline with built-in responses.
• Widgets: add the "我们的天数" and "我们的宠物" widgets from the Home Screen widget gallery.
• Long-distance sync (设置 → 异地同步): uses CloudKit sharing. One partner invites the other through the system iCloud share sheet; data lives in the inviter's private iCloud database and is shared only with the invited Apple ID. Silent CloudKit pushes wake the app so it can post a local notification when the partner answers a question or adds a memory. Requires two Apple IDs to test end-to-end.
• Nearby sync (设置 → 面对面同步): syncs data directly between two nearby iPhones over MultipeerConnectivity. It needs two devices, so it may not be testable in review; no server is involved.

Optional AI features: the app ships with no AI service and no API keys. Users may enter their own API key for a provider of their choice (DeepSeek, OpenAI, Anthropic, etc.) in Settings → AI 设置. Before any data is sent to a provider for the first time, the app shows a consent alert naming the provider. Without a key, all features work offline.

All data stays on the device. No analytics, ads or tracking.
```

联系人信息：⚠️ 填你的姓名、电话、邮箱（只有审核员能看到）。不需要提供演示账号（勾选「不需要登录」）。

## 截图

- 已生成 6.9 英寸 iPhone 截图（1320 × 2868）：`docs/appstore/screenshots/`
- 重新生成：`ios/scripts/screenshots.sh`
- ⚠️ 建议把宠物换成你们自己宠物的照片后再生成一次，更有真实感
