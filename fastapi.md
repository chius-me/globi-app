# FastAPI 标准对接文档

本文档给 Flutter 前端使用，描述当前 `globi-server` 后端已经提供和将稳定维护的接口契约。

目标：

- 前端严格按本文档对接，不自行改路径、字段名或错误结构。
- 本文档以当前后端代码为准。
- 后续新增接口也应继续补充到本文档。

## 1. 基础信息

### 1.1 当前后端地址

- `https://server.globi.lan.tamochi.cn`

### 1.2 当前接口分组

1. 健康检查
2. 认证接口
3. 盲人模式助手接口
4. 家属与盲人绑定接口
5. 盲人定位接口

### 1.3 当前后端关键能力

- Authentik OIDC 认证
- 盲人模式助手匿名可用
- 家属登录后可生成盲人绑定授权码
- 盲人首次输入授权码完成绑定
- 盲人绑定成功后获得独立访问凭证，后续进入盲人模式无需再次输入授权码
- 盲人可上报手机定位
- 对应授权家属可查看该盲人的最新精准定位

## 2. 统一约束

### 2.1 返回格式

- 普通成功接口返回 JSON
- `text-to-speech` 成功时返回二进制音频流

### 2.2 错误格式

除 2xx 成功外，错误统一返回：

```json
{
  "detail": {
    "code": "assistant_unavailable",
    "message": "语音助手暂时不可用，请稍后再试。",
    "retryable": true
  }
}
```

字段说明：

- `detail.code`: 机器可读错误码
- `detail.message`: 给前端展示的中文文案
- `detail.retryable`: 是否建议用户重试

Flutter 错误展示优先读取：

1. `detail.message`
2. `detail`
3. `message`

### 2.3 时间格式

- 所有时间字段统一使用 ISO 8601 UTC 字符串

### 2.4 认证方式

本项目有两类 Bearer token：

1. 家属登录态 token
2. 盲人绑定后的 blind access token

家属登录态 token：

- 来源于 `/api/auth/token` 或 `/api/auth/refresh`
- 只用于家属模式相关接口

盲人 blind access token：

- 来源于 `/api/blind/link`
- 只用于盲人绑定身份与定位上传相关接口

前端不要混用这两类 token。

## 3. 健康检查接口

### 3.1 GET /api/health/live

成功响应：

```json
{
  "status": "ok"
}
```

### 3.2 GET /api/health/ready

成功响应示例：

```json
{
  "status": "ok",
  "services": {
    "postgres": {
      "status": "ok",
      "latency_ms": 0.89
    },
    "redis": {
      "status": "ok",
      "latency_ms": 0.25,
      "pong": true
    }
  }
}
```

失败时：

- 状态码：`503`
- `status` 为 `degraded`

## 4. 认证接口

这组接口供家属模式使用。

### 4.1 GET /api/auth/config

成功响应示例：

```json
{
  "issuer": "https://auth.lan.tamochi.cn/application/o/globi/",
  "discovery_url": "https://auth.lan.tamochi.cn/application/o/globi/.well-known/openid-configuration",
  "client_id": "PsCobM1MdPegN77u8mUfJIkycrXadMX5duX4v4Y4",
  "audience": null,
  "scopes": ["openid", "profile", "email", "offline_access"],
  "response_type": "code",
  "code_challenge_method": "S256",
  "token_endpoint_auth_method": "none",
  "authorization_endpoint": "https://auth.lan.tamochi.cn/application/o/authorize/",
  "token_endpoint": "https://auth.lan.tamochi.cn/application/o/token/",
  "userinfo_endpoint": "https://auth.lan.tamochi.cn/application/o/userinfo/",
  "revocation_endpoint": "https://auth.lan.tamochi.cn/application/o/revoke/",
  "end_session_endpoint": "https://auth.lan.tamochi.cn/application/o/globi/end-session/",
  "jwks_uri": "https://auth.lan.tamochi.cn/application/o/globi/jwks/"
}
```

