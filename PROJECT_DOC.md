# AI 医疗问诊系统 - 项目技术文档

## 一、项目概览

本项目是一套面向医疗健康领域的 AI 问诊系统，采用**前后端分离**架构，支持多轮对话问诊、检查报告解析、高频问题快速应答、患者档案管理等功能。系统分为两个主要子系统：

- **backend**：FastAPI 后端服务，负责 LLM 对话、数据持久化、认证鉴权
- **admin_web**：React 管理后台前端，供管理员进行运营和内容管理

---

## 二、技术栈总览

### 后端

| 层次 | 技术选型 |
|------|----------|
| Web 框架 | FastAPI + Uvicorn (ASGI) |
| 语言 | Python 3.11+ |
| ORM | SQLAlchemy 2.0 (异步) |
| 数据库迁移 | Alembic |
| 数据库 | PostgreSQL (asyncpg 异步驱动) |
| 缓存 | Redis (async) + fakeredis (本地降级) |
| LLM 接入 | OpenAI SDK → 阿里云 DashScope 兼容接口 |
| LLM 框架 | LangChain (记忆管理) |
| 流式响应 | SSE (Server-Sent Events, sse-starlette) |
| 认证 | JWT (python-jose) + bcrypt 密码哈希 |
| 数据加密 | Fernet (AES, cryptography 库) |
| 短信服务 | 阿里云 Dypns API |
| 日志 | loguru |
| 部署 | Docker + docker-compose |

### 前端 (admin_web)

| 层次 | 技术选型 |
|------|----------|
| 框架 | React 18 + TypeScript |
| 构建工具 | Vite 6 |
| 路由 | react-router-dom v7 |
| 状态管理 | Zustand |
| UI 组件库 | Radix UI (shadcn/ui 风格) |
| 样式方案 | Tailwind CSS 3 + PostCSS |
| 图标 | lucide-react |
| HTTP 客户端 | axios |
| Markdown 编辑 | @uiw/react-md-editor |
| 代码规范 | ESLint 9 + typescript-eslint |

---

## 三、系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                     admin_web (React SPA)                    │
│  Vite · React 18 · TypeScript · Tailwind CSS · Zustand      │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTP (axios)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    backend (FastAPI)                         │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │ 中间件层     │  │ 路由层        │  │ LLM 对话层          │ │
│  │ CORS        │  │ auth         │  │ agents.py           │ │
│  │ 限流 (Redis)│  │ profiles     │  │ stream_chat         │ │
│  │ 安全头       │  │ consultations│  │ stream_normal_chat  │ │
│  │ 请求体限制   │  │ chat_sessions│  │ stream_medical_chat │ │
│  │ 请求日志     │  │ admin        │  │                     │ │
│  └─────────────┘  │ health       │  └──────────┬─────────┘ │
│                    └──────┬───────┘             │           │
│                           │                     │           │
│  ┌────────────────────────┼─────────────────────┼────────┐ │
│  │         数据层          │                     │        │ │
│  │  SQLAlchemy ORM        │  Redis              │ OpenAI │ │
│  │  PostgreSQL (asyncpg)  │  (AuthCache/Rate/   │ SDK    │ │
│  │  Alembic migrations    │   L1+L2 Cache)      │        │ │
│  └────────────────────────┴─────────────────────┴────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 四、核心业务流程

### 4.1 用户认证流程

```
用户登录
    │
    ├─ 密码登录 ──→ POST /api/auth/login ──→ 校验密码(bcrypt) ──→ 签发 JWT
    ├─ 短信登录 ──→ POST /api/auth/send_code ──→ 存储验证码(Redis, TTL=300s)
    │                POST /api/auth/login/sms ──→ 校验验证码 ──→ 签发 JWT
    ├─ 运营商一键登录 ──→ POST /api/auth/login/carrier ──→ 阿里云获取本机号码 ──→ 签发 JWT
    └─ 退出 ──→ POST /api/auth/logout ──→ Token 加入黑名单(Redis, TTL=7天)
```

**安全机制：**
- 密码策略：≥8位，含大小写字母+数字
- 登录失败锁定：5次失败锁定15分钟
- JWT 有效期：2小时
- Token 黑名单：Redis 存储，7天过期

### 4.2 AI 对话流程

