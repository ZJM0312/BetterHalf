# BetterHalf 上架清单

✅ = 已经在代码里做好　👤 = 需要你本人操作

## 一、代码侧（已完成）

- ✅ 隐私清单 `PrivacyInfo.xcprivacy`（App 和小组件各一份）
- ✅ 出口合规：`ITSAppUsesNonExemptEncryption = NO`
- ✅ 只支持 iPhone（不需要准备 iPad 截图，也避免 iPad 布局被拒）
- ✅ 版本号 1.0（build 1）；App 类别：生活
- ✅ 所有权限都有中文用途说明（相册、麦克风、面容 ID、本地网络）
- ✅ App 内「设置 → 关于 → 隐私政策」
- ✅ AI 功能：不内置任何密钥；首次发送前弹窗征得同意；密钥只存钥匙串
- ✅ 调试用的启动参数（`-BHOpenSync`、`-BHTab`）只在 Debug 版本存在，正式包里没有

## 二、上架前你要做的

1. 👤 **开通 Apple 开发者账号**（US$99 / ¥688 每年）
   - iPhone 下载「Apple Developer」App → 登录 → 立即注册（个人账号即可）
2. 👤 **替换联系邮箱**：把下面 3 处的 `betterhalf.app@example.com` 换成你的邮箱
   - `ios/BetterHalf/Views/PrivacyPolicyView.swift`（`AppInfo.contactEmail`）
   - `docs/privacy.html`、`docs/support.html`
3. 👤 **把隐私政策放到网上**（GitHub Pages，免费）
   - 把代码推到 GitHub → 仓库 Settings → Pages → Source 选 `main` 分支、`/docs` 目录 → Save
   - 几分钟后可以访问 `https://你的用户名.github.io/BetterHalf/privacy.html`
   - 仓库必须是公开的（或者用任何你有的网站托管这两个 html 文件也行）
4. 👤 **开发者账号通过后**，在 Xcode → Signing & Capabilities 把两个 target 的 Team 换成新的付费团队（名字后面不再是 Personal Team）
   - **打开异地同步**（免费账号不支持 iCloud 和推送，所以默认关着）：Xcode 左侧点项目 BetterHalf →（PROJECT 下的）BetterHalf → Build Settings → 搜 `BH_CLOUDKIT` → 改成 `YES`
   - 然后在 BetterHalf target 的 Signing & Capabilities 里确认出现了 iCloud（勾选 CloudKit，容器 `iCloud.com.betterhalf.hxiz1q`）和 Push Notifications；没出现就点「+ Capability」手动加上这两项，容器名保持一致
   - 用两个 Apple ID 的手机各装一次测试：A 在「设置 → 异地同步」邀请，B 点开链接加入，然后 B 回答今日一问，A 应该马上收到「宝箱可以开啦」通知
   - **上架前必须做**：打开 icloud.developer.apple.com → 选容器 `iCloud.com.betterhalf.hxiz1q` → Schema → Deploy Schema Changes（把开发环境自动生成的 Snapshot / Media 记录类型部署到生产环境），否则正式版同步会失败
5. 👤 **在 App Store Connect 创建 App**（appstoreconnect.apple.com → 我的 App → ＋）
   - 平台 iOS，名称见 `docs/appstore/listing.md`，套装 ID 选 `com.betterhalf.hxiz1q`，SKU 随便填（如 betterhalf001）
6. **上传**（可以让我来做，或者你在 Xcode 里操作）
   - Xcode 顶部设备选「Any iOS Device (arm64)」→ 菜单 Product → Archive → 完成后点 Distribute App → App Store Connect → Upload
7. 👤 **先发 TestFlight 给老婆**（可选，推荐）
   - App Store Connect → TestFlight → 内部测试 → 把她的 Apple ID 邮箱加成用户 → 她装 TestFlight App 就能下载
8. 👤 **填写商店信息并提交审核**
   - 文案、关键词、审核备注全部在 `docs/appstore/listing.md`，复制粘贴即可
   - 截图在 `docs/appstore/screenshots/`（6.9 英寸）
   - App 隐私选「不收集数据」（理由见 listing.md）
   - 选择刚上传的版本 → 提交审核，一般 1～2 天出结果

## 三、上架地区

- 中国大陆区需要先办 **App 备案**（ICP），没有备案号无法在国区上架。可以先在「价格与销售范围」里取消中国大陆，其他地区先上。
- 法国区需要额外的加密声明；不想处理的话同样可以先不选法国。

## 四、常见被拒原因（已提前规避）

| 原因 | 我们的情况 |
|---|---|
| 缺隐私政策 / 隐私清单 | 已有 |
| 需要登录但没给测试账号 | 不需要登录 |
| AI 生成内容 / 向第三方 AI 发数据未告知 | 有首次同意弹窗 + 隐私政策说明，且不内置 AI |
| 功能太少（4.2） | 功能完整 |
| 权限用途说明不清楚 | 都写了具体用途 |
| 崩溃 | 已在模拟器和真机跑过主要流程 |