### 4.2 POST /api/auth/authorize-url

请求体：

```json
{
  "redirect_uri": "flutty://login-callback",
  "state": "<random_state>",
  "code_challenge": "<pkce_code_challenge>",
  "code_challenge_method": "S256",
  "scope": "openid profile email offline_access",
  "nonce": "<random_nonce>",
  "prompt": "login"
}
```

响应：

```json
{
  "authorization_url": "string"
}
```

### 4.3 POST /api/auth/token

请求体：

```json
{
  "code": "<authorization_code>",
  "redirect_uri": "flutty://login-callback",
  "code_verifier": "<original_pkce_code_verifier>"
}
```

响应：

```json
{
  "access_token": "string",
  "token_type": "Bearer",
  "expires_in": 3600,
  "expires_at": 1712345678,
  "refresh_token": "string | null",
  "id_token": "string | null",
  "scope": "string | null"
}
```

### 4.4 POST /api/auth/refresh

请求体：

```json
{
  "refresh_token": "<refresh_token>"
}
```

响应结构与 `/api/auth/token` 相同。

### 4.5 POST /api/auth/logout

请求体：

```json
{
  "refresh_token": "<optional>",
  "id_token": "<optional>",
  "post_logout_redirect_uri": "<optional>"
}
```

响应：

```json
{
  "revoked": true,
  "end_session_url": "string | null"
}
```

### 4.6 GET /api/auth/me

请求头：

```text
Authorization: Bearer <family_access_token>
```

响应：

```json
{
  "sub": "string | null",
  "preferred_username": "string | null",
  "name": "string | null",
  "email": "string | null",
  "email_verified": true,
  "picture": "string | null",
  "source": "userinfo | token",
  "claims": { "...": "..." },
  "userinfo": { "...": "..." } | null
}
```

### 4.7 GET /api/private

请求头：

```text
Authorization: Bearer <family_access_token>
```

响应示例：

```json
{
  "message": "鉴权成功",
  "user_info": { "...": "..." }
}
```

## 5. 盲人模式助手接口

这组接口默认匿名可用，不依赖家属登录态。

### 5.1 POST /api/assistant/sessions

请求体：

```json
{
  "mode": "blind",
  "client": "flutter",
  "locale": "zh-CN"
}
```

成功响应示例：

```json
{
  "session_id": "asst_sess_xxx",
  "created_at": "2026-04-01T11:19:59.514626Z",
  "expires_in": 7200,
  "mode": "blind",
  "locale": "zh-CN",
  "greeting": "你好，我是 Globi 助手。你可以直接问我问题。",
  "capabilities": {
    "text_chat": true,
    "speech_to_text": true,
    "text_to_speech": true
  }
}
```

### 5.2 POST /api/assistant/chat

请求体：

```json
{
  "session_id": "asst_sess_xxx",
  "message": "请用两句话介绍一下西湖，适合语音朗读。",
  "input_type": "text",
  "mode": "blind",
  "expect_voice_friendly": true
}
```

成功响应示例：

```json
{
  "session_id": "asst_sess_xxx",
  "assistant_message": {
    "id": "msg_xxx",
    "role": "assistant",
    "text": "西湖位于杭州，湖光山色秀丽，是江南著名的游览胜地。您可以去湖边漫步，感受微风拂面与鸟语花香的宁静氛围。",
    "created_at": "2026-04-01T11:20:15.983591Z"
  },
  "suggestions": ["帮我换一种更简单的说法", "请再简短一点"],
  "usage": {
    "prompt_tokens": 130,
    "completion_tokens": 881,
    "total_tokens": 1011
  },
  "trace_id": "chatcmpl-xxx"
}
```

### 5.3 POST /api/assistant/speech-to-text

请求格式：

- `multipart/form-data`

表单字段：

