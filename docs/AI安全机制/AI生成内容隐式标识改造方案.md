# AI 生成合成内容标识元数据改造方案

> 项目：三十天时刻智护（hospital-v5）
> 版本：V2.1（V2.0 依据 GB 45438-2025 六要素规范重新设计；V2.1 补充导出/分享显式水印与复制追加标识）
> 日期：2026-09-07
> 服务提供者编码：`001191149900MA0LA3QG5T20001`
> 应用包名：`com.sstkjgf.app`

---

## 1. 背景与依据

- 《人工智能生成合成内容标识办法》（2025-09-01 施行）第 4 条（显式标识）、第 5 条（隐式标识）。
- **GB 45438-2025《网络安全技术 人工智能生成合成内容标识方法》**：AI 生成合成内容的标识元数据应包含以下六要素：

| # | 要素 | 说明 |
|---|------|------|
| 1 | 生成合成属性标志位 | 标记内容属性为「AI生成」 |
| 2 | 服务提供者编码 | 备案分配编码：`001191149900MA0LA3QG5T20001` |
| 3 | 内容编号 | 本次生成内容的唯一序列号 |
| 4 | 生成时间戳 | 内容生成时刻 |
| 5 | 应用包名 | `com.sstkjgf.app` |
| 6 | 保留字段 | 预留扩展 |

## 2. 标识元数据结构定义（核心变更）

所有落点统一使用如下 JSON 结构（语义化英文键名，可按标准正式稿附录字段名调整映射）：

```json
{
  "aiGenerated": true,
  "serviceProviderCode": "001191149900MA0LA3QG5T20001",
  "contentId": "9f2c7a1e48b34d2e8c5a6f0b7d3e4a5c",
  "generateTimestamp": 1759904400123,
  "packageName": "com.sstkjgf.app",
  "reserved": ""
}
```

| 字段 | 类型 | 生成规则 |
|------|------|---------|
| `aiGenerated` | bool | 恒为 `true`（本系统出口均为 AI 生成内容） |
| `serviceProviderCode` | string | 服务端常量，来自 `.env` |
| `contentId` | string | 每条 AI 生成内容一个 UUID4 hex（32 位）；**同一条内容的 SSE 事件与落库留存使用同一编号** |
| `generateTimestamp` | int | Unix 毫秒时间戳，内容生成完成时刻 |
| `packageName` | string | 服务端常量 `com.sstkjgf.app` |
| `reserved` | string | 预留空串 |

## 3. 现状盘点

### 3.1 已具备能力（显式标识 ✅）

| 端 | 实现位置 |
|----|---------|
| Flutter App | `lib/constants/ai_watermark.dart`（"以上内容由AI生成，仅供参考"），用于 `chat_screen.dart`（4 处）、`history_screen.dart`（2 处）、`health_archive_screen.dart`（1 处） |
| Web 端 | `frontend/src/utils/aiWatermark.ts`，用于 `MessageRender.tsx`、`ChatPage.tsx`、`MedicalCard.tsx`；`ChatContainer.tsx` 另有免责声明 |

### 3.2 缺口（隐式标识 ❌）

- 全项目未出现服务提供者编码 `001191149900MA0LA3QG5T20001`；
- 无六要素元数据的生成与注入逻辑；
- 会话/报告留存数据无法举证。

### 3.3 AI 生成内容出口清单（改造对象）

| # | 出口 | 链路位置 |
|---|------|---------|
| 1 | 聊天 AI 回复（流式 SSE，含高频问题模板秒回） | `backend/main.py` L435-484，事件 `{"type":"content"/"reasoning"/"context",...}`，`[DONE]` 结束 |
| 2 | 聊天会话持久化（前端 upsert 整包） | `backend/routers/chat_sessions.py` `upsert_chat_session`（L169-197），消息模型 L25-32，落库 `chat_sessions.messages_json` |
| 3 | 智能诊断卡片/报告 | `backend/routers/consultations.py`：`POST ""`（L279）、`POST /save-card`（L301）、`GET /records`（L350） |
| 4 | 文件导出（图片/PDF） | **当前无此场景**，仅做预留设计 |

### 3.4 两端 SSE 解析现状（兼容性依据）

- Flutter：`consultation_chat_provider.dart` `_readSseEvents`（L241-282）按 `type` 分发，未知类型且无 `content` 时静默跳过 → 新事件天然兼容；
- Web：`frontend/src/api/chat.ts` `onmessage`（L142-164）同样按 `type` 分发，未知类型忽略。