```
前端发起请求
    │
    POST /api/chat (mode, message, history, session_id, files...)
    │
    ├─ 1. 解析认证 Header → 获取用户身份
    ├─ 2. 加载会话历史 (memory.py, 滑动窗口 20条)
    ├─ 3. 构建用户病例上下文 (profiles + 最近5条问诊记录)
    ├─ 4. 处理附件上传 → DashScope 文件提取 API → 获得 file_ids
    │
    ├─ 5. 高频问题匹配 (无文件、无历史时)
    │       └─ 精确匹配 high_freq_questions 表
    │           ├─ 命中 → 直接返回预设模板(支持变量替换 [姓名][性别][年龄])
    │           └─ 未命中 → 进入 LLM 对话
    │
    ├─ 6. 调用 LLM 流式对话
    │       ├─ mode="normal" → stream_normal_chat (日常问答)
    │       └─ mode="medical" → stream_medical_chat (多轮问诊)
    │
    └─ 7. SSE 流式返回前端
            ├─ 实时推送 reasoning / content 事件
            ├─ 问诊模式下解析 [CARD] 标签 → 结构化卡片
            └─ 对话完成后持久化到 memory 系统
```

### 4.3 两种对话模式对比

| 特性 | 普通问答 (normal) | 问诊模式 (medical) |
|------|-------------------|-------------------|
| 角色设定 | 医疗健康助手"安小记" | 专业在线问诊医生 |
| 交互方式 | 单轮问答 | 多轮对话收集病情 |
| 输出格式 | 纯文本 | 文本 + 结构化卡片 (JSON) |
| 卡片类型 | 无 | question_options (选项卡片) / medical_result (问诊结果卡片) |
| 信息收集 | 不涉及 | 症状 → 伴随症状 → 既往病史 → 初诊结论 |
| 推荐科室 | 不涉及 | 输出推荐科室和就医建议 |

### 4.4 问诊卡片数据结构

问诊模式通过 `[CARD]...[/CARD]` 标签传递结构化数据：

**选项卡片** (AI 追问时)：
```json
{
  "type": "question_options",
  "data": {
    "options": ["选项1", "选项2", "选项3"]
  }
}
```

**问诊结果卡片** (信息充分时)：
```json
{
  "type": "medical_result",
  "data": {
    "summary": "患者概览",
    "analysis": "病情分析",
    "recommended_department": "推荐科室",
    "hospital_suggestion": "就医建议"
  }
}
```

---

## 五、数据模型

### 5.1 核心实体关系

```
User (用户)
 ├── PatientProfile[] (患者档案, 1:N)
 │    └── ConsultationRecord[] (问诊记录, 1:N)
 └── ChatSession[] (对话会话, 1:N)
```

### 5.2 数据库表结构

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| `users` | 用户表 | phone, hashed_password, is_admin, is_active |
| `patient_profiles` | 患者档案表 | name, relation(self/parent/child), gender, age, medical_history(加密), allergies(加密) |
| `consultation_records` | 问诊记录表 | symptoms, diagnosis, advice, department, chat_history(JSON) |
| `chat_sessions` | 对话会话表 | title, mode(normal/medical), messages_json, is_active, token_count |
| `high_freq_questions` | 高频问题表 | question, answer_template, status(draft/published), click_count, sort_weight |
| `system_configs` | 系统配置表 | key, value |
| `agreements` | 协议表 | type(user_agreement/privacy_policy), title, content |
| `audit_logs` | 审计日志表 | admin_id, action, target_id, details |

### 5.3 敏感数据加密

`patient_profiles` 表中的 `medical_history` 和 `allergies` 字段使用 **Fernet (AES-128-CBC)** 对称加密存储，密钥通过 `ENCRYPTION_KEY` 环境变量注入。

---

## 六、API 接口清单

### 认证模块 `/api/auth`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/auth/register` | 用户注册 | 无 |
| POST | `/api/auth/login` | 密码登录 | 无 |
| POST | `/api/auth/login/sms` | 短信登录 | 无 |
| POST | `/api/auth/login/carrier` | 运营商一键登录 | 无 |
| POST | `/api/auth/send_code` | 发送验证码 | 无 |
| POST | `/api/auth/logout` | 退出登录 | Bearer |
| GET | `/api/auth/me` | 获取当前用户信息 | Bearer |
| PUT | `/api/auth/me` | 更新用户信息 | Bearer |
| GET | `/api/auth/check-admin` | 检查管理员是否存在 | 无 |
| POST | `/api/auth/setup` | 初始化管理员 | 无 |

