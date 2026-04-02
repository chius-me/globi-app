stage('Publish to Gitea Release') {
    environment {
        // 在 Jenkins 凭据管理中添加 GITEA_TOKEN
        GITEA_TOKEN = credentials('gitea-api-token')
        GITEA_URL = "https://git.tamochi.cn"
        REPO_OWNER = "chius"
        REPO_NAME = "globi-mobile"
        TAG_NAME = "v${env.BUILD_NUMBER}" // 使用构建号作为版本号
        TARGET_COMMITISH = "${env.BRANCH_NAME ?: 'main'}"
        APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
    }
    steps {
        script {
            if (!fileExists(env.APK_PATH)) {
                error("APK 文件不存在: ${env.APK_PATH}，请先执行 flutter build apk --release")
            }

            // 1. 创建 Release 版本
            def createReleaseJson = groovy.json.JsonOutput.toJson([
                tag_name: TAG_NAME,
                target_commitish: TARGET_COMMITISH,
                name: "自动构建版本 ${TAG_NAME}",
                body: "由 Jenkins 自动生成的构建版本。",
                draft: false,
                prerelease: false,
            ])
            
            def response = sh(script: """
                curl --fail --silent --show-error -X POST "${GITEA_URL}/api/v1/repos/${REPO_OWNER}/${REPO_NAME}/releases" \
                -H "Authorization: token ${GITEA_TOKEN}" \
                -H "Content-Type: application/json" \
                -d '${createReleaseJson}'
            """, returnStdout: true).trim()

            def props = new groovy.json.JsonSlurperClassic().parseText(response)
            def releaseId = props.id

            if (!releaseId) {
                error("创建 Gitea Release 失败，未获取到 release id。响应内容: ${response}")
            }

            // 2. 上传 APK 附件
            sh """
                curl --fail --silent --show-error -X POST "${GITEA_URL}/api/v1/repos/${REPO_OWNER}/${REPO_NAME}/releases/${releaseId}/attachments" \
                -H "Authorization: token ${GITEA_TOKEN}" \
                -H "Accept: application/json" \
                -F "attachment=@${APK_PATH}"
            """
        }
    }
}