---

## 4. 改造目标与设计原则

1. **六要素完整**：所有出口注入的元数据均含标志位、提供者编码、内容编号、时间戳、包名、保留字段；
2. **服务端权威**：`aiGenerated`、`serviceProviderCode`、`packageName` 三要素由服务端强制写入，客户端不可伪造；`contentId`、`generateTimestamp` 优先沿用链路传递值，缺失时服务端补齐，确保"一次生成、全程同号"；
3. **无扰可溯**：元数据不在正文显示，但任何留存数据（会话 JSON、报告记录、导出文件）可读出完整六要素；
4. **向后兼容**：新增 SSE 事件与消息字段均为可选，老客户端零感知；
5. **可配置**：编码/包名存 `.env`，换证换包不改代码。

## 5. 总体架构

```
.env: AI_SERVICE_PROVIDER_CODE / AI_APP_PACKAGE_NAME
        │
        ▼
backend/ai_label.py（新增：常量 + build_ai_label_meta() 工厂 + 内容编号生成）
        │
   ┌────┼─────────────┬──────────────────┐
   ▼    ▼             ▼                  ▼
 ①SSE  ②会话持久化   ③诊断报告接口      ④文件元数据(预留)
 ai_label  aiLabelMeta   ai_label_meta     PNG tEXt / PDF meta
 事件      强制注入      JSONB 落库       写完整元数据 JSON
   │        │             │
   ▼        ▼             ▼
Flutter/Web 接收并随会话上传 → 后端校验合并 → 全链路同 contentId
```

## 6. 详细设计

### 6.1 新增元数据模块 `backend/ai_label.py`（新文件）

```python
"""AI 生成合成内容标识元数据（GB 45438-2025 六要素）"""
import time
import uuid
import os
from typing import Optional, TypedDict


class AiLabelMeta(TypedDict):
    aiGenerated: bool            # 生成合成属性标志位
    serviceProviderCode: str     # 服务提供者编码
    contentId: str               # 内容编号（唯一序列号）
    generateTimestamp: int       # 生成时间戳（Unix 毫秒）
    packageName: str             # 应用包名
    reserved: str                # 保留字段


SERVICE_PROVIDER_CODE = os.getenv("AI_SERVICE_PROVIDER_CODE", "001191149900MA0LA3QG5T20001")
APP_PACKAGE_NAME = os.getenv("AI_APP_PACKAGE_NAME", "com.sstkjgf.app")


def new_content_id() -> str:
    """内容编号：UUID4 hex，每次生成本次唯一"""
    return uuid.uuid4().hex


def build_ai_label_meta(
    content_id: Optional[str] = None,
    generate_timestamp: Optional[int] = None,
) -> AiLabelMeta:
    """构建完整六要素元数据。

    contentId / generateTimestamp 允许链路传入（保持一次生成全程同号），
    其余三要素恒为服务端权威值，不受输入影响。
    """
    return AiLabelMeta(
        aiGenerated=True,
        serviceProviderCode=SERVICE_PROVIDER_CODE,
        contentId=content_id or new_content_id(),
        generateTimestamp=generate_timestamp or int(time.time() * 1000),
        packageName=APP_PACKAGE_NAME,
        reserved="",
    )
```

`backend/.env` 增加：

```text
AI_SERVICE_PROVIDER_CODE=001191149900MA0LA3QG5T20001
AI_APP_PACKAGE_NAME=com.sstkjgf.app
```

> 独立模块而非放 `main.py`：router 反向 import `main` 会产生循环导入。

### 6.2 落点①：聊天 SSE 流追加标识事件

位置：`backend/main.py` chat 接口，两处 `yield {"data": "[DONE]"}`（L437 高频秒回分支、L481 正常流结束）之前各插入。

本次生成的内容编号在**流开始前生成一次**，结束事件携带，保证客户端保存会话时能带同一编号回传：

```python
from ai_label import build_ai_label_meta, new_content_id

# 流开始前（进入生成流程时）：
_label_content_id = new_content_id()

# [DONE] 之前：
_label_meta = build_ai_label_meta(content_id=_label_content_id)  # 时间戳取生成完成时刻
yield {"data": json.dumps({"type": "ai_label", "meta": _label_meta}, ensure_ascii=False)}
yield {"data": "[DONE]"}
```

