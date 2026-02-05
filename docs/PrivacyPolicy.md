# Delta Chat — Privacy Policy / 隐私政策

**Last Updated / 最后更新：2026-02-05**
**App Name / 应用名称：Delta Chat**
**Developer / 开发者：merlinux GmbH and Delta Chat contributors**
**Contact / 联系方式：https://delta.chat**

---

## English Version

### 1. Introduction

Delta Chat is a free, open-source, decentralized messaging application. We are committed to protecting your privacy. This Privacy Policy explains what data the Delta Chat iOS app ("the App") collects, how it is used, and the choices available to you.

Delta Chat is fundamentally different from most messaging apps: **we do not operate central servers that process or store your messages**. All communication is routed through email protocols (IMAP/SMTP) using servers that you or your relay provider operate.

### 2. Data Controller

The Delta Chat project is developed by merlinux GmbH and a community of open-source contributors.

```
merlinux GmbH
Reichgrafen Str. 20
79102 Freiburg, Germany
```

For privacy-related inquiries, contact us via: https://delta.chat

### 3. Data We Do NOT Collect

Delta Chat **does not** collect, store, or have access to:

- Your phone number
- Your device identifiers (IDFA, IDFV, etc.)
- Your contacts / address book
- Your message content (messages are end-to-end encrypted)
- Your browsing or usage behavior
- Your location data
- Any advertising identifiers
- Crash reports (no third-party crash reporting SDKs are integrated)

### 4. Data Processed Locally on Your Device

The following data is created and stored **exclusively on your device** and is never transmitted to Delta Chat developers or any central server operated by us:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Chat profile (name, avatar) | Display in conversations | Local device only |
| Messages and media | Chat functionality | Local device + your email server |
| Encryption keys (OpenPGP) | End-to-end encryption | Local device only |
| Contact list | Managing conversations | Local device only |
| App settings and preferences | User customization | Local device (UserDefaults) |

### 5. Data Transmitted to Third-Party Servers

#### 5.1 Email/Chatmail Relay Servers

Delta Chat transmits your messages through email servers using IMAP and SMTP protocols. These servers may be:

