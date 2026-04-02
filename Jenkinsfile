pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
    }

    environment {
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = 'http://10.0.0.131:3000'
        REPO_OWNER = 'chius'
        REPO_NAME = 'globi-mobile'
        TAG_NAME = "v${env.BUILD_NUMBER}"
        TARGET_COMMITISH = "${env.BRANCH_NAME ?: 'main'}"
        APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
    }

    stages {
        stage('Docker Build APK') {
            steps {
                sh '''
                echo "启动 Flutter 编译容器..."
                docker run --rm \\
                  -v "${WORKSPACE}:/workspace" \\
                  -v "/var/lib/jenkins/.gradle_cache:/root/.gradle" \\
                  -v "/var/lib/jenkins/.pub_cache:/root/.pub-cache" \\
                  -e HTTP_PROXY="http://Clash:AYmOkhoZ@10.0.0.1:7890" \\
                  -e HTTPS_PROXY="http://Clash:AYmOkhoZ@10.0.0.1:7890" \\
                  -e PUB_HOSTED_URL='https://pub.flutter-io.cn' \\
                  -e FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn' \\
                  -w /workspace \\
                  ghcr.io/cirruslabs/flutter:stable \\
                  bash -c "
                    echo '=== 强制配置 Java/Gradle 专属代理 ==='
                    mkdir -p /root/.gradle
                    cat <<EOF > /root/.gradle/gradle.properties
systemProp.http.proxyHost=10.0.0.1
systemProp.http.proxyPort=7890
systemProp.http.proxyUser=Clash
systemProp.http.proxyPassword=AYmOkhoZ
systemProp.https.proxyHost=10.0.0.1
systemProp.https.proxyPort=7890
systemProp.https.proxyUser=Clash
systemProp.https.proxyPassword=AYmOkhoZ
systemProp.jdk.http.auth.tunneling.disabledSchemes=
EOF

                    echo '=== 环境检查 ==='
                    flutter --version
                    
                    echo '=== 拉取依赖 ==='
                    flutter pub get
                    
                    echo '=== 开始构建 ==='
                    flutter build apk --release
                    
                    BUILD_STATUS=\\$?
                    
                    echo '=== 修复权限 (无论成功失败都会执行) ==='
                    chmod -R 777 /workspace/build /workspace/.dart_tool 2>/dev/null || true
                    
                    exit \\$BUILD_STATUS
                  "
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