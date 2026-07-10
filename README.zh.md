<p align="right">
  <a href="./README.md">English</a> | 简体中文
</p>

<h1 align="center">globi-app</h1>

<p align="center">
  Globi (领航助手) 移动端客户端 App — 基于 Flutter/Dart 开发，面向视障人士及其家属的辅助安全通信客户端。
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue.svg">
  <img alt="Language" src="https://img.shields.io/badge/Language-Dart-00B4AB.svg">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Flutter-02569B.svg">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg">
</p>

## 功能特性

`globi-app` 致力于在视障人士与其家属之间架起安全沟通的桥梁。应用具有两种独立的用户操作模式：

| 模式 | 核心功能 | 适用对象 |
|---|---|---|
| **盲人模式** | 8 位免密授权码绑定、语音 AI 交互助手、每 45 秒定时位置上报、一键电话拨打家属。 | 视障用户 |
| **家属模式** | 地图实时位置追踪、自动刷新定位频率监控、多账号绑定管理、邮箱及第三方认证登录。 | 家属 / 监护人 |

## 环境要求

| 工具 / 平台 | 建议版本 | 用途 |
|---|---|---|
| **Flutter SDK** | `^3.11.1` (stable) | 跨平台工程构建 |
| **Dart SDK** | 随 Flutter SDK 绑定 | 业务逻辑开发语言 |
| **JDK (Java)** | 17 | 配合 Android Gradle Plugin (AGP 8.11.1) 编译 |
| **Android Studio** | 最新版 | Android SDK 与模拟器管理 |
| **Xcode** | 最新版 | iOS 编译环境（最低支持 iOS 13.0） |
| **CocoaPods** | 最新版 | iOS Pod 依赖包管理 |

## 快速开始

### 1. 克隆与初始化

克隆本项目仓库，并获取 Flutter 依赖包：
```bash
git clone https://github.com/chius-me/globi-app.git
cd globi-app
flutter pub get
```

### 2. 配置后端 API 地址

修改 `lib/config/constants.dart` 文件，将后端地址替换为您的实际服务地址：
```dart
static const String backendBaseUrl = 'https://api.yourdomain.com';
```

### 3. 运行与调试

- 启动开发调试（需连接真机或启动模拟器）：
  ```bash
  flutter run
  ```
- 运行单元测试：
  ```bash
  flutter test
  ```

---

## 打包与签名

### Android 打包签名
本地编译签名的 Release APK 包，需要配置签名证书配置文件（已被 git 忽略）：

1. **生成 Keystore 签名密钥（仅需执行一次）：**
   ```bash
   keytool -genkeypair -v \
     -keystore android/app/release-keystore.jks \
     -alias globi-key \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. **创建配置文件：**
   在 `android/key.properties` 中写入：
   ```properties
   storeFile=release-keystore.jks
   storePassword=your-store-password
   keyAlias=globi-key
   keyPassword=your-key-password
   ```
3. **开始编译：**
   ```bash
   flutter build apk --release
   ```

### iOS 打包
安装 Pods 依赖，并触发打包编译：
```bash
cd ios
pod install
cd ..
flutter build ios --release
```

---

## 技术细节与调试

### 1. 深度链接调试 (Deep Links)
GitHub OAuth 登录流程使用 `flutty://login-callback` 深度链接重定向回 App：
- **Android**: 配有 intent-filter，见 `android/app/src/main/AndroidManifest.xml`
- **iOS**: 配有 CFBundleURLTypes，见 `ios/Runner/Info.plist`

**本地调试命令：**
- **Android**: `adb shell am start -W -a android.intent.action.VIEW -d "flutty://login-callback?code=xxx" cn.tamochi.globi`
- **iOS**: `xcrun simctl openurl booted "flutty://login-callback?code=xxx"`

### 2. 语音 AI 录音与播放
- 使用 `record` 库采集 `.wav` 音频并发送给后端进行 Paraformer STT 转换。
- 使用 `just_audio` 播报后端返回的 Cosyvoice 合成音频字节流。

### 3. 数据安全与状态存储
- **Provider**: 用于高效管理盲人页面状态和家属地图列表状态。
- **flutter_secure_storage**: 使用 EncryptedSharedPreferences (Android) 和 Keychain (iOS) 加密保存 JWT tokens。
- **PKCE 流程**: 在客户端（`lib/utils/pkce.dart`）实现 OAuth 2.0 PKCE 规范防篡改。

---

## 协作规范

### Commit 格式规范
项目遵循 Conventional Commits 提交注释约定：
- `feat: add voice recording waveform animation`
- `fix: handle null location when GPS is disabled`
- `refactor: extract location upload logic into service`
- `chore: update dependencies`

### CI/CD 流水线
在 `main` 分支上打以 `v*` 开头的 Tag 并推送（例如 `v0.2.0`），GitHub Actions 会自动触发打包任务，对 Android APK 进行签名编译，并创建对应的 GitHub Release，将 APK 上传至附件中发布。
