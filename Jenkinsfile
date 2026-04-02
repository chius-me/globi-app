pipeline {
    agent any

    parameters {
        string(name: 'FLUTTER_HOME', defaultValue: '/opt/flutter', description: 'Flutter SDK 根目录，例如 /opt/flutter 或 C:/src/flutter')
    }

    options {
        timestamps()
    }

    environment {
        FLUTTER_CHANNEL = 'stable'
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = 'https://git.tamochi.cn'
        REPO_OWNER = 'chius'
        REPO_NAME = 'globi-mobile'
        TAG_NAME = "v${env.BUILD_NUMBER}"
        TARGET_COMMITISH = "${env.BRANCH_NAME ?: 'main'}"
        APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    def flutterCommand = isUnix()
                        ? "${params.FLUTTER_HOME}/bin/flutter"
                        : "${params.FLUTTER_HOME}\\bin\\flutter.bat"

                    env.FLUTTER_CMD = flutterCommand

                    if (isUnix()) {
                        if (!fileExists(flutterCommand)) {
                            error("未找到 Flutter SDK，请检查 Jenkins 参数 FLUTTER_HOME。当前路径: ${flutterCommand}")
                        }
                        sh "'${env.FLUTTER_CMD}' --version"
                    } else {
                        if (!fileExists(flutterCommand)) {
                            error("未找到 Flutter SDK，请检查 Jenkins 参数 FLUTTER_HOME。当前路径: ${flutterCommand}")
                        }
                        pwsh "& '${env.FLUTTER_CMD}' --version"
                    }
                }
            }
        }

        stage('Dependencies') {
            steps {
                script {
                    if (isUnix()) {
                        sh "'${env.FLUTTER_CMD}' pub get"
                    } else {
                        pwsh "& '${env.FLUTTER_CMD}' pub get"
                    }
                }
            }
        }

        stage('Analyze') {
            steps {
                script {
                    if (isUnix()) {
                        sh "'${env.FLUTTER_CMD}' analyze"
                    } else {
                        pwsh "& '${env.FLUTTER_CMD}' analyze"
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    if (isUnix()) {
                        sh "'${env.FLUTTER_CMD}' test"
                    } else {
                        pwsh "& '${env.FLUTTER_CMD}' test"
                    }
                }
            }
        }

        stage('Build Release APK') {
            steps {
                script {
                    if (isUnix()) {
                        sh "'${env.FLUTTER_CMD}' build apk --release"
                    } else {
                        pwsh "& '${env.FLUTTER_CMD}' build apk --release"
                    }
                }
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
                        name: "自动构建版本 ${env.TAG_NAME}",
                        body: "由 Jenkins 自动生成的构建版本。",
                        draft: false,
                        prerelease: false,
                    ])

                    def response
                    if (isUnix()) {
                        response = sh(
                            script: """
                                curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases' \
                                  -H 'Authorization: token ${env.GITEA_TOKEN}' \
                                  -H 'Content-Type: application/json' \
                                  -d '${createReleaseJson}'
                            """.stripIndent(),
                            returnStdout: true,
                        ).trim()
                    } else {
                        def payload = createReleaseJson.replace("'", "''")
                        response = pwsh(
                            script: """
                                curl.exe --fail --silent --show-error -X POST "${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases" `
                                  -H "Authorization: token ${env.GITEA_TOKEN}" `
                                  -H "Content-Type: application/json" `
                                  -d '${payload}'
                            """.stripIndent(),
                            returnStdout: true,
                        ).trim()
                    }

                    def props = new groovy.json.JsonSlurperClassic().parseText(response)
                    def releaseId = props.id
                    if (!releaseId) {
                        error("创建 Gitea Release 失败，未获取到 release id。响应内容: ${response}")
                    }

                    if (isUnix()) {
                        sh """
                            curl --fail --silent --show-error -X POST '${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases/${releaseId}/attachments' \
                              -H 'Authorization: token ${env.GITEA_TOKEN}' \
                              -H 'Accept: application/json' \
                              -F 'attachment=@${env.APK_PATH}'
                        """.stripIndent()
                    } else {
                        pwsh """
                            curl.exe --fail --silent --show-error -X POST "${env.GITEA_URL}/api/v1/repos/${env.REPO_OWNER}/${env.REPO_NAME}/releases/${releaseId}/attachments" `
                              -H "Authorization: token ${env.GITEA_TOKEN}" `
                              -H "Accept: application/json" `
                              -F "attachment=@${env.APK_PATH}"
                        """.stripIndent()
                    }
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