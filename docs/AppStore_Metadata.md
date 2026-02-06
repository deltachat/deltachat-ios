# Delta Chat iOS — App Store 上架资料

> 基于代码仓库 deltachat-ios (v2.34.0 / Build 156) 整理
> Bundle Identifier: `chat.delta`

---

## 一、App 基础信息（全局显示）

### 1. App 名称 (Name)
```
Delta Chat
```
> 10 个字符，已在 Info.plist 中配置为 `CFBundleDisplayName: Delta Chat`

### 2. 副标题 (Subtitle)
```
Secure Decentralized Messenger
```
> 30 个字符。突出"安全"与"去中心化"两大核心卖点。

**备选方案（中文区上架时）：**
```
安全去中心化即时通讯
```
> 10 个字符

### 3. 关键词 (Keywords)
```
chat,messenger,encrypted,email,privacy,OpenPGP,secure,decentralized,open-source,IMAP
```
> 共 93 个字符（含逗号），不超过 100 字符上限。
> 关键词策略：覆盖通讯类核心词（chat, messenger）、安全类（encrypted, secure, privacy, OpenPGP）、技术特色（email, IMAP, decentralized）、开源属性（open-source）。

**备选方案（中文区）：**
```
聊天,加密,通讯,隐私,安全,邮件,开源,去中心化,即时消息,端对端
```

### 4. 分类 (Category)
| 类型 | 选择 |
|------|------|
| **主分类（必选）** | Social Networking（社交） |
| **次分类（可选）** | Productivity（效率） |

---

## 二、版本描述信息（内容详情）

### 1. 宣传文本 (Promotional Text)
```
The decentralized messenger with end-to-end encryption. No phone number needed. No tracking. Free & open source. Chat with anyone using email.
```
> 146 个字符，不超过 170 字符上限。
> 宣传文本可随时修改，无需提交新版本。

**中文版本：**
```
去中心化加密通讯，无需手机号，无追踪，自由开源。基于邮件协议，与任何人安全聊天。支持端到端加密、语音通话、群组和阅后即焚消息。
```

### 2. 描述 (Description)

```
Delta Chat is a reliable, decentralized, and secure messaging app.

NO PHONE NUMBER REQUIRED
Create your chat profile instantly using secure chatmail relays — no phone number, no central account, no tracking. Alternatively, use any classic email address to start chatting.

END-TO-END ENCRYPTION
All messages are automatically encrypted using the proven OpenPGP standard (Autocrypt Level 1). Delta Chat has been independently security-audited. Your conversations are safe from network and server attacks.

TRULY DECENTRALIZED
Delta Chat uses the Internet's most widespread, battle-tested messaging infrastructure — email (IMAP/SMTP). There is no single company or server that controls your data. Choose from a network of interoperable chatmail relays, or use your own server.

FEATURE-RICH MESSENGER
• Instant message delivery with push notifications
• Voice messages, photos, videos, files, and location sharing
• Voice and video calls
• Group chats with unlimited members
• In-chat apps (webxdc) for games and collaboration
• Disappearing messages
• Multi-profile and multi-device support
• Reactions and message editing
• Face ID / Touch ID app lock

PRIVACY BY DESIGN
• No ads, no tracking, no data mining
• No central servers collecting your metadata
• Metadata protection: To, Date, and Autocrypt headers are encrypted
• Optional anonymous usage statistics (disabled by default)
• Delta Chat does not access your phone contacts by default

OPEN SOURCE & FREE
Delta Chat is 100% free and open source (MPL-2.0 license). The source code is available on GitHub for full transparency. No premium features, no subscriptions, no hidden costs.

WORKS WITH EMAIL
Send messages to anyone — even people who don't use Delta Chat. Your messages will arrive as normal emails in their inbox. It's the only messenger that truly reaches everyone.

CROSS-PLATFORM
Available on iOS, Android, Windows, macOS, and Linux. Sync seamlessly across all your devices.

Learn more: https://delta.chat
```
> 约 1,600 个字符，不超过 4,000 字符上限。

