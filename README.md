# Globi (领航助手)

Globi 是一款面向视障人士及其家属的**辅助安全通信 App**，帮助盲人用户与家人建立实时联系，提供语音 AI 助手、位置追踪、一键呼叫等核心功能。

## 功能特性

### 盲人模式

| 功能 | 说明 |
|------|------|
| **授权码绑定** | 输入家属生成的 8 位授权码完成配对，无需传统账号注册 |
| **语音 AI 助手** | 语音输入 → 语音转文字 → AI 对话 → 文字转语音播报，全程语音交互 |
| **实时位置上报** | 自动定时上报位置（每 45 秒），支持手动立即上报 |
| **一键呼叫家属** | 自动拨打绑定家属的电话号码 |
| **SOS 求助** | （开发中）一键呼叫紧急联系人 |

### 家属模式

| 功能 | 说明 |
|------|------|
| **多种登录方式** | OIDC 认证（Authentik）、邮箱密码注册登录 |
| **生成授权码** | 输入盲人姓名，生成一次性 8 位授权码用于绑定 |
| **实时位置监控** | 在地图上查看已绑定盲人的实时位置、精度、速度等信息 |
| **自动刷新定位** | 按服务端指定间隔（默认 ~5 秒）自动拉取最新位置 |
| **管理绑定关系** | 查看所有绑定的盲人列表，支持解绑 |

## 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter** ^3.11.1 | 跨平台 UI 框架 |
| **Dart** ^3.11.1 | 开发语言 |
| **Provider** | 状态管理 |
| **Dio** | 网络请求与拦截器 |
| **flutter_map + OpenStreetMap** | 位置地图展示 |
| **just_audio + record** | 音频播放与录制 |
| **geolocator** | 定位服务 |
| **flutter_secure_storage** | 安全存储 Token |
| **app_links** | 深度链接处理（OAuth2 回调） |
| **dynamic_color** | Material You 动态取色 |
| **flutter_svg** | SVG 图标渲染 |
| **pinput** | 授权码输入框 |

### 目标平台

- Android（primary target）
- iOS
- Web / Linux / macOS / Windows（辅助支持）

## 项目结构

```
globi-app/
├── android/                    # Android 原生工程
│   ├── app/
│   │   ├── build.gradle.kts    # 构建配置（AGP 8.11.1, Kotlin 2.2.20）
│   │   └── release-keystore.jks# 本地发布签名文件（已 gitignore）
│   ├── gradle.properties
│   ├── settings.gradle.kts     # 含国内镜像源
│   └── build.gradle.kts
├── ios/                        # iOS 原生工程
│   └── Runner/
│       └── Info.plist          # 展示名"领航助手", 深链 flutty://
├── lib/
│   ├── main.dart               # 入口：Dio 初始化、Provider 注入、深度链接
│   ├── config/                 # 主题、常量（后端 URL）、导航
│   ├── interceptors/           # Dio 认证拦截器（自动刷新 Token）
│   ├── models/                 # 数据模型（DTO）
│   ├── providers/              # Provider 状态管理
│   ├── screens/                # 页面
│   ├── services/               # API 服务层
│   ├── utils/                  # 工具类（PKCE、WAV 分析、错误处理）
│   └── widgets/                # 公共组件
├── assets/
│   ├── icons_login/            # 登录页图标（authentik.svg）
│   ├── icons_wexin/            # 微信图标（占位）
│   └── icons/                  # 应用图标源文件
├── test/                       # 测试
├── .github/workflows/          # GitHub Actions CI
└── pubspec.yaml                # Flutter 依赖配置
```

## 本地开发指南

### 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| Flutter | ^3.11.1 (stable) | 建议使用 `fvm` 或直接从官网安装 |
| Dart | 随 Flutter SDK | 与 Flutter 绑定 |
| Java | 17 | Android Gradle Plugin 8.11.1 要求 |
| Android Studio | 最新版 | 推荐安装 Android SDK、NDK、Emulator |
| Xcode | 最新版 | 仅 iOS 开发需要，部署目标 13.0 |

