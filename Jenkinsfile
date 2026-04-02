pipeline {
    agent {
        docker {
            // 官方社区维护的镜像，内置了最新的 Flutter Stable 版本和 Android SDK / JDK
            image 'cirruslabs/flutter:stable'
            // 以 root 用户运行，避免 Jenkins 挂载工作目录时出现权限问题
            args '-u root'
        }
    }

    options {
        timestamps()
    }

    environment {
        // Gitea 凭据及变量保持不变
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = 'https://git.tamochi.cn'
        REPO_OWNER = 'chius'
        REPO_NAME = 'globi-mobile'
        TAG_NAME = "v${env.BUILD_NUMBER}"
        TARGET_COMMITISH = "${env.BRANCH_NAME ?: 'main'}"
        APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
    }

    stages {
        stage('Prepare Environment') {
            steps {
                // 直接使用 flutter 命令，顺便打印下环境信息方便排查问题
                sh 'flutter --version'
                sh 'flutter doctor -v'
            }
        }

        stage('Dependencies') {
            steps {
                sh 'flutter pub get'
            }
        }

        stage('Analyze') {
            steps {
                sh 'flutter analyze'
            }
        }

        stage('Test') {
            steps {
                sh 'flutter test'
            }
        }

        stage('Build Release APK') {
            steps {
                sh 'flutter build apk --release'
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
                        body: "由 Jenkins Docker 容器自动生成的构建版本。",
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
                        error("创建 Gitea Release 失败，未获取到 release id。响应内容: ${response}")
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
            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk', allowEmptyArchive: true
        }
    }
}