- `session_id`: 必填
- `mode`: 必填，固定 `blind`
- `locale`: 可选，默认 `zh-CN`
- `audio_format`: 必填，例如 `wav`、`mp3`、`m4a`、`webm`
- `audio`: 必填，文件字段名固定为 `audio`

成功响应：

```json
{
  "session_id": "asst_sess_xxx",
  "transcript": "帮我给家属发一条消息，说我已经到家了",
  "duration_ms": 4280,
  "detected_locale": "zh-CN",
  "trace_id": "trace_xxx"
}
```

### 5.4 POST /api/assistant/text-to-speech

请求体：

```json
{
  "session_id": "asst_sess_xxx",
  "text": "你好，这是 Globi 语音助手的连通性测试。",
  "voice": "longxiaochun_v3",
  "format": "mp3",
  "speaking_rate": 1.0
}
```

成功响应：

- HTTP `200`
- `Content-Type: audio/mpeg` 或 `audio/wav`
- Body 为音频二进制
- 当前会附加 `X-Trace-Id`

## 6. 新功能一：家属授权盲人绑定

目标：

1. 家属登录后，在家属模式内生成授权码
2. 盲人首次进入盲人模式时输入授权码
3. 后端完成绑定后返回盲人访问凭证
4. Flutter 本地持久化该盲人访问凭证
5. 后续盲人再次打开 App，无需重新输入授权码

### 6.1 设计原则

- 绑定关系持久化存储在 PostgreSQL
- 授权码是一次性、短时有效码
- 授权码只能使用一次
- 盲人完成首次绑定后，会获得一个独立的 `blind_access_token`
- 后续盲人身份请求只使用 `blind_access_token`
- 家属只能看到自己授权过的盲人用户

### 6.2 家属生成授权码

#### POST /api/family/blind-link-codes

请求头：

```text
Authorization: Bearer <family_access_token>
Content-Type: application/json
```

请求体：

```json
{
  "blind_user_name": "张三"
}
```

字段说明：

- `blind_user_name`: 必填，建议用于家属侧标识这个盲人用户

成功响应示例：

```json
{
  "authorization_code": "ABCD-7KQ9",
  "blind_user_name": "张三",
  "expires_at": "2026-04-02T12:00:00Z",
  "expires_in": 600
}
```

行为要求：

- 授权码默认 10 分钟内有效
- 授权码只能使用一次
- 前端应清晰展示过期时间或倒计时

常见错误码：

- `invalid_token`
- `family_token_missing`
- `invalid_request`
- `blind_link_unavailable`

### 6.3 盲人首次绑定

#### POST /api/blind/link

请求头：

- `Content-Type: application/json`

请求体：

```json
{
  "authorization_code": "ABCD-7KQ9",
  "device_label": "Xiaomi 14 Blind"
}
```

字段说明：

- `authorization_code`: 必填，家属端生成的一次性授权码
- `device_label`: 可选，盲人设备名称，便于家属辨认

成功响应示例：

```json
{
  "blind_user_id": "blind_user_123456",
  "blind_user_name": "张三",
  "family_display_name": "李四",
  "linked_at": "2026-04-02T12:01:03Z",
  "blind_access_token": "blind_xxxxxxxxxxxxxxxxx",
  "token_type": "Bearer",
  "device_label": "Xiaomi 14 Blind"
}
```

前端要求：

- 成功后必须安全持久化 `blind_access_token`
- 后续盲人进入盲人模式时，不再要求输入授权码
- 后续盲人模式下的身份确认和定位上传，都使用这个 token

常见错误码：

- `authorization_code_invalid`
- `authorization_code_used`
- `authorization_code_expired`
- `invalid_request`
- `blind_link_unavailable`

### 6.4 盲人身份确认

#### GET /api/blind/me

请求头：

```text
Authorization: Bearer <blind_access_token>
```

成功响应示例：

