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
static const String backendBaseUrl = 'https://server.globi.lan.tamochi.cn';
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

### 推送 Tag 触发自动构建

项目配置了 GitHub Actions，推送 `v*` 格式的 Tag 会自动构建签名 APK 并创建 Release：

```bash
git tag v0.1.0
git push origin v0.1.0
```

Workflow 所需的 Secrets 已在仓库中配置：
- `ANDROID_KEYSTORE_BASE64` — 签名证书（Base64 编码）
- `ANDROID_STORE_PASSWORD` — 证书存储密码
- `ANDROID_KEY_ALIAS` — 证书别名
- `ANDROID_KEY_PASSWORD` — 证书密钥密码

### 运行测试

```bash
flutter test
```

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

## 相关仓库

- **后端服务：** [globi-server](https://github.com/chius-me/globi-server)（待补充）
- **Web 管理端：** [globi-admin](https://github.com/chius-me/globi-admin)（待补充）

## 许可证

MIT