### 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/chius-me/globi-app.git
cd globi-app

# 2. 安装 Flutter 依赖
flutter pub get

# 3. 生成应用图标（可选）
dart run flutter_launcher_icons

# 4. 启动开发
flutter run
```

> **国内开发者：** Android 构建配置已包含 Aliyun / 腾讯云 / Flutter-IO 等国内镜像源，无需额外配置代理。

### 后端配置

后端地址在 `lib/config/constants.dart` 中配置：

```dart
static const String backendBaseUrl = 'https://api.globi.lan.tamochi.cn';
```

开发时如需更改后端地址，直接修改此常量即可。项目没有使用 `.env` 文件，如需环境隔离建议自行引入 `flutter_dotenv` 或通过编译常量注入。

### 深度链接配置

OAuth2 登录回调使用 `flutty://login-callback` 深度链接：

| 平台 | 配置位置 |
|------|----------|
| **Android** | `android/app/src/main/AndroidManifest.xml`（intent-filter） |
| **iOS** | `ios/Runner/Info.plist`（CFBundleURLTypes） |

本地调试深度链接：
- **Android:** `adb shell am start -W -a android.intent.action.VIEW -d "flutty://login-callback?code=xxx&state=yyy" cn.tamochi.globi`
- **iOS:** `xcrun simctl openurl booted "flutty://login-callback?code=xxx&state=yyy"`

### Android 发布签名

**本地构建 release APK 需要配置签名文件：**

```bash
# 生成开发用 keystore（仅首次）
keytool -genkeypair -v \
  -keystore android/app/release-keystore.jks \
  -alias globi-key \
  -keyalg RSA -keysize 2048 -validity 10000

# 创建 signing 配置文件
cat > android/key.properties << EOF
storeFile=release-keystore.jks
storePassword=your_store_password
keyAlias=globi-key
keyPassword=your_key_password
EOF

# 构建签名 release APK
flutter build apk --release
```

> `android/key.properties` 和 `release-keystore.jks` 已加入 `.gitignore`，不会提交到仓库。

### iOS 构建

```bash
# 安装 CocoaPods 依赖（首次）
cd ios && pod install && cd ..

# 构建 iOS
flutter build ios --release
```

> iOS 发布需要 Apple Developer 账号、证书和 Provisioning Profile。

### 运行测试

```bash
flutter test
```

## 协作规范

### Git 分支策略

```
main         ← 稳定分支，随时可发布
  └─ feat/*  ← 新功能开发分支（如 feat/voice-record）
  └─ fix/*   ← Bug 修复分支（如 fix/location-crash）
  └─ refactor/* ← 重构分支
```

- **`main`**：只接受 PR 合入，禁止直接推送。合入后即视为可发布状态。
- **功能分支**：从 `main` 切出，命名格式 `feat/<简短描述>`，多个单词用连字符分隔。
- **修复分支**：从 `main` 切出，命名格式 `fix/<简短描述>`。
- 开发完成后通过 **Pull Request** 合入 `main`，PR 标题简明扼要描述改动内容。

### Commit 规范

使用常规提交格式，便于生成 Changelog 和回溯：

```
<type>: <简短描述>

<可选：详细说明>
```

**常用类型：**

| 类型 | 使用场景 |
|------|----------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 重构（不改变外部行为） |
| `docs` | 文档变更 |
| `style` | 代码格式调整（不影响逻辑） |
| `chore` | 构建、CI、依赖等杂项 |
| `revert` | 回滚提交 |

**示例：**

```
feat: add voice recording waveform animation
fix: handle null location when GPS is disabled
refactor: extract location upload logic into service
docs: add local development guide to README
```

### 版本号与 Tag

项目遵循 **语义化版本** `v<主版本>.<次版本>.<补丁>`：

| 版本 | 说明 |
|------|------|
| `v0.1.0` | 初始开发版 |
| `v0.2.0` | 新增功能，向后兼容 |
| `v0.2.1` | Bug 修复 |
| `v1.0.0` | 第一个正式发布版 |

