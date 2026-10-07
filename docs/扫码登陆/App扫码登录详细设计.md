# App 扫码登录详细设计

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 功能名称 | PC 端 App 扫码登录 |
| 文档状态 | 待确认设计 |
| 适用端 | PC Web、Android App、鸿蒙 App；iOS 按同一业务协议实现 |
| 关联代码 | `frontend/src/pages/LoginPage.tsx`、`frontend/src/api/auth.ts`、`flutter_app/lib/screens/chat_screen.dart`、`flutter_app/lib/router/app_router.dart`、`backend/routers/auth.py` |
| 设计日期 | 2026-09-13 |

本文只描述设计，不包含代码实现。产品、交互、安全和接口方案确认后再进入开发。

## 2. 需求目标

用户在 PC 登录页选择“App 扫码登录”，PC 展示一次性二维码；用户在已登录的 App 中打开左侧导航“扫一扫”，扫描二维码并在 App 内确认；确认成功后 PC 自动登录并进入 `/chat`。

目标包括：

1. 不要求用户在 PC 输入手机号和短信验证码。
2. 扫码登录必须经过 App 已登录用户的明确确认，不能仅凭识别二维码自动登录。
3. 二维码短时有效、单次使用、不可复用；过期、取消、拒绝和异常状态均有明确提示。
4. PC、App 和后端复用现有用户体系、JWT 签发逻辑和审计日志能力。
5. 未登录 App 扫码时，允许先去 App 登录；登录成功后需要重新扫描，避免跨页面长期保存二维码凭证。

## 3. 当前现状与改造边界

### 3.1 已有能力

- PC `LoginPage` 已有 `qrcode` Tab，但当前仅显示二维码图标占位和“功能开发中”文案。
- PC 现有短信登录调用 `/api/auth/send_code`、`/api/auth/login/sms`，登录成功后将 JWT 写入 `localStorage.token` 并跳转 `/chat`。
- Flutter App 使用 `AuthProvider` 管理登录态，`ApiService` 统一封装 Dio 请求，App 端请求头使用 `X-Client-Terminal: app`。
- App 的 `ChatScreen._buildSidebar` 同时作为宽屏左侧栏和窄屏 Drawer，适合增加“扫一扫”入口。
- 后端使用 FastAPI、SQLAlchemy、Redis/FakeRedis 和 JWT；`backend/routers/auth.py` 已集中承载认证接口。

### 3.2 本次不做

- 不改变现有短信登录、运营商一键登录和 JWT 格式。
- 不通过二维码直接传输手机号、密码、JWT 或其他个人隐私数据。
- 不实现 PC 与 App 的设备绑定、免密长期授权或“记住此设备”。
- 扫码登录入口放在已登录 App 的导航中；未登录用户若通过深链或其他入口进入扫描页，统一提示“请先登录 App”。

## 4. 总体方案

采用“后端一次性扫码会话 + PC 短轮询 + App 扫描后确认”的方案。

```text
PC                         Backend/Redis                         App
 |  POST /qr/session              |                                |
 |<-- session_id, qr_payload,     |                                |
 |    pc_secret ------------------|                                |
 |  将 qr_payload 渲染为二维码    |                                |
 |                                |                                |
 |  GET /qr/session/{id}/status -->|                                |
 |  (每 2 秒，最多 60 秒)          |                                |
 |                                |<-- POST /qr/scan (token) -------|
 |                                |--> 返回待确认信息 -------------->|
 |                                |<-- POST /qr/confirm --------------|
 |<-- status=confirmed, JWT ------|                                |
 |  写 token，进入 /chat           |                                |
```

选择短轮询的原因：现有 PC 登录页和后端均为 HTTP 请求模式，短轮询实现简单、可在现有部署和反向代理下运行，扫码登录的并发量通常较低。后续若需要更强实时性，可将 PC 状态查询替换为 SSE，但不改变会话状态和接口语义。

## 5. 业务流程

### 5.1 PC 端展示二维码