- 错误分支（L483-484）不加：错误响应不属于生成内容；
- 兼容性：Flutter / Web 对未知 `type` 且无 `content` 的事件静默忽略，老客户端无感。

### 6.3 落点②：会话持久化服务端注入

位置：`backend/routers/chat_sessions.py`

**6.3.1 消息模型加可选字段**（L25-32）：

```python
from ai_label import build_ai_label_meta, SERVICE_PROVIDER_CODE, APP_PACKAGE_NAME

class ChatSessionMessagePayload(BaseModel):
    id: str
    role: Literal["user", "ai"]
    content: str
    reasoning: Optional[str] = None
    status: Literal["local", "loading", "updating", "success", "error"] = "success"
    contextFileIds: List[str] = []
    attachments: List["ChatSessionAttachmentPayload"] = []
    aiLabelMeta: Optional[dict] = None   # 新增：GB 45438-2025 六要素元数据
```

**6.3.2 `upsert_chat_session` 强制注入/校验合并**（在 `json.dumps(...)` 落库前）：

```python
def _merge_ai_label(meta: Optional[dict]) -> dict:
    """三要素服务端强制；contentId/timestamp 沿用客户端链路值（缺失则补齐）"""
    incoming = meta if isinstance(meta, dict) else {}
    trusted_id = incoming.get("contentId") if isinstance(incoming.get("contentId"), str) else None
    trusted_ts = incoming.get("generateTimestamp") if isinstance(incoming.get("generateTimestamp"), int) else None
    return build_ai_label_meta(content_id=trusted_id, generate_timestamp=trusted_ts)

# upsert 循环内：
for item in request.messages:
    if item.role == "ai":
        item.aiLabelMeta = _merge_ai_label(item.aiLabelMeta)  # 服务端权威，防伪造/漏传
    valid_messages.append(item)
```

**6.3.3 读取自动带出**：`get_chat_session` / `get_session_messages` 基于同一模型解析返回，`aiLabelMeta` 自动透出，无需额外改动；管理端会话查看（`UserChatSessionsDialog`）可直接读取举证。

### 6.4 落点③：诊断报告接口

位置：`backend/routers/consultations.py`

**6.4.1 响应模型加字段**：

```python
class ConsultationResponse(ConsultationCreate):
    ...
    ai_label_meta: Optional[dict] = None   # 新增：六要素元数据

class SavedConsultationResponse(BaseModel):
    ...
    ai_label_meta: Optional[dict] = None   # 新增
```

**6.4.2 落库**（生成时间与元数据版本绑定，历史记录可独立举证）：

数据库变更（PG `hospital` 库）：

```sql
ALTER TABLE consultation_records ADD COLUMN IF NOT EXISTS ai_label_meta JSONB;
```

`models.py` 的 `ConsultationRecord` 增加（需 `from sqlalchemy import JSON`）：

```python
ai_label_meta = Column(JSON, nullable=True)
```

`create_consultation` / `save_consultation_card` 构造记录时：

```python
db_consultation = ConsultationRecord(..., ai_label_meta=build_ai_label_meta())
```

`GET /records` 返回自动带出；存量旧报告该列为 NULL，响应中 `ai_label_meta: null` 表示"未标识"。

> 注：项目未实际启用 alembic 迁移，建表走 `create_all`，存量表加列用手工 DDL；JSONB 可空、无默认值、无索引，风险为零。

### 6.5 落点④：导出文件元数据（预留设计）

当前无文件导出场景。后续新增导出功能时，**元数据 JSON 整体写入**文件：

```python
import json
# PNG：tEXt chunk（肉眼不可见）
from PIL.PngImagePlugin import PngInfo
meta = PngInfo()
meta.add_text("AiLabel", json.dumps(ai_label_meta, ensure_ascii=False))
img.save(buf, format="PNG", pnginfo=meta)

# PDF：文档元数据
from pypdf import PdfWriter
writer.add_metadata({"/Keywords": json.dumps(ai_label_meta, ensure_ascii=False)})
```

若将来 Flutter 端客户端截图分享（`RepaintBoundary.toImage`），分享前需重编码注入 tEXt，或改为服务端代理生成分享图。

### 6.6 客户端消费（可选升级，非必须）

> 后端已在落点②③强制注入，客户端不做也合规；改造目的仅是"链路同号"（SSE 事件里的 contentId 与落库一致）。

**Flutter**（`consultation_chat_provider.dart`）：