```json
{
  "blind_user_id": "blind_user_123456",
  "blind_user_name": "张三",
  "family_display_name": "李四",
  "device_label": "Xiaomi 14 Blind",
  "linked_at": "2026-04-02T12:01:03Z",
  "last_seen_at": "2026-04-02T12:05:00Z",
  "last_location_at": "2026-04-02T12:04:20Z"
}
```

前端用途：

- App 启动时检查本地是否已有 `blind_access_token`
- 如果有，则调用 `/api/blind/me`
- 成功就直接进入盲人界面
- 如果返回 401，则清除本地 blind token，回到“输入授权码”流程

常见错误码：

- `blind_token_missing`
- `blind_token_invalid`
- `blind_link_unavailable`

## 7. 新功能二：盲人定位上传与家属查看

目标：

1. 盲人端周期性采集手机定位
2. 上传后端保存最新定位
3. 对应授权家属可以查看该盲人用户的精准位置

### 7.1 实现选择

当前后端实现使用 PostgreSQL 保存最新定位，原因：

- 绑定关系和定位需要跨重启稳定保留
- 查询模型简单，直接持久化更实用
- 目前每个盲人只保存“最新一条定位”，避免设计过重

### 7.2 盲人上传定位

#### POST /api/blind/location

请求头：

```text
Authorization: Bearer <blind_access_token>
Content-Type: application/json
```

请求体：

```json
{
  "latitude": 30.274084,
  "longitude": 120.15507,
  "accuracy_meters": 8.5,
  "altitude_meters": 15.2,
  "speed_mps": 0.6,
  "heading_degrees": 182.0,
  "provider": "gps",
  "captured_at": "2026-04-02T12:10:22Z"
}
```

字段说明：

- `latitude`: 必填，范围 `-90` 到 `90`
- `longitude`: 必填，范围 `-180` 到 `180`
- `accuracy_meters`: 可选，定位精度，单位米
- `altitude_meters`: 可选，海拔，单位米
- `speed_mps`: 可选，速度，单位米每秒
- `heading_degrees`: 可选，朝向，范围 `0` 到 `360`
- `provider`: 可选，例如 `gps`、`network`、`fused`
- `captured_at`: 可选，采集时间；不传则由后端按接收时间处理

成功响应示例：

```json
{
  "blind_user_id": "blind_user_123456",
  "recorded_at": "2026-04-02T12:10:22Z",
  "updated_at": "2026-04-02T12:10:24Z"
}
```

行为要求：

- 当前只保存该盲人用户的最新一条定位
- 新位置会覆盖旧位置
- 同时更新该盲人用户的 `last_seen_at` 和 `last_location_at`

常见错误码：

- `blind_token_missing`
- `blind_token_invalid`
- `invalid_request`
- `location_unavailable`

### 7.3 家属获取已绑定盲人用户列表

#### GET /api/family/blind-users

请求头：

```text
Authorization: Bearer <family_access_token>
```

成功响应示例：

```json
{
  "blind_users": [
    {
      "blind_user_id": "blind_user_123456",
      "blind_user_name": "张三",
      "device_label": "Xiaomi 14 Blind",
      "linked_at": "2026-04-02T12:01:03Z",
      "last_seen_at": "2026-04-02T12:11:00Z",
      "last_location_at": "2026-04-02T12:10:22Z",
      "latest_location": {
        "latitude": 30.274084,
        "longitude": 120.15507,
        "accuracy_meters": 8.5,
        "altitude_meters": 15.2,
        "speed_mps": 0.6,
        "heading_degrees": 182.0,
        "provider": "gps",
        "captured_at": "2026-04-02T12:10:22Z",
        "updated_at": "2026-04-02T12:10:24Z"
      }
    }
  ]
}
```

用途：

- 家属模式首页展示自己已授权的盲人用户列表
- 同时展示最近定位和在线感知信息

### 7.4 家属获取单个盲人用户详情

#### GET /api/family/blind-users/{blind_user_id}

请求头：

