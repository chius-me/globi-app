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
    }

    stages {
        stage('Docker Build APK') {
            steps {
                // 使用原生的 docker run 命令
                // 结合了国内镜像源、持久化缓存挂载，极大提升二次构建速度
                sh '''
                echo "启动 Flutter 编译容器..."
                docker run --rm \\
                  -v "${WORKSPACE}:/workspace" \\
                  -v "/var/lib/jenkins/.gradle_cache:/root/.gradle" \\
                  -v "/var/lib/jenkins/.pub_cache:/root/.pub-cache" \\
                  -e PUB_HOSTED_URL='https://pub.flutter-io.cn' \\
                  -e FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn' \\
                  -w /workspace \\
                  ghcr.io/cirruslabs/flutter:stable \\
                  bash -c "
                    echo '=== 环境检查 ===' &&
                    flutter --version &&
                    
                    echo '=== 拉取依赖 ===' &&
                    flutter pub get &&
                    
                    echo '=== 开始构建 ===' &&
                    flutter build apk --release &&
                    
                    echo '=== 修复权限 ===' &&
                    chmod -R 777 /workspace/build /workspace/.dart_tool
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

                    // 准备 Release 信息
                    def createReleaseJson = groovy.json.JsonOutput.toJson([
                        tag_name: env.TAG_NAME,
                        target_commitish: env.TARGET_COMMITISH,
                        name: "自动构建版本 ${env.TAG_NAME}",
                        body: "由 Jenkins 原生 Docker 脚本自动生成。",
                        draft: false,
                        prerelease: false,
                    ])

                    // 创建 Release
                    def response = sh(
                        script: """
                            curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases' \
                              -H 'Authorization: token ${env.GITEA_TOKEN}' \
                              -H 'Content-Type: application/json' \
                              -d '${createReleaseJson}'
                        """.stripIndent(),
                        returnStdout: true,
                    ).trim()

                    // 解析 Release ID（你在上一步已经通过了脚本安全审批，这里会直接放行）
                    def props = new groovy.json.JsonSlurperClassic().parseText(response)
                    def releaseId = props.id
                    if (!releaseId) {
                        error("创建 Gitea Release 失败，响应内容: ${response}")
                    }

                    // 上传 APK 附件
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
            // 1. 将构建产物归档到 Jenkins 面板，方便直接下载
            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', allowEmptyArchive: true
            
            // 2. 阅后即焚：清理占用磁盘极大的编译缓存目录，保持宿主机干净
            sh '''
            echo "清理工作空间冗余文件..."
            rm -rf build/ .dart_tool/
            '''
        }
    }
}