**打 Tag 并触发自动构建：**

```bash
# 确保在正确的提交上
git log --oneline -3

# 创建 Tag（仅合入 main 后打 tag）
git tag v0.2.0

# 推送到 GitHub，触发 Release 流水线
git push origin v0.2.0
```

> **重要规则：**
> - Tag 只能在 `main` 分支上打，禁止在功能分支上打 Tag。
> - Tag 名称必须匹配 `v*` 格式（如 `v0.2.0`），否则流水线不会触发。
> - 一旦推送 Tag，流水线会自动构建并创建 Release，不可撤回（除删除 Tag 和 Release 外）。
> - 发布后如需修复，递增补丁号打新 Tag（`v0.2.1`），不要删除旧 Tag 重打。

```bash
# 如果打错了 Tag（尚未推送）
git tag -d v0.2.0

# 如果已经推送了错误的 Tag
git push origin :refs/tags/v0.2.0   # 删除远程 Tag
git tag -d v0.2.0                    # 删除本地 Tag
gh release delete v0.2.0 --yes       # 删除已创建的 Release
```

## CI/CD 流水线

### 触发方式

推送匹配 `v*` 格式的 Git Tag 时自动触发。

```yaml
on:
  push:
    tags:
      - 'v*'
```

### 流水线步骤

```
Checkout → Setup Flutter → 验证签名 Secrets → 还原签名文件
    → flutter pub get → flutter analyze → flutter build apk --release
    → 重命名 APK → 创建 GitHub Release → 上传 APK
```

| 步骤 | 说明 |
|------|------|
| **Checkout** | 拉取 Tag 对应代码 |
| **Setup Flutter** | 安装 stable 频道 Flutter SDK |
| **验证 Secrets** | 检查 4 个签名 Secrets 是否全部配置 |
| **还原签名文件** | 将 Base64 编码的 keystore 解码写入 `android/app/release-keystore.jks`，生成 `key.properties` |
| **安装依赖** | `flutter pub get` |
| **静态分析** | `flutter analyze` — 代码质量门禁，失败则中止 |
| **构建 APK** | `flutter build apk --release` — 使用上述签名文件签名 |
| **重命名 APK** | `globi-mobile-v0.1.0-release.apk` |
| **创建 Release** | 自动创建 GitHub Release 并上传 APK 作为附件 |

### 所需 Secrets

以下 Secrets 已在仓库中配置，**不需要组员自行设置**：

| Secret | 内容 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | 发布用 keystore 的 Base64 编码 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名（globi-key） |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

## 开发注意事项

### Android

1. **国内镜像源** — `android/settings.gradle.kts` 和 `android/build.gradle.kts` 已预配 Aliyun、腾讯云、Flutter-IO 国内镜像，如果需要切回官方源可以直接删除这些镜像配置。
2. **签名文件不要提交** — `android/key.properties` 和 `*.jks` 已在 `.gitignore` 中且被 Git 忽略。如果本地需要构建 release，按"Android 发布签名"章节自行生成。
3. **NDK 版本** — 不需要手动安装 NDK 或设置 `ANDROID_NDK_HOME`，Gradle 会自动匹配 Flutter 要求的 NDK 版本。

### iOS

1. **Bundle ID** — iOS 的 Bundle Identifier 是 `com.example.globiMobile`，与 Android 的 `cn.tamochi.globi` 不同。发布前需要修改为正式的 Apple Developer 账号对应的 Bundle ID。
2. **显示名称** — iOS 桌面显示名称为"领航助手"，在 `ios/Runner/Info.plist` 的 `CFBundleDisplayName` 中配置。
3. **CocoaPods** — 首次构建需要 `cd ios && pod install`，生成 `.xcworkspace` 文件。
4. **部署目标** — 最低 iOS 13.0。

### 后端