1. 用户勾选用户协议/隐私政策后切换到“App 扫码登录” Tab。
2. Tab 激活时调用 `POST /api/auth/qr/session` 创建会话。
3. 后端生成随机 `session_id`、二维码凭证 `qr_token` 和仅供当前 PC 页面使用的 `pc_secret`。`qr_payload` 只包含 `session_id` 和 `qr_token`；`pc_secret` 不写入二维码、不写入 URL、不写入 localStorage。
4. PC 使用二维码组件渲染 `qr_payload`，显示“请使用 App 扫一扫”。
5. PC 以 2 秒间隔查询状态，页面离开、切换到短信登录或组件销毁时停止轮询并取消/放弃本地会话。
6. 页面显示 60 秒倒计时；二维码过期后停止轮询并显示“二维码已过期，请点击刷新”，不得自动刷新或自动生成新二维码。

### 5.2 App 端入口与扫描

1. 在 `ChatScreen._buildSidebar` 的功能入口区域增加“扫一扫”，图标使用 `Icons.qr_code_scanner_outlined`。
2. 宽屏显示在左侧栏；窄屏显示在 Drawer 中。点击后进入 `/scan`。
3. `/scan` 页面申请摄像头权限并打开扫码组件；首次拒绝权限时显示说明和“去系统设置”入口。
4. 扫描结果必须匹配约定的 URI scheme，例如：

   `hospital://pc-login?sid=<session_id>&qt=<qr_token>&v=1`

5. 对非本系统二维码显示“无法识别该二维码”，不向后端提交原始内容。
6. 对合法二维码调用 `POST /api/auth/qr/scan`。后端校验会话有效性后返回待确认信息：终端名称“PC 网页端”、创建时间、脱敏 IP/地点（如有可信信息）。
7. App 显示确认页/确认弹窗：
   - 标题：确认登录 PC 端
   - 说明：确认后将使用当前 App 账号登录 PC
   - 操作：`确认登录`、`取消`
8. 用户确认后调用 `POST /api/auth/qr/confirm`；成功后展示“登录成功”，返回上一页或关闭扫描页。
9. 用户取消调用 `POST /api/auth/qr/reject`，PC 显示“已取消本次登录”。

### 5.3 PC 端完成登录

1. PC 状态接口返回 `confirmed` 时获得一次性 access token。
2. PC 校验响应结构后写入现有 `localStorage.token`，停止轮询，提示“登录成功”，跳转 `/chat`。
3. 跳转前调用现有用户信息接口或直接进入现有鉴权流程；若 token 无效，清理 token 并提示重新扫码。
4. PC 页面刷新、关闭或网络中断不会泄漏 token；后端状态查询只返回 token 一次，之后再次查询返回无 token 的已消费状态。

## 6. 会话状态机

| 状态 | 说明 | 可转换到 |
| --- | --- | --- |
| `pending` | 已创建，等待 App 扫描 | `scanned`、`expired`、`cancelled` |
| `scanned` | App 已识别，等待用户确认 | `confirmed`、`rejected`、`expired` |
| `confirmed` | App 已确认，等待 PC 消费 token | `consumed` |
| `rejected` | App 明确拒绝 | 终态 |
| `cancelled` | PC 主动取消/放弃 | 终态 |
| `expired` | 超过有效期 | 终态 |
| `consumed` | PC 已取走 token | 终态 |

建议有效期：二维码创建后 60 秒；App 扫描后仍受原会话有效期限制，确认必须在剩余有效时间内完成。二维码过期后只能由 PC 用户手动点击刷新重新创建会话。

## 7. 接口设计

所有接口前缀为 `/api/auth/qr`。请求头必须携带 `X-Client-Terminal`，PC 为 `pc`，App 为 `app`。接口错误统一使用现有 FastAPI 错误结构 `{ "detail": "..." }`。

### 7.1 创建会话

`POST /api/auth/qr/session`

请求体：无。

响应：

```json
{
  "session_id": "01J...",
  "qr_payload": "hospital://pc-login?sid=...&qt=...&v=1",
  "pc_secret": "...",
  "expires_at": "2026-09-13T10:00:00+08:00",
  "poll_interval_seconds": 2
}
```

`qr_payload` 只包含随机会话标识和随机二维码凭证，不包含手机号、用户 ID、JWT。建议 `session_id` 使用不可猜测的 UUID/ULID，`qr_token` 和 `pc_secret` 均使用至少 32 字节随机值。`pc_secret` 仅保存在当前页面内存中，页面刷新后直接创建新会话。

### 7.2 PC 查询状态