### 对话模块

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/chat` | 主对话接口 (SSE 流式) | Bearer |
| POST | `/api/chat/polish` | AI 润色医疗问题 | 无 |
| POST | `/api/chat/uploads` | 上传对话附件 | Bearer |
| POST | `/api/upload` | 上传图片(测试用) | 无 |

### 会话管理 `/api/chat-sessions`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/chat-sessions` | 列出所有会话 | Bearer |
| GET | `/api/chat-sessions/{id}` | 获取会话详情 | Bearer |
| POST | `/api/chat-sessions` | 创建/更新会话 | Bearer |
| GET | `/api/chat-sessions/{id}/messages` | 获取会话消息 | Bearer |
| DELETE | `/api/chat-sessions/{id}` | 删除会话 | Bearer |

### 患者档案 `/api/profiles`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/profiles` | 列出当前用户档案 | Bearer |
| POST | `/api/profiles` | 创建档案 | Bearer |
| PUT | `/api/profiles/{id}` | 更新档案 | Bearer |
| DELETE | `/api/profiles/{id}` | 删除档案 | Bearer |

### 问诊记录 `/api/consultations`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/consultations` | 查询问诊记录 | Bearer |
| POST | `/api/consultations` | 创建问诊记录 | Bearer |
| POST | `/api/consultations/save-card` | 保存问诊卡片(自动更新患者病史) | Bearer |
| GET | `/api/consultations/records` | 获取已保存的问诊记录列表 | Bearer |

### 管理后台 `/api/admin`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/admin/dashboard/stats` | 仪表盘统计数据 |
| GET | `/api/admin/users` | 用户列表 |
| PUT | `/api/admin/users/{id}/status` | 启用/禁用用户 |
| GET | `/api/admin/users/{id}/chat-sessions` | 查看用户会话列表 |
| GET | `/api/admin/chat-sessions/{id}` | 查看会话详情 |
| GET/POST/PUT/DELETE | `/api/admin/questions/*` | 高频问题 CRUD |
| PUT | `/api/admin/questions/{id}/publish` | 发布高频问题 |
| GET/PUT | `/api/admin/settings` | 系统配置管理 |
| GET | `/api/admin/audit-logs` | 审计日志 |
| GET/PUT | `/api/admin/agreements/*` | 协议管理 |
| PUT | `/api/admin/password` | 修改管理员密码 |

### 公开接口 `/api/public`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/public/questions` | 获取已发布的高频问题 |
| POST | `/api/public/questions/{id}/click` | 记录问题点击 |
| GET | `/api/public/agreements/{type}` | 获取协议内容 |

---

## 七、模型接入配置

### 7.1 当前配置

```python
# backend/agents.py
MODEL_NAME = "qwen-plus"                       # 主对话模型
LONG_CONTEXT_MODEL_NAME = "qwen-long"           # 文件解析模型(长上下文)

client = AsyncOpenAI(
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
)
```

### 7.2 模型切换

修改 `backend/agents.py` 中的常量即可切换模型：

```python
MODEL_NAME = "qwen-max"     # 可换为 qwen-turbo, qwen-max, qwen-long 等
```

### 7.3 切换其他 LLM 服务商

由于使用 OpenAI 兼容协议，修改以下配置即可：

```python
client = AsyncOpenAI(
    api_key="your-api-key",
    base_url="https://your-provider.com/v1",   # 服务商端点
)
MODEL_NAME = "model-name"
```

### 7.4 对话模式参数

| 参数 | 说明 |
|------|------|
| `mode` | `"normal"` 或 `"medical"` |
| `thinking` | 是否开启深度推理 (qwen-plus 支持 `enable_thinking`) |
| `file_ids` | 文件 ID 列表，存在时自动切换为 `qwen-long` 长上下文模型 |
| `session_id` | 会话 ID，用于加载/持久化对话记忆 |
| `consultation_profile_id` | 指定患者档案，用于注入病例上下文 |

---

## 八、中间件与安全

### 8.1 中间件栈 (按执行顺序)

| 顺序 | 中间件 | 说明 |
|------|--------|------|
| 1 | 请求日志 | 记录所有请求的方法、路径、耗时 |
| 2 | CORS | 可配置的跨域白名单 |
| 3 | 安全响应头 | X-Content-Type-Options, X-Frame-Options, HSTS 等 |
| 4 | 请求体限制 | 最大 10MB |
| 5 | 限流 (RateLimitMiddleware) | Redis 滑动窗口算法 |

