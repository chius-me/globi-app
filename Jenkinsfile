pipeline {
    agent any // 在宿主机执行

    options {
        timestamps()
        // 保持构建的最大个数，防止历史记录塞满磁盘
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
    }

    environment {
        // Gitea 凭据及变量
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = 'http://10.0.0.131:3000'
        REPO_OWNER = 'chius'
        REPO_NAME = 'globi-mobile'
        TAG_NAME = "v${env.BUILD_NUMBER}"
        TARGET_COMMITISH = "${env.BRANCH_NAME ?: 'main'}"
        APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
        NDK_VERSION = '27.0.12077973'
        NDK_DOWNLOAD_URL = 'https://dl.google.com/android/repository/android-ndk-r27-linux.zip'
    }

    stages {
        stage('Docker Build APK') {
            steps {
                sh '''
                echo "启动 Flutter 编译容器..."
                docker run --rm -i \\
                  -v "${WORKSPACE}:/workspace" \\
                  -v "/var/lib/jenkins/.gradle_cache:/root/.gradle" \\
                  -v "/var/lib/jenkins/.pub_cache:/root/.pub-cache" \\
                  -e HTTP_PROXY="http://Clash:AYmOkhoZ@10.0.0.1:7890" \\
                  -e HTTPS_PROXY="http://Clash:AYmOkhoZ@10.0.0.1:7890" \\
                  -e NDK_VERSION="${NDK_VERSION}" \\
                  -e NDK_DOWNLOAD_URL="${NDK_DOWNLOAD_URL}" \\
                  -e PUB_HOSTED_URL='https://pub.flutter-io.cn' \\
                  -e FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn' \\
                  -w /workspace \\
                  ghcr.io/cirruslabs/flutter:stable \\
                  bash -se <<'EOF'
set -e

echo '=== 强制注入 JVM 底层参数 ==='
# 确保 Java 在启动的第一时间就允许 HTTP 代理隧道传递密码，并全局注入代理认证信息
export _JAVA_OPTIONS='-Djdk.http.auth.tunneling.disabledSchemes= -Djdk.http.auth.proxying.disabledSchemes= -Dhttp.proxyHost=10.0.0.1 -Dhttp.proxyPort=7890 -Dhttp.proxyUser=Clash -Dhttp.proxyPassword=AYmOkhoZ -Dhttps.proxyHost=10.0.0.1 -Dhttps.proxyPort=7890 -Dhttps.proxyUser=Clash -Dhttps.proxyPassword=AYmOkhoZ'
export GRADLE_OPTS='-Djdk.http.auth.tunneling.disabledSchemes= -Djdk.http.auth.proxying.disabledSchemes='

echo '=== 强制配置 Java/Gradle 专属代理 ==='
mkdir -p /root/.gradle
cat <<'GRADLE_EOF' > /root/.gradle/gradle.properties
systemProp.http.proxyHost=10.0.0.1
systemProp.http.proxyPort=7890
systemProp.http.proxyUser=Clash
systemProp.http.proxyPassword=AYmOkhoZ
systemProp.https.proxyHost=10.0.0.1
systemProp.https.proxyPort=7890
systemProp.https.proxyUser=Clash
systemProp.https.proxyPassword=AYmOkhoZ
org.gradle.jvmargs=-Djdk.http.auth.tunneling.disabledSchemes= -Djdk.http.auth.proxying.disabledSchemes=
GRADLE_EOF

echo '=== 准备 Android SDK / NDK ==='
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
NDK_DIR="$ANDROID_HOME/ndk/${NDK_VERSION}"
SDKMANAGER_BIN="$(command -v sdkmanager || true)"
if [ -z "$SDKMANAGER_BIN" ] && [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    SDKMANAGER_BIN="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
fi
if [ ! -d "$NDK_DIR" ]; then
    if [ -n "$SDKMANAGER_BIN" ]; then
        yes | "$SDKMANAGER_BIN" --licenses > /dev/null || true
        if ! yes | "$SDKMANAGER_BIN" "ndk;${NDK_VERSION}"; then
            echo 'sdkmanager 安装 NDK 失败，改为直接下载安装包'
        fi
    else
        echo 'sdkmanager 未找到，改为直接下载安装包'
    fi
fi
if [ ! -d "$NDK_DIR" ]; then
    rm -rf /tmp/android-ndk-download
    mkdir -p /tmp/android-ndk-download "$ANDROID_HOME/ndk"
    curl --fail --location --retry 3 --output /tmp/android-ndk.zip "$NDK_DOWNLOAD_URL"
    unzip -q /tmp/android-ndk.zip -d /tmp/android-ndk-download
    NDK_EXTRACT_DIR="$(find /tmp/android-ndk-download -maxdepth 1 -type d -name 'android-ndk-r27*' | head -n 1)"
    if [ -z "$NDK_EXTRACT_DIR" ]; then
        echo 'NDK 解压目录未找到'
        exit 1
    fi
    rm -rf "$NDK_DIR"
    mv "$NDK_EXTRACT_DIR" "$NDK_DIR"
fi
export ANDROID_NDK_HOME="$NDK_DIR"
export ANDROID_NDK_ROOT="$NDK_DIR"
if [ ! -f "$NDK_DIR/source.properties" ]; then
    echo "NDK 目录无效: $NDK_DIR"
    exit 1
fi

echo '=== 修正 Android local.properties ==='
FLUTTER_BIN="$(command -v flutter)"
FLUTTER_BIN="$(readlink -f "$FLUTTER_BIN" 2>/dev/null || echo "$FLUTTER_BIN")"
FLUTTER_ROOT="$(dirname "$(dirname "$FLUTTER_BIN")")"
FLUTTER_VERSION_NAME="$(grep '^flutter.versionName=' android/local.properties 2>/dev/null | cut -d= -f2- || true)"
FLUTTER_VERSION_CODE="$(grep '^flutter.versionCode=' android/local.properties 2>/dev/null | cut -d= -f2- || true)"
cat > android/local.properties <<LOCAL_PROPERTIES_EOF
sdk.dir=$ANDROID_HOME
flutter.sdk=$FLUTTER_ROOT
flutter.buildMode=release
flutter.versionName=${FLUTTER_VERSION_NAME:-1.0.0}
flutter.versionCode=${FLUTTER_VERSION_CODE:-1}
LOCAL_PROPERTIES_EOF

echo '=== 环境检查 ==='
flutter --version

echo '=== 拉取依赖 ==='
flutter pub get

echo '=== 开始构建 ==='
set +e
flutter build apk --release
BUILD_STATUS=$?
set -e

echo '=== 修复权限 (无论成功失败都会执行) ==='
chmod -R 777 /workspace/build /workspace/.dart_tool 2>/dev/null || true

exit $BUILD_STATUS
EOF
                '''
            }
        }

        stage('Publish to Gitea Release') {
            when {
                anyOf {
                    branch 'main'
                    expression { return env.BRANCH_NAME == null || env.BRANCH_NAME.trim().isEmpty() }
                }
            }
            steps {
                script {
                    if (!fileExists(env.APK_PATH)) {
                        error("APK 文件不存在: ${env.APK_PATH}")
                    }

                    def createReleaseJson = groovy.json.JsonOutput.toJson([
                        tag_name: env.TAG_NAME,
                        target_commitish: env.TARGET_COMMITISH,
                        name: "Globi-V APP ${env.TAG_NAME}",
                        body: "由 Jenkins 自动生成",
                        draft: false,
                        prerelease: false,
                    ])

                    def response = sh(
                        script: """
                            curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases' \
                              -H 'Authorization: token ${env.GITEA_TOKEN}' \
                              -H 'Content-Type: application/json' \
                              -d '${createReleaseJson}'
                        """.stripIndent(),
                        returnStdout: true,
                    ).trim()

                    def props = new groovy.json.JsonSlurperClassic().parseText(response)
                    def releaseId = props.id
                    if (!releaseId) {
                        error("创建 Gitea Release 失败，响应内容: ${response}")
                    }

                    sh """
                        curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases/${releaseId}/assets' \
                          -H 'Authorization: token ${env.GITEA_TOKEN}' \
                          -H 'Accept: application/json' \
                          -F 'attachment=@${env.APK_PATH}'
                    """.stripIndent()
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', allowEmptyArchive: true
            sh '''
            echo "清理工作空间冗余文件..."
            rm -rf build/ .dart_tool/
            '''
        }
    }
}