`GET /api/auth/qr/session/{session_id}/status`

请求头：`X-QR-PC-Secret: <pc_secret>`。只凭 `session_id` 不允许查询状态，防止会话枚举后获取登录结果。

响应示例：

```json
{ "status": "pending", "expires_at": "2026-09-13T10:00:00+08:00" }
```

确认成功时仅允许第一次返回 token：

```json
{
  "status": "confirmed",
  "access_token": "...",
  "token_type": "bearer"
}
```

再次查询返回 `consumed`，不得重复返回 token。状态查询建议限流为每会话每秒不超过 2 次，并校验来源终端为 `pc`。PC 端应将 `pc_secret` 保存在 React state/ref 中，不进入 localStorage、URL、埋点或日志。

### 7.3 App 扫描

`POST /api/auth/qr/scan`

请求：

```json
{ "session_id": "01J...", "qr_token": "..." }
```

App 必须携带当前 App JWT。响应：

```json
{
  "status": "scanned",
  "session_id": "01J...",
  "terminal_name": "PC 网页端",
  "scanned_at": "2026-09-13T09:56:00+08:00",
  "confirm_expires_at": "2026-09-13T10:00:00+08:00"
}
```

扫描动作必须使用 Redis 原子状态变更：只有 `pending -> scanned` 的第一个请求成功，后续 App 返回“二维码已被其他设备处理”，不得覆盖已记录的用户。

### 7.4 App 确认/拒绝

`POST /api/auth/qr/confirm`

请求：

```json
{ "session_id": "01J...", "qr_token": "..." }
```

需要 App JWT；后端从 JWT 获取用户，不信任请求体传入的用户 ID。仅 `scanned` 状态允许确认，确认后生成与短信登录一致的 JWT，并暂存在 Redis 直到 PC 消费。

`POST /api/auth/qr/reject`

请求体同上，需要 App JWT。仅 `pending` 或 `scanned` 状态允许拒绝，处理成功后状态为 `rejected`。

### 7.5 PC 主动取消

`POST /api/auth/qr/session/{session_id}/cancel`

PC 创建会话后可调用；接口不需要登录，但必须携带 `X-QR-PC-Secret: <pc_secret>`。不允许把该凭证放在 URL 参数中；若未来改为 Cookie，必须使用 HttpOnly、Secure、SameSite 保护。

## 8. Redis 数据设计

建议不新增数据库表，扫码会话是短生命周期、一次性认证中间态，使用 Redis 更合适。

键建议如下：

```text
qr_login:{session_id}
  hash/json: qr_token_hash, pc_secret_hash, status, pc_created_at, scanned_at,
             confirmed_at, user_id, consumed_at, terminal
  TTL: 60 秒

qr_login_token:{session_id}
  string: 待 PC 消费的加密/签名 token 或一次性 token 引用
  TTL: 与会话一致
```

Redis 中不保存明文 `qr_token` 或 `pc_secret`；服务端保存哈希并使用常量时间比较。确认后可直接生成 access token，但要确保 access token 的 Redis 暂存 TTL 不超过会话 TTL，且只有持有正确 `pc_secret` 的原 PC 会话可以消费一次。

并发处理要求：`confirm`、`status consume` 使用 Redis 原子操作或 Lua 脚本，避免两个 PC 请求同时消费同一个 token。

## 9. 安全设计

1. **一次性与短时效**：二维码有效期 60 秒；`confirmed` token 只能被 PC 消费一次；任何终态均不可再次扫描/确认。
2. **不信任二维码内容**：App 只接受固定 scheme、固定 host 和版本字段；禁止把二维码内容拼接成 WebView 或外部 URL 打开。
3. **明确确认**：扫描仅进入待确认态，必须由当前 App 登录用户点击确认。
4. **用户绑定**：确认接口只使用 App JWT 对应用户；禁止客户端传入任意 user ID。
5. **终端隔离**：接口检查 `X-Client-Terminal`，PC 状态接口与 App 操作接口分开限制。
6. **限流与风控**：按 IP、session_id、用户和设备指纹限流；连续失败、过期会话、伪造 token 只返回通用错误，避免枚举有效会话。
7. **日志脱敏**：审计日志记录 `qr_login_create`、`qr_login_scan`、`qr_login_confirm`、`qr_login_reject`、`qr_login_expire`、`qr_login_consume`，仅记录 session_id 摘要、用户 ID、终端、结果和 request_id，不记录二维码完整内容、JWT、`qr_token`、`pc_secret`。
8. **传输保护**：生产环境必须 HTTPS；App 和 PC 均不得在日志、崩溃上报和埋点中打印 token。
9. **异常恢复**：PC 网络恢复后可以继续查询同一会话；若服务端返回 `consumed`、`expired` 或无法识别状态，前端应停止轮询并要求重新创建二维码。