- **Chatmail relays** (e.g., servers listed at https://chatmail.at/relays) — privacy-focused servers designed for Delta Chat that minimize metadata retention
- **Traditional email providers** — if you choose to use a classic email address (e.g., Gmail, Outlook)

**What is transmitted:**
- Encrypted message content (end-to-end encrypted with OpenPGP when possible)
- Email headers (To, From, Date — protected via metadata encryption on chatmail relays)
- Attachments (encrypted)

**Important:** Delta Chat does not control these email servers. Please review the privacy policy of your chosen email/chatmail provider.

#### 5.2 Apple Push Notification Service (APNs)

To deliver push notifications on iOS, Delta Chat uses Apple's Push Notification Service. When you use a chatmail relay that supports push notifications:

- A device push token is shared with your chatmail relay server
- The chatmail relay sends notification triggers through APNs
- **No message content is included in push notifications** — messages are fetched directly from the server after the notification wakes the app

#### 5.3 Optional Anonymous Statistics

Delta Chat includes an **opt-in** feature to send anonymous usage statistics to help improve the app. This feature is:

- **Disabled by default** — you must explicitly enable it in Settings → Advanced → "Send statistics to Delta Chat's developers"
- **Anonymous** — no personal identifiers are included
- **Limited in scope** — only collects: the Delta Chat version in use, the count of QR code introductions, and error occurrence rates
- **Sent weekly** via a Delta Chat bot when enabled

You can disable this at any time by toggling the setting off.

### 6. Device Permissions

Delta Chat requests the following device permissions **only when the corresponding feature is used**. All permissions are optional and can be denied without affecting core messaging functionality.

| Permission | When Requested | Purpose |
|------------|---------------|---------|
| **Camera** | Taking photos/videos, scanning QR codes | Capture media to send; scan QR codes for contact verification and account setup |
| **Microphone** | Recording voice messages or videos with sound | Capture audio for voice messages and video recordings |
| **Photo Library (Read)** | Selecting existing photos to send | Let you choose photos from your library to share in chats |
| **Photo Library (Write)** | Saving received images | Save images from conversations to your photo library |
| **Location (When In Use)** | Sharing location in a chat | Share your real-time location with selected conversation partners |
| **Location (Always)** | Continued location sharing | Continue sharing location when the app is in the background |
| **Face ID / Touch ID** | Enabling app lock | Protect your local profile, backup creation, and second device setup with biometric authentication |
| **Notifications** | Receiving message alerts | Display notifications for incoming messages |

### 7. End-to-End Encryption

Delta Chat uses the **OpenPGP** standard with **Autocrypt Level 1** for automatic end-to-end encryption:

- Encryption keys are generated on your device and never leave it
- Messages between Delta Chat users are encrypted by default when keys have been exchanged
- Contact verification via QR codes provides protection against active network attacks
- Delta Chat has undergone **independent security audits**
- Metadata protection: To, Date, and Autocrypt headers are encrypted on supported relays

### 8. Data Retention and Deletion

- **Messages:** Stored locally on your device and on your email server. You control deletion through the app's "Disappearing Messages" feature or manual deletion. Delta Chat does not retain copies.
- **Account data:** When you delete a chat profile from the app, all local data (messages, keys, settings) for that profile is permanently removed from your device.
- **Email server data:** Depending on your server settings, messages may remain on the email server. You can configure "Multi-Device Mode" settings to control server retention.
- **Anonymous statistics:** If previously enabled, no further data is sent once disabled. Historical anonymous data cannot be linked back to you.

### 9. Children's Privacy

Delta Chat does not knowingly collect personal information from children under the age of 13 (or the applicable age in your jurisdiction). The App does not contain age-gated content. The suggested App Store age rating is 4+.

### 10. International Data Transfers

Since Delta Chat is a decentralized system using email protocols, your messages transit through the email servers you have chosen. If you use a chatmail relay or email provider located in a different country, your data may cross international borders subject to that provider's policies.

Delta Chat itself (the app and its developers) does not transfer your personal data internationally.

### 11. Your Rights (GDPR & Applicable Law)

If you are in the European Economic Area (EEA), you have the following rights:

- **Right of Access:** You can access all your data directly within the app (it's stored locally on your device)
- **Right to Rectification:** You can edit your profile information at any time within the app
- **Right to Erasure:** You can delete your profile and all associated data within the app
- **Right to Data Portability:** You can export your data using the app's backup feature
- **Right to Object:** You can disable optional statistics at any time

Since Delta Chat stores your data locally on your device and does not maintain a central database of user information, most data rights are exercised directly through the app.

### 12. Third-Party Services and SDKs

Delta Chat iOS integrates the following third-party components:

| Component | Purpose | Data Shared |
|-----------|---------|-------------|
| deltachat-core-rust | Core messaging engine | None (local processing) |
| Apple Push Notification Service | Push notifications | Device token (via chatmail relay) |

**Delta Chat does NOT integrate:**
- No advertising SDKs
- No analytics SDKs (e.g., no Firebase Analytics, no Mixpanel)
- No crash reporting SDKs (e.g., no Crashlytics, no Sentry)
- No social media SDKs
- No tracking pixels or beacons

### 13. Open Source Transparency

Delta Chat is fully open source under the Mozilla Public License 2.0. You can verify all privacy claims by reviewing the source code:

- iOS App: https://github.com/deltachat/deltachat-ios
- Core Library: https://github.com/deltachat/deltachat-core-rust

### 14. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated "Last Updated" date. We encourage you to review this Privacy Policy periodically.

### 15. Contact Us

For any questions about this Privacy Policy or Delta Chat's privacy practices:

- Website: https://delta.chat
- Community Forum: https://support.delta.chat
- GitHub Issues: https://github.com/deltachat/deltachat-ios/issues

---

## 中文版本

### 1. 引言

Delta Chat 是一款免费、开源、去中心化的即时通讯应用。我们致力于保护您的隐私。本隐私政策说明 Delta Chat iOS 应用（以下简称"本应用"）收集哪些数据、如何使用这些数据，以及您可做出的选择。

Delta Chat 与大多数即时通讯应用有着根本性的不同：**我们不运营处理或存储您消息的中央服务器**。所有通信均通过电子邮件协议（IMAP/SMTP），经由您或您的中继服务提供商运营的服务器进行传输。

### 2. 数据控制方

Delta Chat 项目由 merlinux GmbH 及开源社区贡献者共同开发。

```
merlinux GmbH
Reichgrafen Str. 20
79102 Freiburg, Germany（德国弗莱堡）
```

隐私相关问询请通过以下地址联系：https://delta.chat

### 3. 我们不收集的数据

Delta Chat **不会**收集、存储或访问以下信息：

- 您的手机号码
- 您的设备标识符（IDFA、IDFV 等）
- 您的通讯录/地址簿
- 您的消息内容（消息经端到端加密）
- 您的浏览或使用行为
- 您的位置数据
- 任何广告标识符
- 崩溃报告（未集成任何第三方崩溃报告 SDK）

### 4. 在您设备上本地处理的数据

以下数据**仅在您的设备上**创建和存储，绝不会传输给 Delta Chat 开发者或我们运营的任何中央服务器：

| 数据类型 | 用途 | 存储位置 |
|---------|------|---------|
| 聊天档案（姓名、头像） | 在对话中显示 | 仅限本地设备 |
| 消息和媒体文件 | 聊天功能 | 本地设备 + 您的邮件服务器 |
| 加密密钥（OpenPGP） | 端到端加密 | 仅限本地设备 |
| 联系人列表 | 管理对话 | 仅限本地设备 |
| 应用设置和偏好 | 用户自定义 | 本地设备（UserDefaults） |

### 5. 传输至第三方服务器的数据

#### 5.1 邮件/Chatmail 中继服务器

Delta Chat 通过 IMAP 和 SMTP 协议经由邮件服务器传输您的消息。这些服务器可能是：

- **Chatmail 中继**（例如 https://chatmail.at/relays 上列出的服务器）——为 Delta Chat 设计的注重隐私的服务器，最小化元数据留存
- **传统邮件提供商**——如果您选择使用传统邮箱地址（如 Gmail、Outlook）

**传输内容：**
- 加密的消息内容（在可能时使用 OpenPGP 端到端加密）
- 邮件头部（收件人、发件人、日期——在 chatmail 中继上通过元数据加密保护）
- 附件（已加密）

**重要提示：** Delta Chat 不控制这些邮件服务器。请查阅您所选邮件/chatmail 提供商的隐私政策。

#### 5.2 Apple 推送通知服务（APNs）

为在 iOS 上投递推送通知，Delta Chat 使用 Apple 的推送通知服务。当您使用支持推送通知的 chatmail 中继时：

- 设备推送令牌会与您的 chatmail 中继服务器共享
- chatmail 中继通过 APNs 发送通知触发器
- **推送通知中不包含消息内容**——消息在通知唤醒应用后直接从服务器获取

#### 5.3 可选的匿名统计

Delta Chat 包含一项**可选启用**的匿名使用统计功能，以帮助改进应用。该功能：

- **默认关闭**——您必须在"设置 → 高级 → 向 Delta Chat 开发者发送统计数据"中明确启用
- **匿名**——不包含任何个人标识符
- **范围有限**——仅收集：使用中的 Delta Chat 版本、QR 码引荐次数、错误发生率
- 启用后**每周发送一次**，通过 Delta Chat 机器人传递

您可以随时通过关闭该设置来停止发送。

### 6. 设备权限

Delta Chat **仅在使用相应功能时**请求以下设备权限。所有权限均为可选，拒绝授权不会影响核心消息功能。

| 权限 | 请求时机 | 用途 |
|------|---------|------|
| **相机** | 拍照/录像、扫描二维码 | 拍摄媒体以发送；扫描二维码用于联系人验证和账号设置 |
| **麦克风** | 录制语音消息或带声音的视频 | 为语音消息和视频录制捕获音频 |
| **照片库（读取）** | 选择已有照片发送 | 让您从相册中选择照片在聊天中分享 |
| **照片库（写入）** | 保存收到的图片 | 将对话中的图片保存到您的相册 |
| **位置（使用时）** | 在聊天中共享位置 | 与选定的对话伙伴分享您的实时位置 |
| **位置（始终）** | 持续位置共享 | 应用在后台时继续共享位置 |
| **Face ID / Touch ID** | 启用应用锁 | 使用生物识别保护您的本地档案、备份创建和第二设备设置 |
| **通知** | 接收消息提醒 | 显示收到消息的通知 |

### 7. 端到端加密

Delta Chat 使用 **OpenPGP** 标准与 **Autocrypt Level 1** 实现自动端到端加密：

- 加密密钥在您的设备上生成，绝不会离开设备
- Delta Chat 用户之间的消息在交换密钥后默认加密
- 通过二维码进行的联系人验证可防范主动网络攻击
- Delta Chat 已通过**独立安全审计**
- 元数据保护：在支持的中继上对 To、Date 和 Autocrypt 头部进行加密

### 8. 数据保留与删除

- **消息：** 存储在您的设备和邮件服务器上。您可以通过应用的"阅后即焚消息"功能或手动删除来控制。Delta Chat 不保留副本。
- **账户数据：** 当您从应用中删除聊天档案时，该档案的所有本地数据（消息、密钥、设置）将从您的设备上永久删除。
- **邮件服务器数据：** 根据您的服务器设置，消息可能保留在邮件服务器上。您可以配置"多设备模式"设置来控制服务器端的留存。
- **匿名统计：** 如果之前启用，禁用后将不再发送数据。历史匿名数据无法追溯关联到您。

### 9. 儿童隐私

Delta Chat 不会故意收集 13 岁以下（或您所在司法管辖区适用年龄以下）儿童的个人信息。本应用不包含年龄限制内容。建议的 App Store 年龄评级为 4+。

### 10. 国际数据传输

由于 Delta Chat 是使用电子邮件协议的去中心化系统，您的消息通过您选择的邮件服务器传输。如果您使用位于其他国家的 chatmail 中继或邮件提供商，您的数据可能跨越国际边界，受该提供商政策约束。

Delta Chat 本身（应用及其开发者）不会将您的个人数据进行国际传输。

### 11. 您的权利（GDPR 及适用法律）

如果您位于欧洲经济区（EEA），您拥有以下权利：

- **访问权：** 您可以直接在应用中访问所有数据（数据存储在您的本地设备上）
- **更正权：** 您可以随时在应用中编辑您的档案信息
- **删除权：** 您可以在应用中删除档案及所有相关数据
- **数据可携权：** 您可以使用应用的备份功能导出数据
- **反对权：** 您可以随时禁用可选的统计功能

由于 Delta Chat 将数据存储在您的本地设备上，不维护用户信息的中央数据库，大多数数据权利可直接通过应用行使。

### 12. 第三方服务与 SDK

Delta Chat iOS 集成了以下第三方组件：

| 组件 | 用途 | 共享的数据 |
|------|------|-----------|
| deltachat-core-rust | 核心消息引擎 | 无（本地处理） |
| Apple 推送通知服务 | 推送通知 | 设备令牌（通过 chatmail 中继） |

**Delta Chat 未集成：**
- 无广告 SDK
- 无分析 SDK（如无 Firebase Analytics、无 Mixpanel）
- 无崩溃报告 SDK（如无 Crashlytics、无 Sentry）
- 无社交媒体 SDK
- 无追踪像素或信标

### 13. 开源透明

Delta Chat 在 Mozilla Public License 2.0 下完全开源。您可以通过查看源代码来验证所有隐私声明：

- iOS 应用：https://github.com/deltachat/deltachat-ios
- 核心库：https://github.com/deltachat/deltachat-core-rust

### 14. 隐私政策变更

我们可能会不时更新本隐私政策。变更将在本页面发布，并更新"最后更新"日期。我们建议您定期查阅本隐私政策。

### 15. 联系我们

如果您对本隐私政策或 Delta Chat 的隐私实践有任何问题：

- 网站：https://delta.chat
- 社区论坛：https://support.delta.chat
- GitHub Issues：https://github.com/deltachat/deltachat-ios/issues

---

*This privacy policy is provided as part of the App Store submission materials for Delta Chat iOS. The canonical privacy policy is available at https://delta.chat/gdpr*
