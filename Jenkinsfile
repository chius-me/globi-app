pipeline {
    agent any

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
                    if (isUnix()) {
                        sh 'flutter --version'
                    } else {
                        pwsh 'flutter --version'
                    }
                }
            }
        }

        stage('Dependencies') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'flutter pub get'
                    } else {
                        pwsh 'flutter pub get'
                    }
                }
            }
        }

        stage('Analyze') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'flutter analyze'
                    } else {
                        pwsh 'flutter analyze'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'flutter test'
                    } else {
                        pwsh 'flutter test'
                    }
                }
            }
        }

        stage('Build Release APK') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'flutter build apk --release'
                    } else {
                        pwsh 'flutter build apk --release'
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