```dart
// _readSseEvents 中 type 分发处（L263 之后）增加：
if (type == 'ai_label') {
  yield _BackendEvent.aiLabel(
    (decoded['meta'] as Map<String, dynamic>?) ?? const {},
  );
  continue;
}
// _serializeHistoryMessage（L215-218）对 AI 消息补 'aiLabelMeta': lastAiLabelMeta
```

**Web**（`frontend/src/api/chat.ts`）：

```ts
// onmessage 分发处（L151 附近）增加：
else if (data.type === 'ai_label' && data.meta && typeof data.meta === 'object') {
  controllerStream.enqueue({ type: 'ai_label', meta: data.meta });
}
```

调用侧把 meta 挂到 AI 消息对象，upsert 会话时上传（后端校验合并，三要素不可伪造）。

### 6.7 管理端（可选）

`admin_web` 无需强制改造。可选增强：会话查看与报告详情展示元数据（如"AI生成 · 编号 9f2c…a5c · 2026-09-07 10:30"徽标），便于内部合规举证。

---

## 7. 改动文件清单与工作量

| 文件 | 改动 | 类型 | 规模 |
|------|------|------|------|
| `backend/ai_label.py` | 元数据模块（常量+工厂+编号生成） | 新文件 | ~50 行 |
| `backend/.env` | 增 2 个环境变量 | 配置 | 2 行 |
| `backend/main.py` | 流内生成 contentId + 2 处 SSE 事件 | 修改 | 6 行 |
| `backend/routers/chat_sessions.py` | 模型字段 + `_merge_ai_label` + upsert 注入 | 修改 | ~20 行 |
| `backend/routers/consultations.py` | 2 个响应模型 + 2 处填充 | 修改 | ~10 行 |
| `backend/models.py` | ConsultationRecord 加 JSONB 列 | 修改 | 1 行 |
| 数据库 | `ALTER TABLE consultation_records ADD COLUMN ai_label_meta JSONB` | SQL | 1 条 |
| `frontend/src/api/chat.ts` + 消息对象 | ai_label 分支与透传 | 修改（可选） | ~15 行 |
| `flutter/lib/providers/consultation_chat_provider.dart` | ai_label 分支与透传 | 修改（可选） | ~15 行 |
| `admin_web`（可选） | 会话/报告展示元数据徽标 | 修改（可选） | ~20 行 |

## 8. 兼容性与灰度

| 场景 | 行为 |
|------|------|
| 老版本 App/Web（不认识 `ai_label` 事件） | 事件被静默忽略，功能无损 |
| 老客户端 upsert（消息不带 `aiLabelMeta`） | 服务端全量构建六要素，落库数据完整 |
| 新客户端 + 新后端 | 链路同号（SSE 与落库同 contentId），三要素后端覆盖 |
| 报告历史数据（JSONB 为 NULL） | `GET /records` 返回 `ai_label_meta: null`，按"未标识"展示 |
| 换编码/换包名 | 改 `.env` 即刻生效，无需发版 |

## 9. 测试与验收

1. **六要素完整性**：`curl -N` 调 chat 接口，验证 `ai_label` 事件 meta 同时含 `aiGenerated=true`、`serviceProviderCode=001191149900MA0LA3QG5T20001`、非空 `contentId`、毫秒级 `generateTimestamp`、`packageName=com.sstkjgf.app`、`reserved` 字段存在；高频秒回分支同样携带；
2. **链路同号**：新客户端跑完整会话 → upsert → 读回，验证 AI 消息 `aiLabelMeta.contentId` 与 SSE 事件一致；
3. **防伪造**：构造 `aiLabelMeta`（提供者编码/包名/标志位填假值）调 upsert，读回验证三要素已被服务端覆盖；
4. **编号唯一性**：连续生成 2 条内容，验证 `contentId` 互不相同；
5. **报告接口**：`POST /api/consultations`、`/save-card` 响应含 `ai_label_meta`，`GET /records` 带出；历史数据返回 `null` 不报错；
6. **回归**：老前端页面（不升级）跑完整聊天 + 报告流程无报错；
7. **复制尾巴**：App/Web 复制 AI 回复，验证剪贴板文本末尾包含「——以上内容由AI生成，仅供参考」；
8. **导出双标识（导出功能上线时）**：导出图片/PDF 验证 ①内容本体可见「AI生成」水印 ②文件元数据含完整六要素 JSON；
9. **合规自查**：显式标识各屏可见（已有）；AI 回复、会话留存、报告留存三处均可读出完整六要素。