## 10. 前端与 App 改造点

### 10.1 PC Web

- `LoginPage.tsx`：将 qrcode 占位替换为真实二维码、状态文案、倒计时、刷新按钮、异常提示。
- `auth.ts`：新增创建会话、查询状态、取消会话 API 方法。
- 建议引入成熟二维码生成库，二维码组件固定白底、足够静区，建议展示尺寸不小于 192×192 px；不要手工绘制二维码。
- Tab 切换到短信登录时停止轮询；重新进入扫码 Tab 时创建新会话，避免复用旧二维码。
- 用户协议未勾选时不创建登录会话；协议勾选状态沿用现有登录页逻辑。
- 登录成功沿用现有 token 存储和 `/chat` 跳转逻辑，避免形成第二套 PC 登录态。

### 10.2 Flutter App

- `ChatScreen._buildSidebar`：增加“扫一扫”导航项及点击处理。
- `app_router.dart`：新增 `/scan` 路由。
- 新增 `ScanScreen` 和扫码服务封装，页面职责包括权限、识别、校验、确认和结果反馈。
- `ApiService`：新增扫码、确认、拒绝接口；请求自动带现有 App JWT 和 `X-Client-Terminal: app`。
- `AuthProvider`：扫码登录确认不改变 App 当前登录态，仅由 `ApiService` 发起授权动作；未登录用户从 `/scan` 点击“去登录”后，登录成功需返回扫码页并重新扫描。
- Android、iOS、鸿蒙分别配置摄像头权限和扫码插件能力；扫码插件必须支持三端相机实时识别，一期不提供相册选择入口。
- 扫描页从后台恢复时重新检查会话/确认状态，不保留过期的确认数据。

## 11. 交互与文案

| 场景 | PC 文案 | App 文案 |
| --- | --- | --- |
| 等待扫描 | 请使用 App 扫一扫 | 扫描 PC 端二维码 |
| 已扫描 | 已扫描，请在 App 上确认登录 | 确认登录 PC 端 |
| 已确认 | 登录中… | 登录成功 |
| 已拒绝 | 已取消本次登录 | 已取消登录 |
| 已过期 | 二维码已过期，点击刷新 | 二维码已失效，请重新扫描 |
| 非法二维码 | 无法识别该二维码 | 不是本系统的登录二维码 |
| 未登录 App | — | 请先登录 App 后再使用扫一扫 |
| 摄像头权限拒绝 | — | 需要摄像头权限才能扫一扫 |
| 网络异常 | 网络异常，请检查网络后重试 | 网络异常，请稍后重试 |

## 12. 异常与边界处理

- 同一 App 用户可同时确认多个不同 PC 会话，每个会话独立；可按产品需要增加“只保留最近一个 PC 会话”的风控策略，默认不做强制互斥。
- 同一二维码被多个 App 扫描时，只接受第一个有效扫描用户；若已进入 `scanned`，其他用户收到“二维码已被其他设备处理”。
- App 扫描后 PC 刷新页面：旧会话仍可在有效期内继续完成；PC 页面重新创建会话时，建议主动取消旧会话。
- PC 已拿到 token 但跳转失败：不重复消费 token；页面刷新后若本地已有 token，按现有鉴权逻辑恢复，否则重新扫码。
- App 确认后 PC 长时间不消费：TTL 到期自动失效并记录异常，不允许之后恢复登录。
- 账号被禁用/注销：确认接口重新校验账号状态，返回 403，不签发 PC token。
- App 当前账号与预期账号不一致：确认页展示脱敏账号信息，用户可取消后切换账号。

## 13. 测试设计

### 13.1 接口测试