1. **后端地址硬编码** — `lib/config/constants.dart` 中的 `backendBaseUrl` 当前指向 `https://api.globi.lan.tamochi.cn`。如果多人需要连接不同后端，可以考虑引入 `flutter_dotenv` 包或通过编译时 Dart 定义（`--dart-define=BACKEND_URL=xxx`）注入。
2. **后端需要自建** — 后端源码在 [globi-server](https://github.com/chius-me/globi-server) 仓库（待完善），本地开发需要先启动后端服务。
3. **OIDC 依赖** — 家属模式的 Authentik 登录需要后端和 Authentik 实例配合，本地调试时可能需要 mock 或使用开发环境。

### 安全性

1. **Token 存储** — 访问令牌和刷新令牌存储在 `flutter_secure_storage` 中（Android 使用 EncryptedSharedPreferences，iOS 使用 Keychain），不会明文存储在本地。
2. **PKCE 流程** — OAuth2 授权码流程使用了 PKCE（`lib/utils/pkce.dart`），验证器仅存于内存，App 重启后需重新登录。
3. **API 认证** — 所有需要认证的请求通过 `AuthInterceptor` 自动附加 Token 并处理刷新逻辑，无需在每个 API 调用中手动处理。

### 本地化

1. **全部中文界面** — 当前所有 UI 文本为简体中文，无国际化（i18n）支持。如需添加多语言，建议引入 `flutter_localizations` 和 `intl` 包。
2. **地图使用 OpenStreetMap** — `flutter_map` 使用 OpenStreetMap 瓦片，无需 API Key，但在中国境内可能需要代理才能正常加载瓦片。

### 常见问题

<details>
<summary><b>Flutter 版本不匹配</b></summary>

```
The current Dart SDK version is 3.x.x, but globi_mobile requires ^3.11.1.
```

使用 `fvm` 管理 Flutter 版本，或从 [flutter.dev](https://flutter.dev) 安装匹配的 SDK。
</details>

<details>
<summary><b>Android NDK 版本冲突</b></summary>

```
android.ndkVersion is [27.0.12077973] but android.ndkPath ... refers to a different version
```

确保 `ANDROID_NDK_HOME` 和 `ANDROID_NDK_ROOT` 环境变量未设置，让 Gradle 自动匹配 `flutter.ndkVersion`。
</details>

<details>
<summary><b>iOS CocoaPods 安装失败</b></summary>

```bash
sudo gem install cocoapods
pod setup
```

如果网络不稳定，可以尝试设置镜像源或使用代理。
</details>

## 前后端协作流程

由于后端服务部署在内网流水线开发，前后端分离协作采用**文档优先 (Docs First)** 模式。

### 接口需求与契约管理

前端同学需要新接口或字段时，请按以下流程与后端组员同步：

1. **起草需求文档**：在项目根目录维护一个专门的 Markdown 文件（建议命名为 `API_REQUIREMENTS.md` 或在 `docs/API_REQUIREMENTS.md`），将需要的新接口、请求参数、预期返回格式、字段说明清晰写出。
2. **提交 PR / 抛出需求**：将该 Markdown 文件的修改提交到仓库，或直接发送给后端同学。
3. **评审与对齐**：后端同学确认接口设计的合理性，双方对齐参数格式与边界条件后，后端进入开发。
4. **前端 Mock 开发**：在后端接口未就绪期间，前端同学可以通过修改 `lib/services/` 目录下的相关方法，临时返回 Mock 数据进行界面开发。
5. **联调测试**：后端在内网流水线更新发布后，前端切回真实环境地址（或配置内网穿透）进行联调。

**需求文档编写模板参考：**

```markdown
### 1. 获取用户家庭信息 (GET /api/family/info)
- **场景**：个人中心展示家庭住址及联系人
- **Request Query**：无
- **Response**：
  \`\`\`json
  {
    "address": "上海市浦东新区xxx",
    "emergency_contact": "13800138000"
  }
  \`\`\`
```

## 相关仓库

- **后端服务：** [globi-server](https://github.com/chius-me/globi-server)（待补充）

## 许可证

MIT