```text
Authorization: Bearer <family_access_token>
```

成功响应结构与 `blind_users[]` 单项一致。

### 7.5 家属获取单个盲人用户定位

#### GET /api/family/blind-users/{blind_user_id}/location

请求头：

```text
Authorization: Bearer <family_access_token>
```

成功响应示例：

```json
{
  "blind_user_id": "blind_user_123456",
  "blind_user_name": "张三",
  "latest_location": {
    "latitude": 30.274084,
    "longitude": 120.15507,
    "accuracy_meters": 8.5,
    "altitude_meters": 15.2,
    "speed_mps": 0.6,
    "heading_degrees": 182.0,
    "provider": "gps",
    "captured_at": "2026-04-02T12:10:22Z",
    "updated_at": "2026-04-02T12:10:24Z"
  }
}
```

如果该盲人用户当前还没有上传过定位：

```json
{
  "blind_user_id": "blind_user_123456",
  "blind_user_name": "张三",
  "latest_location": null
}
```

常见错误码：

- `family_token_missing`
- `invalid_token`
- `blind_user_not_found`
- `location_unavailable`

## 8. 前端实现建议

### 8.1 家属侧授权流程

1. 家属按现有 Authentik 流程登录
2. 进入家属主页
3. 调 `POST /api/family/blind-link-codes`
4. 将返回的 `authorization_code` 展示给盲人用户
5. 过期后可重新生成

### 8.2 盲人首次进入流程

1. 盲人首次打开 App 进入盲人模式
2. 检查本地是否存在 `blind_access_token`
3. 若不存在，展示授权码输入页
4. 调 `POST /api/blind/link`
5. 成功后保存 `blind_access_token`
6. 进入盲人模式主页

### 8.3 盲人后续进入流程

1. App 启动时读取本地 `blind_access_token`
2. 调 `GET /api/blind/me`
3. 成功则直接进入盲人模式主页
4. 若 401，则清除本地 blind token，重新要求输入授权码

### 8.4 盲人定位上传流程

1. 盲人侧获取手机定位权限
2. 进入盲人模式后定时采集定位
3. 调 `POST /api/blind/location`
4. 建议在以下场景上传：
   - 首次进入盲人主页
   - 前台持续使用中按固定周期上传
   - 位移明显变化时上传

### 8.5 家属查看定位流程

1. 家属登录后调 `GET /api/family/blind-users`
2. 在列表中展示已授权盲人用户
3. 点击某个盲人用户后调 `GET /api/family/blind-users/{blind_user_id}/location`
4. 在地图或定位页展示精准位置

## 9. 数据持久化说明

当前后端实现：

- PostgreSQL 持久化以下数据：
  - 绑定授权码
  - 家属与盲人绑定关系
  - 盲人访问凭证摘要
  - 盲人用户最新定位

没有把这部分主数据只放 Redis，原因是：

- Redis 更适合短期缓存和会话
- 绑定关系与定位属于关键业务数据
- PostgreSQL 更适合跨重启持久化

## 10. 新功能验收标准

后端完成后，前端联调至少应满足：

1. 家属登录后能成功生成授权码
2. 授权码可被盲人首次绑定成功使用
3. 同一授权码不能重复使用
4. 过期授权码会返回明确错误码
5. 盲人绑定成功后能拿到 `blind_access_token`
6. 盲人再次进入 App 时无需重新输入授权码
7. 盲人能成功上传定位
8. 家属能看到自己已授权盲人用户的最新定位
9. 家属不能查看未授权盲人用户的定位
10. 所有错误都能稳定返回统一 JSON 结构

## 11. 当前后端对应模块

如需查看后端实现，当前相关代码位于：

- `app/auth/`
- `app/assistant/`
- `app/linking/`
- `app/system/routes.py`
- `app/core/config.py`
- `app/core/lifecycle.py`

前端只要严格按本文档路径、字段和错误格式实现，就可以与当前后端直接联调。