- 创建会话返回字段完整，TTL、随机性和终端校验正确。
- 未登录 App 调用 scan/confirm 被拒绝；伪造 user ID 不生效。
- pending、scanned、confirmed、rejected、expired、consumed 状态流转符合状态机。
- 同一 token 并发 confirm/consume 只成功一次。
- 过期、重复扫描、重复确认、错误 token、错误终端、错误用户均返回预期错误且不泄漏敏感信息。
- 禁用/注销用户不能确认登录。

### 13.2 PC 测试

- 首次进入扫码 Tab 能生成二维码；刷新、切换 Tab、离开页面均正确停止轮询。
- 轮询间隔、倒计时和错误重试符合设计；确认成功只写入一次 token 并跳转 `/chat`。
- 二维码过期、App 拒绝、网络断开恢复、浏览器刷新均有正确提示。
- 未勾选用户协议时不能创建扫码会话。

### 13.3 App 测试

- 宽屏侧栏、窄屏 Drawer 都显示“扫一扫”，入口可达且不影响现有导航。
- 摄像头首次授权、拒绝、永久拒绝、返回前台均正确处理。
- 合法二维码、非法二维码、过期二维码、重复二维码均有正确结果。
- 确认/取消按钮防重复点击；确认成功后 App 当前登录态不被覆盖。
- Android、iOS、鸿蒙真机相机权限和扫码识别可用。

### 13.4 安全与验收标准

1. 用户在已登录 App 中完成一次扫码确认后，PC 能在 10 秒内自动进入首页。
2. 未点击 App“确认登录”时，PC 永远不能完成登录。
3. 二维码过期、拒绝、消费后不可再次登录。
4. 服务端日志、前端日志和 App 日志均不出现 JWT、`qr_token`、`pc_secret` 明文。
5. 现有短信登录和 App 其他功能回归通过。

## 14. 发布与回滚

建议分阶段发布：

1. 后端先发布接口和 Redis 会话能力，保持前端无感。
2. PC 发布二维码 Tab，但可通过配置开关控制展示。
3. App 发布“扫一扫”入口和确认流程。
4. 灰度期间监控创建成功率、扫描成功率、确认成功率、平均耗时、过期率和异常码。

回滚策略：关闭 PC 扫码入口配置并停止 App 导航入口；后端扫码接口可保留但不影响短信登录。Redis 扫码 key 会按 TTL 自动清理，无需数据回滚。

## 15. 待确认事项

以下事项需要产品/安全确认后再开发：

1. 扫码确认页是否展示 PC 登录地点/IP/浏览器信息；当前设计仅展示“PC 网页端”。
2. 二维码有效期：已确认采用 60 秒；确认后不额外延长，过期后必须手动刷新。
3. PC 多会话：已确认允许同一 App 账号同时登录多个 PC；每个 PC 使用独立二维码，每个二维码只能成功消费一次。单个浏览器窗口仍只维护一个活动会话。
4. 相册扫码：已确认一期不支持相册选择，只支持相机实时扫码。
5. 是否要求扫码登录操作写入现有审计后台；当前设计建议必须写入。
6. 是否接受短轮询；当前设计建议一期采用 2 秒轮询，后续根据监控数据评估 SSE。
7. 二维码 URI：已确认采用 `hospital://pc-login`，二维码参数使用 `sid`、`qt`、`v`，由 App 扫码页校验后处理。
8. 扫码插件需在 Android、iOS、鸿蒙真机上分别验证相机权限、实时识别和构建兼容性；建议先确定统一的 `ScanService` 抽象，再选定各平台实现，避免将插件 API 直接耦合到页面。

## 16. 建议确认结论

若无特别约束，建议按以下默认值进入开发：

- 短轮询，间隔 2 秒；二维码有效期 60 秒，过期后只能手动刷新。
- 允许同一 App 账号同时登录多个 PC；每个 PC 会话独立、每个二维码只能使用一次。
- 二维码 scheme 固定为 `hospital://pc-login`。
- App 扫描后必须二次确认。
- Redis 存储会话，不新增数据库表。
- PC 端复用现有 JWT 存储和登录后跳转逻辑。
- App “扫一扫”放入现有 Chat 页左侧栏/Drawer。
- 一期只支持兼容 Android、iOS、鸿蒙的相机实时扫码，不支持相册导入。
- 所有扫码行为写入审计日志，并按安全要求脱敏。