### 8.2 限流策略

| 端点 | 限制 |
|------|------|
| `/api/auth/login` | 10次/分钟 |
| `/api/auth/register` | 5次/分钟 |
| `/api/auth/send_code` | 10次/天 |
| `/api/chat` | 30次/分钟 |
| `/api/chat/uploads` | 20次/分钟 |
| `/api/public/*` | 100次/分钟 |
| `/api/admin/*` | 200次/分钟 |
| 其他 | 60次/分钟 |

限流维度：已认证用户按 `user_id`，未认证按 `client IP`。

### 8.3 安全特性

- 密码 bcrypt 哈希存储
- JWT Token 签发与验证
- 患者敏感数据 Fernet 加密
- 图片 EXIF 数据剥离（隐私保护）
- Token 黑名单机制
- 登录失败锁定
- HSTS / X-Frame-Options 等安全头

---

## 九、缓存体系

### 两级缓存架构

```
请求 ──→ L1 (进程内 TTLCache) ──→ L2 (Redis) ──→ 数据库
              maxsize=500              TTL=300s
              ttl=300s
```

- **L1**：`cachetools.TTLCache`，进程内缓存，适用于热点小数据（配置项、高频问题等）
- **L2**：Redis，跨进程共享，支持 `cache_invalidate` / `cache_invalidate_pattern` 主动失效

### 缓存使用场景

| 场景 | 缓存键 | TTL |
|------|--------|-----|
| 高频问题列表 | `public_questions` | 300s |
| 系统配置 | `system_settings` | 300s |
| 协议内容 | `agreement_{type}` | 300s |
| SMS 验证码 | `sms_code_{phone}` | 300s |
| 登录锁定 | `lock_{phone}` | 900s |
| Token 黑名单 | `blacklist_{token}` | 7天 |

---

## 十、对话记忆系统

基于 LangChain `BaseChatMessageHistory` 接口实现，数据持久化到 PostgreSQL。

### 核心类

| 类 | 说明 |
|----|------|
| `PostgresChatMessageHistory` | LangChain 消息历史实现，读写 `chat_sessions.messages_json` |
| `ConversationMemoryManager` | 对话记忆管理器，封装滑动窗口裁剪和批量记录 |

### 记忆策略

- **滑动窗口**：保留最近 20 条消息（约 10 轮对话）
- **持久化**：每轮对话结束后，自动将 user_msg + assistant_msg 写入数据库
- **上下文注入**：对话时自动加载用户的历史病例和最近问诊记录，作为 system prompt 的补充

---

## 十一、部署配置

### 环境变量清单

| 变量 | 必填 | 说明 |
|------|------|------|
| `DASHSCOPE_API_KEY` | 是 | 阿里云 DashScope API 密钥 |
| `SECRET_KEY` | 是 | JWT 签名密钥 |
| `ENCRYPTION_KEY` | 是 | Fernet 加密密钥（患者数据） |
| `DATABASE_URL` | 是 | PostgreSQL 连接串 |
| `POSTGRES_PASSWORD` | Docker | PostgreSQL 密码 |
| `REDIS_URL` | 否 | Redis 连接串（不配置则使用 fakeredis） |
| `CORS_ALLOWED_ORIGINS` | 否 | CORS 白名单（逗号分隔） |
| `APP_PORT` | 否 | 服务端口（默认 8000） |
| `LOG_LEVEL` | 否 | 日志级别（默认 INFO） |
| `SQL_ECHO` | 否 | 是否打印 SQL（调试用） |

### Docker 部署

```bash
# backend/docker-compose.yml
docker-compose up -d
```

包含服务：backend (FastAPI) + PostgreSQL + Redis

---

## 十二、前端管理后台

### 页面结构

```
/login          → 管理员登录
/dashboard      → 仪表盘（用户数、会话数、问诊数统计）
/users          → 用户管理（列表、启用/禁用、查看会话）
/questions       → 高频问题管理（CRUD、发布/草稿、排序）
/agreements     → 协议管理（用户协议、隐私政策）
/audit          → 审计日志
/settings       → 系统配置
```

### 前端架构

- Token 存储在 `localStorage`（key: `admin_token`）
- axios 拦截器自动附加 Authorization Header
- 401/403 响应自动跳转登录页
- 所有 API 调用通过 `api/index.ts` 统一管理