## 10. 上线步骤与回滚

1. 执行 DDL（JSONB 可空列，秒级，不锁业务）；
2. 发布后端（元数据生效）；
3. 可选：发布两端客户端（链路同号增强）；
4. 回滚：还原后端代码即可；`ai_label_meta` 列与已落库元数据留存无害，无需回滚 DDL；`.env` 调整编码/包名即刻生效。

## 11. 风险与对策

| 风险 | 等级 | 对策 |
|------|------|------|
| 客户端伪造/漏传元数据 | 低 | `aiGenerated`/`serviceProviderCode`/`packageName` 服务端强制覆盖，`contentId`/时间戳仅做可信沿用 |
| contentId 与落库不一致（老客户端） | 低 | 服务端补齐生成新号，仅影响"链路同号"增强项，不影响合规完整性 |
| 循环导入 | 低 | 独立 `ai_label.py` 模块，无业务依赖 |
| 元数据对外可见（隐私） | 低 | 六要素均为备案公开要素，不含个人信息 |
| 加列影响现网 | 低 | JSONB 可空、无默认值、不建索引 |
| 时间戳客户端偏差 | 低 | 仅沿用可信 int，异常类型自动走服务端时间 |
| 未来导出/分享遗漏双标识（显式水印+隐式元数据） | 中 | 6.5 节为强制实现项，双标识缺一不可，列入功能验收 |
| 复制文本脱离系统后无隐式标识 | 中 | 6.5.3 复制尾巴实施后消除；纯文本剪贴板无元数据容器，属固有限制，以显式尾巴兜底 |

## 12. 与 V1.0 方案的差异说明

| 项 | V1.0 | V2.0（本版） |
|----|------|-------------|
| 标识内容 | 单一编码字符串 | GB 45438-2025 六要素元数据 JSON |
| 内容编号 | 无 | 每次生成 UUID4 唯一编号，SSE 与落库同号 |
| 时间戳 | 无 | Unix 毫秒，生成完成时刻 |
| 包名/标志位 | 无 | `com.sstkjgf.app` / `aiGenerated: true` 服务端强制 |
| 报告落库列 | `VARCHAR(64)` | `JSONB` |
| 常量模块 | `constants.py` | `ai_label.py`（含工厂函数与校验合并逻辑） |

## 10. 上线步骤与回滚

1. 执行 DDL（JSONB 可空列，秒级，不锁业务）；
2. 发布后端（元数据生效）；
3. 可选：发布两端客户端（链路同号增强）；
4. 回滚：还原后端代码即可；`ai_label_meta` 列与已落库元数据留存无害，无需回滚 DDL；`.env` 调整编码/包名即刻生效。

## 11. 风险与对策

| 风险 | 等级 | 对策 |
|------|------|------|
| 客户端伪造/漏传元数据 | 低 | `aiGenerated`/`serviceProviderCode`/`packageName` 服务端强制覆盖，`contentId`/时间戳仅做可信沿用 |
| contentId 与落库不一致（老客户端） | 低 | 服务端补齐生成新号，仅影响"链路同号"增强项，不影响合规完整性 |
| 循环导入 | 低 | 独立 `ai_label.py` 模块，无业务依赖 |
| 元数据对外可见（隐私） | 低 | 六要素均为备案公开要素，不含个人信息 |
| 加列影响现网 | 低 | JSONB 可空、无默认值、不建索引 |
| 时间戳客户端偏差 | 低 | 仅沿用可信 int，异常类型自动走服务端时间 |
| 未来文件导出遗漏标识 | 中 | 6.5 节范式 + 列为导出功能验收项 |

## 12. 与 V1.0 方案的差异说明

| 项 | V1.0 | V2.0（本版） |
|----|------|-------------|
| 标识内容 | 单一编码字符串 | GB 45438-2025 六要素元数据 JSON |
| 内容编号 | 无 | 每次生成 UUID4 唯一编号，SSE 与落库同号 |
| 时间戳 | 无 | Unix 毫秒，生成完成时刻 |
| 包名/标志位 | 无 | `com.sstkjgf.app` / `aiGenerated: true` 服务端强制 |
| 报告落库列 | `VARCHAR(64)` | `JSONB` |
| 常量模块 | `constants.py` | `ai_label.py`（含工厂函数与校验合并逻辑） |
