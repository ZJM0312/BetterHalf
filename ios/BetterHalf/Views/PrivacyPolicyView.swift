import SwiftUI

enum AppInfo {
    /// TODO before release: replace with your real contact email (also in docs/privacy.html and docs/support.html).
    static let contactEmail = "betterhalf.app@example.com"
    static let privacyURL = "https://YOUR-GITHUB-NAME.github.io/BetterHalf/privacy.html"
}

/// In-app copy of the privacy policy (the public web version lives in docs/privacy.html).
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("更新日期：2026 年 11 月").font(.caption).foregroundStyle(.secondary)
                block("一句话总结", "BetterHalf 不需要注册，没有服务器，不收集、不出售、不分析你的任何数据。你们的回忆只存在你们自己的手机里（开启异地同步时，存在你们自己的 iCloud 里）。")
                block("数据存在哪里", "名字、纪念日、回忆（文字、照片、视频、语音）、每日一问、清单和宠物都保存在你 iPhone 本机的 App 存储空间里，受 iOS 文件加密保护。卸载 App 会一起删除，除非你自己导出了备份。")
                block("两部手机同步", "「面对面同步」通过 Wi-Fi / 蓝牙在附近的两部手机之间直接加密传输，不经过任何服务器。第一次连接需要对方确认。")
                block("你们之间只共享 App 里的内容", "两部手机之间只会同步你们在 BetterHalf 里写下的内容（回忆、每日一问、清单、纪念日、宠物）以及你亲手加进回忆的照片、视频、语音。App 没有任何读取对方手机相册、通讯录、位置、短信、文件或其他 App 信息的功能；对方发来的数据会先经过校验，只接受 App 自己生成的内容。")
                block("相册授权", "「设置 → 相册授权」里有两个开关：「允许从相册选择照片」（关闭后不再显示相册入口）和「读取最新照片并提醒记录」（默认关闭）。照片只在你的手机上读取，除非你自己加进回忆，否则不会同步给任何人。")
                block("异地同步（iCloud）", "开启后，你们的数据会保存在发起人的 iCloud 私有数据库中，并通过 Apple 的 iCloud 共享只与你邀请的另一半共享，由 Apple 负责存储与传输加密。开发者无法访问这些数据。随时可以在设置里停止同步，停止后云端副本会被删除，两部手机上的数据保留。")
                block("AI 功能（可选）", "如果你在「AI 设置」里填写了自己的 API Key，和宠物聊天的内容、宠物的名字/性格/外观描述会直接从你的手机发送到你选择的服务商（例如 DeepSeek、OpenAI、Anthropic），由该服务商按其隐私政策处理并向你的账号计费。第一次发送前 App 会再次征求你的同意。API Key 只保存在本机钥匙串中。不填写则不会有任何数据发送给 AI 服务。")
                block("系统权限", "相册：选择照片、发现新照片并提醒记录、保存分享卡片。麦克风：录制语音回忆。通知：纪念日与宠物提醒。面容 ID：给 App 上锁。本地网络：面对面同步。iCloud 与推送：异地同步与对方更新提醒。所有权限都可以随时在系统设置里关闭。")
                block("儿童", "BetterHalf 不面向 13 岁以下儿童，也不会有意收集任何人的个人信息。")
                block("联系我们", "如有任何问题，请发邮件至 \(AppInfo.contactEmail)。")
            }
            .padding(20)
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