**中文版本：**
```
Delta Chat 是一款可靠、去中心化、安全的即时通讯应用。

无需手机号
通过安全的 chatmail 中继即时创建聊天档案——无需手机号，无中心账户，无追踪。也可使用任何传统电子邮件地址开始聊天。

端到端加密
所有消息使用成熟的 OpenPGP 标准（Autocrypt Level 1）自动加密。Delta Chat 已通过独立安全审计。您的对话安全无忧，免受网络和服务器攻击。

真正的去中心化
Delta Chat 使用互联网上最广泛、最经过考验的消息基础设施——电子邮件（IMAP/SMTP）。没有任何单一公司或服务器控制您的数据。

功能丰富
• 即时消息推送通知
• 语音消息、照片、视频、文件和位置共享
• 语音和视频通话
• 无限成员的群组聊天
• 应用内小程序（webxdc），支持游戏和协作
• 阅后即焚消息
• 多账户和多设备支持
• 消息回应和编辑
• Face ID / Touch ID 应用锁

隐私优先设计
• 无广告、无追踪、无数据挖掘
• 无中央服务器收集您的元数据
• 元数据保护：对 To、Date 和 Autocrypt 头部加密
• 可选的匿名使用统计（默认关闭）

开源且免费
Delta Chat 100% 免费开源（MPL-2.0 许可证）。源代码在 GitHub 公开。无付费功能、无订阅、无隐藏费用。

兼容邮件
向任何人发消息——即使对方没有使用 Delta Chat，消息也会以普通邮件形式送达。

跨平台
支持 iOS、Android、Windows、macOS 和 Linux，所有设备无缝同步。

了解更多：https://delta.chat
```

### 3. 技术支持网址 (Support URL)
```
https://support.delta.chat
```
> Delta Chat 官方社区支持论坛。

### 4. 营销网址 (Marketing URL)
```
https://delta.chat
```

---

## 三、后台审核配置（合规与安全）

### 1. 隐私政策网址 (Privacy Policy URL)
```
https://delta.chat/gdpr
```
> Delta Chat 已有 GDPR 合规的隐私政策页面。
> 同时本仓库提供了一份完整的隐私政策申请报告，见 `docs/PrivacyPolicy.md`。

### 2. 年龄分级 (Age Rating)
| 内容 | 选择 |
|------|------|
| 暴力卡通或幻想暴力 | 无 |
| 现实暴力 | 无 |
| 色情或裸露内容 | 无 |
| 亵渎或粗俗幽默 | 无 |
| 药物或酒精相关 | 无 |
| 赌博 | 无 |
| 恐怖/惊悚题材 | 无 |
| 不受限制的网页访问 | 否（应用内不含浏览器） |

**建议评级：4+**

### 3. 出口合规 (Export Compliance)
```
ITSAppUsesNonExemptEncryption = NO (false)
```
> 已在 Info.plist 中声明。Delta Chat 使用标准 OpenPGP 加密，属于豁免类别。

### 4. App 隐私信息 (App Privacy / Privacy Nutrition Labels)

根据代码分析，Delta Chat 的数据收集情况如下：

| 数据类型 | 是否收集 | 用途 | 是否关联用户身份 |
|----------|---------|------|----------------|
| 联系人信息（电子邮件地址） | 是 | App 功能 | 否（存储在本地/邮件服务器） |
| 用户内容（消息、照片、视频） | 是 | App 功能 | 否（端到端加密，不经过 Delta Chat 服务器） |
| 位置 | 是（用户主动分享时） | App 功能 | 否 |
| 诊断数据 | 是（用户可选，默认关闭） | 分析 | 否（匿名统计） |
| 标识符 | 否 | — | — |
| 使用数据 | 否 | — | — |
| 购买记录 | 否 | — | — |
| 财务信息 | 否 | — | — |
| 健康与健身 | 否 | — | — |
| 敏感信息 | 否 | — | — |

