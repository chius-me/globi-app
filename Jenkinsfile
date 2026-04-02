pipeline {
    agent any // 回归宿主机执行

    options {
        timestamps()
    }

    environment {
        // Gitea 凭据及变量
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = 'https://git.tamochi.cn'
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
                // 注意这里使用的是单引号 '''，这样 $WORKSPACE 会被当做宿主机 shell 环境变量处理
                sh '''
                echo "启动 Flutter 编译容器..."
                docker run --rm \\
                  -v "${WORKSPACE}:/workspace" \\
                  -w /workspace \\
                  ghcr.io/cirruslabs/flutter:stable \\
                  bash -c "
                    echo '=== 环境检查 ===' &&
                    flutter --version &&
                    
                    echo '=== 拉取依赖 ===' &&
                    flutter pub get &&
                    
                    echo '=== 开始构建 ===' &&
                    flutter build apk --release -v &&
                    
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

                    // 解析 Release ID
                    def props = new groovy.json.JsonSlurperClassic().parseText(response)
                    def releaseId = props.id
                    if (!releaseId) {
                        error("创建 Gitea Release 失败，响应内容: ${response}")
                    }

                    // 上传 APK 附件
                    sh """
                        curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases/${releaseId}/attachments' \
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
            // 归档产物，现在宿主机有权限读取这些文件了
            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', allowEmptyArchive: true
        }
    }
}