**Apple Privacy Manifest (PrivacyInfo.xcprivacy) 已配置：**
- NSPrivacyAccessedAPITypes: UserDefaults (reason: 1C8F.1)

### 5. 权限使用说明 (App Permissions)

| 权限 | 用途说明（Info.plist） |
|------|----------------------|
| 相机 (NSCameraUsageDescription) | Delta Chat uses your camera to take and send photos and videos and to scan QR codes. |
| 麦克风 (NSMicrophoneUsageDescription) | Delta Chat uses your microphone to record and send voice messages and videos with sound. |
| 照片库读取 (NSPhotoLibraryUsageDescription) | Delta Chat will let you choose which photos from your library to send. |
| 照片库写入 (NSPhotoLibraryAddUsageDescription) | Delta Chat wants to save images to your photo library. |
| 位置（使用时）(NSLocationWhenInUseUsageDescription) | Delta Chat needs the location permission in order to share your location for the timespan you have enabled location sharing. |
| 位置（始终）(NSLocationAlwaysAndWhenInUseUsageDescription) | Delta Chat needs the location permission in order to share your location for the timespan you have enabled location sharing. |
| Face ID (NSFaceIDUsageDescription) | Delta Chat uses Face ID to protect your local profile, backup creation and second device setup. |

### 6. 后台模式 (Background Modes)
```
audio, fetch, location, remote-notification, voip
```

---

## 四、审核注意事项

### 审核账号
审核人员需要测试账号来验证 App 功能。建议：
- 提供两个预配置的 chatmail 测试账号（互为联系人）
- 或在审核备注中说明：App 支持即时创建账号，无需注册

### 审核备注 (Review Notes) 建议
```
Delta Chat is a decentralized messenger that uses email protocols (IMAP/SMTP) for message delivery. Users can create a chat profile instantly using chatmail relays (no phone number or registration required) or use any existing email address.

To test the app:
1. Open the app and tap "Create Profile" to set up a chatmail account instantly
2. Use a second device or the provided test accounts to exchange messages
3. Voice/video calls can be tested between two accounts

The app requests location permission only when the user actively chooses to share their location in a conversation. Camera and microphone permissions are requested when the user initiates photo/video capture or voice message recording.

Push notifications are delivered through chatmail relay servers, not through a centralized Delta Chat server.

Privacy Policy: https://delta.chat/gdpr
Source Code: https://github.com/deltachat/deltachat-ios
```

---

## 五、截图与素材要求

### 必需的截图尺寸
| 设备 | 尺寸 (像素) | 数量 |
|------|------------|------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 | 3-10 张 |
| iPhone 6.7" (iPhone 15 Plus/Pro Max) | 1290 × 2796 | 3-10 张 |
| iPhone 6.5" (iPhone 14 Plus) | 1284 × 2778 | 3-10 张 |
| iPad Pro 13" (6th gen) | 2064 × 2752 | 3-10 张 |
| iPad Pro 12.9" (2nd gen) | 2048 × 2732 | 3-10 张 |

### App 图标
- 已在项目中配置，格式为 1024 × 1024 PNG（无 alpha 通道）

### 建议截图内容
1. 聊天列表（展示多个对话）
2. 一对一加密聊天界面（显示绿色加密标识）
3. 群组聊天
4. 账号创建/登录界面（展示无需手机号）
5. QR 码验证联系人
6. 语音/视频通话界面

> 参考项目中已有截图资源：
> `https://raw.githubusercontent.com/deltachat/interface/main/screenshots/2025-07/ios/`

---

## 六、版本信息

| 字段 | 值 |
|------|-----|
| 版本号 (Version) | 2.34.0 |
| 构建号 (Build) | 156 |
| 最低系统要求 | iOS 16.0+ (建议) |
| 支持设备 | iPhone, iPad |
| 开发语言 | Swift, Rust |
| 许可证 | MPL-2.0 |
| 源码地址 | https://github.com/deltachat/deltachat-ios |
