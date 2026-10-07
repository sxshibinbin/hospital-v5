---
name: ai-architecture-design
description: 架构设计技能。将需求分析产出的标准化需求文档转化为系统架构设计、数据库模型、API接口规范及编码指南，按团队规范归档至DOCS目录。在ai-prd-auto之后执行，作为全自动软件开发流水线的第二环节。
tags: [架构设计, 数据库, API, 模块设计, 自动开发]
keywords: [架构设计, ai-architecture-design, 数据库设计, API设计, 模块设计]
metadata:
  author: AI事业部
  version: 1.0.0
---

# 架构设计技能

将需求分析技能产出的需求文档、原型和任务拆分转化为完整的架构设计制品，包括模块设计、数据库DDL、OpenAPI规范、架构说明书和编码规范。

## 执行模式

- **临时模式（默认）**：用户未提供 `temp_output_dir` 时触发。完整执行步骤0~7，产物写入 `DOCS/.temp/{uuid}/架构设计/`，返回 `状态: ready_for_org` 等待主Skill确认。
- **组织模式**：用户提供了 `需求号` 和 `temp_output_dir` 时触发。将临时产物迁移至 `DOCS/{需求号}/架构设计/`，更新路径索引，返回 `状态: success`。

## 输入解析

从用户消息中提取以下信息：
- `需求号`：TFS工作项ID，用于定位 `DOCS/{需求号}/` 下的需求文档
- `context`：可选上下文字典，可包含：
  - `prd_temp_path`：ai-prd-auto临时产物中的PRD.md路径（用于ai-prd-auto尚未org化时的流式执行）
  - `prototype_temp_path`：ai-prd-auto临时产物中的prototype/路径
  - `task_split_temp_path`：ai-prd-auto临时产物中的task_split.md路径
  - `clarification_answers`：步骤1技术决策问询的答案列表
  - `existing_repo_path`：现有代码仓库路径
  - `project_tech`：前端技术栈偏好（从ai-prd-auto继承）
  - `upstream_index_path`：ai-prd-auto的execution_index.json路径
  - `temp_output_dir`：临时产物目录（组织模式必填）

## 执行流程

### 步骤0：知识库就绪检查（自动生成）

检查 `DOCS/项目知识库/初始架构/` 下是否存在以下6个文件且内容非空：

| 文件 | 用途 | 生成方式 |
|------|------|----------|
| `architecture_patterns.md` | 分层架构、模块划分原则、技术选型偏好 | GitNexus 聚类 + LLM |
| `database_design_standard.md` | 表命名规范、必备字段、索引策略、枚举管理 | 代码扫描 + LLM |
| `api_design_standard.md` | URL前缀、版本号、分页参数、错误码表 | GitNexus 依赖图 + LLM |
| `coding_standard.md` | 包结构、类命名、异常处理、日志规范 | 代码统计 + LLM |
| `medical_compliance.md` | 审计字段、敏感数据加密脱敏、数据保留策略 | 代码合规扫描 + LLM |
| `design_mistakes.md` | 历史设计评审中的典型错误与修正方案 | 代码反模式扫描 + LLM |

#### 0.1 全量存在且非空 → 直接使用

逐一读取每个文件，判断内容是否为空或仅含标题行。全部通过则进入步骤1。

#### 0.2 存在缺失或空文件 → 尝试自动生成

**0.2.1 检测可用数据源**

按优先级依次检测，使用第一个可用的：

```
优先级1: GitNexus (结构化图谱，覆盖最全)
  → 调用 gitnexus://repo/<项目名>/context 检查索引状态
  → 存在 → 使用 GitNexus，跳至 0.2.2

优先级2: ICIS-knowledge.md (历史遗留总览文档，部分覆盖)
  → 检查 DOCS/项目知识库/ 下是否存在 <项目名>-knowledge.md
  → 存在 → 作为补充参考（6 文件自身有更高优先级）
  → 不存在 → 不影响，直接跳至优先级 3

优先级3: 直接代码扫描 (采样扫描，覆盖最窄)
  → 无外部数据源可用，跳至 0.3 降级模式
```

**GitNexus 不可用时的引导提示**（不阻塞流程，仅告知）：

若检测到 GitNexus 未安装或未索引，在继续执行的同时输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ℹ GitNexus 索引未检测到
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  知识库文件将基于直接代码扫描生成，覆盖度和准确度受限。

  建议执行以下命令获得更好的生成质量：
    npm install -g gitnexus --registry https://registry.npmjs.org/
    gitnexus setup
    gitnexus analyze --skip-git

  安装完成后下次执行本技能即可使用完整图谱。

  本次将继续执行（降级模式）...
```

**首次使用的典型场景**：

| 场景 | 处理路径 | 结果质量 |
|------|---------|---------|
| GitNexus 已索引 | 图谱查询 + 代码补充扫描 | 高（模块边界精确，聚类算法验证） |
| GitNexus 未索引，有 `-knowledge.md` | 总览文档 + 代码补充扫描 | 中（模块边界依赖LLM推断） |
| 两者均无（裸项目） | 纯代码采样扫描 | 低（需后续人工补充） |

> **关键设计决策**：即使裸项目也不阻断。`architecture_patterns.md` 从 `pom.xml` + Controller/Service 采样反推分层模式；`database_design_standard.md` 从 Entity 类 + Flyway 脚本统计表命名和字段模式。质量和 GitNexus 辅助相比有差距，但比"缺文件就停止"的旧逻辑好——至少技能能跑完。**

**0.2.2 按文件分层生成**

对每个缺失或为空的文件，按以下策略生成：

| 文件 | GitNexus 查询 | 补充 LLM 扫描 |
|------|--------------|--------------|
| `architecture_patterns.md` | `gitnexus://repo/.../clusters` 获取模块聚类 + `gitnexus://repo/.../processes` 获取核心执行流 | 读取 `pom.xml` 提取技术栈版本；读取典型 Controller/Service 提取分层模式 |
| `database_design_standard.md` | `gitnexus_context({name: "Entity"})` 类型过滤 + 调用链查表访问关系 | 扫描典型 Entity 类提取字段命名、审计字段模式；扫描 MyBatis XML 提取索引模式 |
| `api_design_standard.md` | `gitnexus_get_clusters` 过滤 Controller 聚类 | 扫描 10-15 个典型 Controller 提取 URL 前缀、分页参数名、返回结构 |
| `coding_standard.md` | `gitnexus://repo/.../context` 了解整体结构 | 扫描 20-30 个随机类统计命名风格、包路径模式、异常处理方式 |
| `medical_compliance.md` | 不适用（合规规则不在代码中） | 扫描所有 Entity/DDL 统计审计字段覆盖率、敏感字段标注率；**写入法规模板**，标注 `[待人工确认]` |
| `design_mistakes.md` | 不适用（错题不在代码中） | 扫描常见反模式：缺 `@ApiOperation`、`@Transactional` 遗漏、日志直接打印敏感字段、VARCHAR 长度未为加密预留等；**每个发现标注置信度** |

**0.2.3 LLM 合成与写入**

对每个文件：
1. 将 GitNexus 查询结果 + 代码扫描结果输入 LLM
2. LLM 按该文件的内容规范生成 draft 版本
3. 写入 `DOCS/项目知识库/初始架构/{文件名}`
4. 在文件顶部插入自动生成标记：
   ```markdown
   > 自动生成于 {时间戳} | 数据源: GitNexus + 代码扫描 | 部分内容标记 [待人工确认]
   ```

**0.2.4 分级处理**

| 文件 | 自动化程度 | 处理策略 |
|------|----------|----------|
| `architecture_patterns.md` | 高（~80%） | 自动生成 → 写入 → 直接使用 |
| `database_design_standard.md` | 高（~85%） | 自动生成 → 写入 → 直接使用 |
| `api_design_standard.md` | 高（~90%） | 自动生成 → 写入 → 直接使用 |
| `coding_standard.md` | 中（~75%） | 自动生成 → 写入 → 直接使用 |
| `medical_compliance.md` | 低（~60%） | 自动生成 → 写入，关键章节标注 `[待人工确认]` → 使用（合规章节以最严格标准兜底） |
| `design_mistakes.md` | 低（~70%） | 自动扫描反模式 → 写入，每个条目标注置信度 → 使用 |

#### 0.3 两种数据源均不可用 → 降级

若 GitNexus 不可用且 `ICIS-knowledge.md` 也不存在，**不回退到 need_knowledge**。改为：
1. 直接扫描核心代码路径（`icis-biz-main` 的 Controller/Service/Entity 前20个类）
2. 基于有限样本生成精简版知识库文件
3. 在 `error.log` 中记录降级警告：
   ```
   [WARN] 步骤0降级：GitNexus 和 ICIS-knowledge.md 均不可用，知识库文件基于有限代码样本生成，准确度受限
   ```
4. 继续执行后续步骤

#### 0.4 步骤0完成标准与摘要输出

不再以"6个文件全部存在"为硬性阻断。只要满足以下任一条件即进入步骤1：
- 6个文件全量存在且非空 ✓
- 已通过 GitNexus + LLM 自动生成缺失文件 ✓
- 已通过降级扫描生成精简版文件 ✓

**唯一的硬性阻断**：生成过程中 LLM 调用全部失败（记录 ERROR 日志后仍尝试继续，使用内置默认规范）。

**步骤0完成后必须输出摘要**。向用户展示知识库就绪状态（不阻塞流程）：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  步骤0：知识库就绪检查 完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  数据源: GitNexus (119,258 节点 / 1,700 聚类) + 代码直接扫描

  📄 architecture_patterns.md      ✅ 已就绪 (已有)
  📄 database_design_standard.md   ✅ 已就绪 (已有)
  📄 api_design_standard.md        🆕 自动生成 (GitNexus 聚类 + Controller 扫描)
  📄 coding_standard.md            🆕 自动生成 (代码统计采样 30 个类)
  📄 medical_compliance.md         ⚠️ 自动生成 (代码合规扫描，3 项 [待人工确认])
  📄 design_mistakes.md            🆕 自动生成 (反模式扫描，4 条 @ 置信度 60-90%)

  ┌─────────────────────────────────────────────────────┐
  │ ⚠️ 需人工复核 (共 3 项，详见各文件 [待人工确认] 标记)    │
  │   - medical_compliance.md: 数据保留期限、物理删除审批   │
  │   - design_mistakes.md: 1 条低置信度反模式待验证        │
  └─────────────────────────────────────────────────────┘

  进入步骤1...
```

状态图标含义：
| 图标 | 含义 |
|------|------|
| ✅ 已就绪 | 文件已存在且内容非空，直接使用 |
| 🆕 自动生成 | 由 GitNexus + LLM 自动生成，内容基于代码事实，可直接使用 |
| ⚠️ 自动生成 | 自动生成但含 `[待人工确认]` 标记项，可先用但建议复核 |
| ❌ 缺失 | （不应出现）所有数据源不可用，使用内置默认规范兜底 |

#### 0.5 生成项目总览文档

步骤0完成（6文件就绪）后，从6个文件聚合生成 `DOCS/项目知识库/{项目名}-knowledge.md`，就是原 `ai-project-knowledge` 的产物，便于新人快速上手。

**聚合规则**（从6文件提取 → 填充7章节模板）：

| 总览章节 | 数据来源 |
|---------|---------|
| 一、技术栈 | `architecture_patterns.md` §技术选型约束（提取框架+版本表格） |
| 二、目录结构 | `architecture_patterns.md` §包路径规范（提取目录树） |
| 三、产品架构 | `architecture_patterns.md` §模块划分原则（提取模块列表+依赖关系） |
| 四、开发规范 | `coding_standard.md` 摘要 + `api_design_standard.md` 摘要 |
| 五、核心代码逻辑 | `architecture_patterns.md` §模块划分（提取核心模块的 Controller+Service 方法签名） |
| 六、开发注意事项 | `design_mistakes.md` 全文引用 |
| 七、常用配置 | `architecture_patterns.md` §技术选型约束 + `database_design_standard.md` §Flyway规范 |

生成后输出一行：

```
  📄 ICIS-knowledge.md              🆕 从6文件聚合生成
```

写入标记：
```markdown
> 自动聚合于 {时间戳} | 数据源: ai-architecture-design 步骤0 产物 | 详细规范见 DOCS/项目知识库/初始架构/
```

### 步骤1：需求理解与关键决策问询

**1.1 读取需求文档**

确定需求文档路径：
- 优先：`DOCS/{需求号}/需求设计/requirement.md`
- 回退：`context.prd_temp_path`（当ai-prd-auto尚未org化时）

读取需求文档，提取以下信息并整理为结构化摘要：
- 功能范围与边界
- 用户故事列表（角色、期望、目的）
- 非功能需求（性能、安全、合规等）
- 已有的技术约束（如果需求文档中已明确）

**1.2 关键技术决策问询**

检查需求文档及用户消息中是否已明确以下决策。对于未明确的项，通过 `AskUserQuestion` 工具向用户提问（最多4个问题）：

必须确认的4项决策：
1. **目标数据库类型**：MySQL / PostgreSQL / SQL Server / 其他
2. **架构风格**：单体分层（默认）/ 微服务
3. **认证鉴权方案**：JWT / OAuth2 / Session / 其他
4. **是否涉及患者隐私数据**：是 / 否（触发更严格的合规设计）

若存在未明确的决策，提问后**立即暂停**，返回：
```
状态: need_clarification
问题:
  - 目标数据库类型？（如 MySQL、PostgreSQL）
  - 是否采用微服务拆分？（默认为单体分层）
  - 认证鉴权方案？（如 JWT、OAuth2）
  - 是否涉及患者隐私数据？
```
等待用户下一轮提供 `context.clarification_answers` 后重新执行。

**1.3 生成技术栈选型文档**

基于用户回答及需求文档中已明确的技术选型，生成 `{output_dir}/tech_stack.md`，内容包含：

```markdown
# 技术栈选型

## 前端
- 框架：{从PRD或project_tech推断，如 Vue 3 + TypeScript}
- 组件库：{如 WinDesign}
- 构建工具：{如 Vite}

## 后端
- 语言/框架：{如 Spring Boot / Rust / Express}
- ORM：{如 MyBatis / Prisma / SQLx}

## 数据库
- 类型：{如 PostgreSQL 15}
- 缓存：{如 Redis 7}

## 中间件
- 消息队列：{如有}
- 其他中间件清单

## 认证鉴权
- 方案：{如 JWT + Spring Security}

## 部署环境
- 环境划分：开发 / 测试 / 生产
- 容器化：Docker / K8s
```

`{output_dir}` 在临时模式下为 `DOCS/.temp/{uuid}/架构设计/`，在组织模式下为 `DOCS/{需求号}/架构设计/`。若用户未传入 `需求号`，生成一个UUID作为临时目录名。临时模式下需在开始时生成UUID并固定使用。

### 步骤2：模块拆分与边界定义

**2.1 分析原型**

确定原型目录路径：
- 优先：`DOCS/{需求号}/需求设计/prototype/`
- 回退：`context.prototype_temp_path`

若原型目录存在且非空，读取原型文件（HTML/Vue组件），分析：
- 页面结构和路由层次
- 用户交互流程
- 组件层级和复用关系
- 从页面功能反推所需的API端点

若原型目录不存在或为空，记录WARN日志，跳过此分析继续执行。

**2.2 读取任务拆分**

确定任务拆分文件路径：
- 优先：`DOCS/{需求号}/任务拆分/task_list.md`
- 回退：`context.task_split_temp_path`

读取任务列表，提取任务ID、标题、依赖关系，作为模块划分的参考粒度。

**2.3 加载架构规范**

读取 `DOCS/项目知识库/初始架构/architecture_patterns.md`，提取：
- 公司分层架构惯例（如 Controller → Service → Repository → Entity）
- 模块划分原则
- 技术选型偏好和约束

**2.4 设计模块划分**

综合以上信息，基于DDD理念进行系统模块划分。生成 `{output_dir}/module_design.md`：

```markdown
# 系统模块设计

## 模块概览

| 模块名 | 职责 | 对应任务 | 对应页面 |
|--------|------|----------|----------|
| 用户管理 | ... | T2 | /users |

## 模块依赖关系

[文本描述模块间调用/依赖关系，可用ASCII图示]

## 模块详细设计

### 模块1：[名称]

**职责**：[一句话描述]

**包含组件/类**：
- ...

**对外接口**：
- ...

**依赖模块**：
- ...

[重复其他模块]
```

**关键约束**：
- 模块粒度应与任务拆分中的任务保持可追溯的对应关系
- 必须遵循 `architecture_patterns.md` 中的分层惯例
- 模块-页面映射关系必须明确，供下游编码技能使用

### 步骤3：数据库模型设计

**3.1 加载数据库规范**

读取 `DOCS/项目知识库/初始架构/database_design_standard.md` 和 `DOCS/项目知识库/初始架构/medical_compliance.md`，提取设计约束。

**3.2 识别领域实体**

从需求文档和模块设计中提取所有领域实体。检查标准的实体清单：
- 业务实体（从用户故事和功能点中提取）
- 关联实体（多对多关系表）
- 枚举/字典表（状态、类型等）

**3.3 设计表结构**

为每个实体设计数据表。每个表必须包含：

- **业务字段**：字段名、类型、长度、是否必填、默认值、注释
- **审计字段（强制）**：`created_by VARCHAR`、`updated_by VARCHAR`、`created_at DATETIME`、`updated_at DATETIME`、`is_deleted TINYINT DEFAULT 0`
- **敏感字段标注**：包含姓名、身份证号、电话、病历等关键词的字段，在注释中标注 `[加密存储]` 或 `[脱敏显示]`
- **枚举字段**：DDL注释中列出全部可选值
- **索引**：主键索引、唯一约束索引、高频查询字段索引

**3.4 生成DDL和数据字典**

生成两个文件：

**`{output_dir}/schema.sql`**：完整建表DDL，注意：
- 使用所选数据库的正确方言语法
- 每个表前加 `-- Table: 表名 (中文说明)` 注释
- 敏感字段的加密/脱敏要求在注释中说明
- 枚举字段的值域在注释中列出
- 所有索引有明确的 `-- Index for: 用途` 注释

**`{output_dir}/data_dictionary.md`**：数据字典Markdown表格：

```markdown
# 数据字典

## 表清单

| 表名 | 中文名 | 说明 | 敏感级别 |
|------|--------|------|----------|
| patient_info | 患者信息表 | ... | 高 |

## 表详细定义

### patient_info - 患者信息表

| 字段名 | 类型 | 必填 | 默认值 | 说明 | 敏感标记 |
|--------|------|------|--------|------|----------|
| id | BIGINT | 是 | AUTO | 主键 | - |
| patient_name | VARCHAR(50) | 是 | - | 患者姓名 | 加密存储 |
| id_card | VARCHAR(18) | 是 | - | 身份证号 | 加密存储 |
| created_by | VARCHAR(50) | 是 | - | 创建人 | - |
| updated_by | VARCHAR(50) | 是 | - | 更新人 | - |
| created_at | DATETIME | 是 | NOW() | 创建时间 | - |
| updated_at | DATETIME | 是 | NOW() | 更新时间 | - |
| is_deleted | TINYINT | 是 | 0 | 软删除标记 | - |

## 枚举值定义

| 枚举名 | 值 | 说明 |
|--------|-----|------|
| PatientStatus | 0 | 在院 |
| PatientStatus | 1 | 出院 |
```

### 步骤4：接口规范设计

**4.1 加载接口规范**

读取 `DOCS/项目知识库/初始架构/api_design_standard.md`，提取：
- URL前缀和版本号规则
- 分页参数规范（pageNo、pageSize、pageType）
- 排序和过滤参数命名约定
- 错误码体系
- 通用返回格式

**4.2 设计API端点**

基于功能需求和模块划分，为每个用户操作设计RESTful API端点。设计原则：
- 资源导向的URL设计（名词复数）
- 统一版本前缀（如 `/api/v1/`）
- 标准HTTP方法语义（GET查询、POST创建、PUT更新、DELETE删除）
- 每个端点需关联角色权限（医生、护士、管理员）

**4.3 处理文件传输**

若需求涉及附件上传、影像导入、报告导出等场景，设计二进制数据传输接口：
- 上传：`POST` + `multipart/form-data`，明确文件大小限制（如最大10MB）和允许的MIME类型
- 下载：`GET` + `application/octet-stream`，明确权限校验要求

**4.4 生成接口规范文件**

生成两个文件：

**`{output_dir}/api_spec.yaml`**：OpenAPI 3.0规范，必须包含：
- `openapi: 3.0.0`
- `servers` 段（含版本前缀）
- `paths` 段（每个接口的完整定义）
- `components/schemas`（请求体和响应体的JSON Schema）
- `components/securitySchemes`（认证方式定义）
- 每个接口的 `security` 声明

**`{output_dir}/api_list.md`**：Markdown表格形式的接口清单：

```markdown
# API接口清单

## 接口汇总

| 序号 | 方法 | 路径 | 说明 | 认证 | 角色权限 | 对应功能 |
|------|------|------|------|------|----------|----------|
| 1 | GET | /api/v1/patients | 查询患者列表 | JWT | 医生,护士 | US-01 |
| 2 | POST | /api/v1/patients | 新增患者 | JWT | 护士 | US-02 |
| ... | ... | ... | ... | ... | ... | ... |

## 版本策略

- 当前版本：v1
- 版本规则：URL路径前缀 `/api/v{major}/`
- 破坏性变更时递增主版本号

## 文件传输接口

| 方法 | 路径 | 说明 | 大小限制 | MIME类型 |
|------|------|------|----------|----------|
| POST | /api/v1/reports/{id}/attachments | 上传报告附件 | 10MB | image/*,application/pdf |
```

### 步骤5：架构说明书与编码规范撰写

**5.1 生成架构设计说明书**

生成 `{output_dir}/architecture_design.md`，内容至少包含：

```markdown
# 系统架构设计说明书

## 1. 技术栈概述
（引用 tech_stack.md 的核心内容）

## 2. 系统分层架构
- 表示层（前端路由与页面）
- 应用层（Controller / Handler）
- 业务层（Service / UseCase）
- 持久层（Repository / DAO）
- 基础设施层（数据库、缓存、消息队列）

## 3. 模块交互与关键流程
- 核心业务流程的模块协作描述
- 关键接口调用链

## 4. 非功能设计策略

### 4.1 性能
- 缓存策略：本地缓存（Caffeine等）用于字典/配置；分布式缓存（Redis）用于会话/热点数据
- 数据库优化：连接池配置建议、慢查询监控策略
- 静态资源：CDN策略（如适用）

### 4.2 安全
- 认证鉴权流程
- 数据传输加密（TLS）
- 防SQL注入/XSS/CSRF策略
- 敏感数据脱敏展示

### 4.3 合规
- 审计追溯机制
- 患者数据保护策略（加密存储字段清单）
- 数据保留与物理删除审批流程

### 4.4 部署
- 环境划分（dev/test/prod）
- 容器化建议
- CI/CD流程概述
```

**5.2 生成编码补充规范**

读取 `DOCS/项目知识库/初始架构/coding_standard.md` 获取基础编码规范。

生成 `{output_dir}/coding_guidelines.md`，内容必须涵盖：

```markdown
# 程序编码补充规范

## 1. 包结构约定
- 基础包路径
- 各层包命名
- 资源文件组织

## 2. 异常处理规范
- 业务异常类层级
- 全局异常拦截器
- 错误码与HTTP状态码映射

## 3. 日志规范
- 日志级别使用约定
- 日志格式（含traceId）
- 敏感信息脱敏（禁止记录明文身份证/手机号）

## 4. 医疗数据脱敏处理编码要求
- 存储层加密方式（如AES-256）
- 接口层脱敏规则（如姓名显示 `张**`、身份证显示前3后4）
- 日志中敏感字段过滤

## 5. 审计日志记录规范
- 审计事件类型（创建/更新/删除/查看敏感数据）
- 审计表结构
- AOP/拦截器实现建议
```

### 步骤6：合规与一致性校验

**6.1 执行交叉校验**

逐项核对以下5个校验维度：

| 校验项 | 检查方法 |
|--------|----------|
| 接口覆盖度 | 逐一对比用户故事与api_list.md中的接口 |
| 字段支撑度 | 逐一检查接口响应字段是否在数据字典中有对应 |
| 审计字段完整性 | 检查schema.sql中所有CREATE TABLE语句是否包含5个审计字段 |
| 敏感字段标注 | 检查含敏感关键词的字段是否标注了加密/脱敏 |
| 角色权限完整性 | 检查api_list.md中每个接口是否指定了角色 |

**6.2 问题分级处理**

- **可自动修复**（如遗漏审计字段、缺少索引、敏感字段未标注）：直接修改对应的产出文件，记录修正内容
- **需人工判断**（如需求逻辑矛盾、接口与功能映射存疑、设计取舍）：标记为 `[待人工确认]`，**不得擅自修改设计制品**

**6.3 自动修复轮次控制**

最多执行3轮自动修复，每轮流程：
1. 全量交叉校验 → 识别问题
2. 自动修复"可自动修复"类问题
3. 重新校验确认修复效果

若3轮后仍有未解决的可自动修复问题，停止自动修复，剩余问题全部标记为 `[待人工确认]`。

**6.4 生成校验报告**

生成 `{output_dir}/verification_report.md`：

```markdown
# 合规与一致性校验报告

## 校验概要

| 指标 | 结果 |
|------|------|
| 接口覆盖度 | 100% (8/8 用户故事已覆盖) |
| 字段支撑度 | 100% (45/45 响应字段有对应) |
| 审计字段完整性 | 100% (6/6 表包含5项审计字段) |
| 敏感字段标注率 | 100% (12/12 敏感字段已标注) |
| 角色权限覆盖率 | 100% (15/15 接口已指定角色) |

## 修复记录

### 第1轮修复
| 问题 | 文件 | 修正操作 | 状态 |
|------|------|----------|------|
| 表patient_info缺少is_deleted字段 | schema.sql | 补充is_deleted字段 | ✅ 已修复 |
| GET /api/v1/wards未标注角色 | api_list.md | 添加角色：医生,护士 | ✅ 已修复 |

### 第2轮校验
校验通过，无新问题。

## 待人工确认

| 问题 | 涉及文件 | 初步建议 |
|------|----------|----------|
| 接口GET /api/v1/reports与用户故事US-05映射存疑 | api_list.md | 建议确认US-05是否需要独立的报告查询接口 |
```

### 步骤7：生成执行索引与错误日志

**7.1 生成执行索引**

生成 `{output_dir}/execution_index.json`：

```json
{
  "pipeline": "architecture_design",
  "mode": "ready_for_org",
  "timestamp": "<当前ISO时间>",
  "upstream": {
    "prd": "DOCS/{需求号}/需求设计/requirement.md",
    "prototype": "DOCS/{需求号}/需求设计/prototype/",
    "task_list": "DOCS/{需求号}/任务拆分/task_list.md",
    "upstream_index": "DOCS/{需求号}/execution_index.json"
  },
  "artifacts": {
    "tech_stack": "DOCS/{需求号}/架构设计/tech_stack.md",
    "architecture_design": "DOCS/{需求号}/架构设计/architecture_design.md",
    "module_design": "DOCS/{需求号}/架构设计/module_design.md",
    "schema": "DOCS/{需求号}/架构设计/schema.sql",
    "data_dictionary": "DOCS/{需求号}/架构设计/data_dictionary.md",
    "api_spec": "DOCS/{需求号}/架构设计/api_spec.yaml",
    "api_list": "DOCS/{需求号}/架构设计/api_list.md",
    "coding_guidelines": "DOCS/{需求号}/架构设计/coding_guidelines.md",
    "verification_report": "DOCS/{需求号}/架构设计/verification_report.md",
    "execution_index": "DOCS/{需求号}/架构设计/execution_index.json",
    "error_log": "DOCS/{需求号}/架构设计/error.log"
  },
  "modules": ["从module_design.md提取的模块名列表"],
  "api_function_map": { "POST /api/v1/leaves": "提交请假申请" }
}
```

> 临时模式下，`mode` 为 `"ready_for_org"`，upstream和artifacts中的路径使用最终的 `DOCS/{需求号}/` 前缀（因为这些路径在组织模式迁移后才会生效）。`timestamp` 使用当前时间的ISO 8601格式。

**7.2 生成错误日志**

将所有异常事件写入 `{output_dir}/error.log`，格式：

```
[YYYY-MM-DD HH:mm:ss] [LEVEL] 步骤描述：具体消息
```

日志级别：
- `INFO`：正常操作里程碑
- `WARN`：降级处理（如跳过原型分析）、自动修复操作、待人工确认项
- `ERROR`：需人工介入的严重问题

示例：
```
[2026-05-20 14:30:00] [INFO] 步骤0通过：6/6知识库文件就绪
[2026-05-20 14:30:10] [WARN] 步骤2原型目录不存在，跳过原型分析继续执行
[2026-05-20 14:30:20] [INFO] 步骤3完成：生成6张表，12个索引
[2026-05-20 14:32:00] [WARN] 步骤6第1轮自动修复：为表patient_info补充is_deleted字段
[2026-05-20 14:33:00] [INFO] 步骤6第2轮校验通过，0个新问题
```

在临时模式结束时，确认所有11个文件（10个产物 + 1个error.log）已写入 `{output_dir}`，输出成功摘要。

---

## 临时模式完成返回

全部步骤（0~7）执行完毕后返回：

```
状态: ready_for_org
临时目录: {temp_output_dir}
产物清单:
  - tech_stack.md
  - architecture_design.md
  - module_design.md
  - schema.sql
  - data_dictionary.md
  - api_spec.yaml
  - api_list.md
  - coding_guidelines.md
  - verification_report.md
  - execution_index.json
  - error.log
```

---

## 组织模式完整流程

接收到 `需求号` 和 `temp_output_dir` 后执行：

1. **创建目标目录**：确认 `DOCS/{需求号}/` 存在，若不存在则报错。在 `DOCS/{需求号}/` 下创建 `架构设计/` 子目录（若不存在）。

2. **迁移产物文件**（11个文件）：

| 源路径 | 目标路径 |
|--------|----------|
| `{temp}/架构设计/tech_stack.md` | `DOCS/{需求号}/架构设计/tech_stack.md` |
| `{temp}/架构设计/architecture_design.md` | `DOCS/{需求号}/架构设计/architecture_design.md` |
| `{temp}/架构设计/module_design.md` | `DOCS/{需求号}/架构设计/module_design.md` |
| `{temp}/架构设计/schema.sql` | `DOCS/{需求号}/架构设计/schema.sql` |
| `{temp}/架构设计/data_dictionary.md` | `DOCS/{需求号}/架构设计/data_dictionary.md` |
| `{temp}/架构设计/api_spec.yaml` | `DOCS/{需求号}/架构设计/api_spec.yaml` |
| `{temp}/架构设计/api_list.md` | `DOCS/{需求号}/架构设计/api_list.md` |
| `{temp}/架构设计/coding_guidelines.md` | `DOCS/{需求号}/架构设计/coding_guidelines.md` |
| `{temp}/架构设计/verification_report.md` | `DOCS/{需求号}/架构设计/verification_report.md` |
| `{temp}/架构设计/execution_index.json` | `DOCS/{需求号}/架构设计/execution_index.json` |
| `{temp}/架构设计/error.log` | `DOCS/{需求号}/架构设计/error.log` |

   - 使用文件系统的move/copy操作迁移每个文件
   - 若目标文件已存在且内容不同，备份旧文件为 `{filename}.bak.{timestamp}`

3. **更新索引文件**：修改 `DOCS/{需求号}/架构设计/execution_index.json`：
   - `mode` 更新为 `"success"`
   - `artifacts` 中所有路径更新为最终路径（`DOCS/{需求号}/架构设计/...`）
   - `upstream` 中所有路径更新为最终路径

4. **返回成功**：
```
状态: success
产物路径:
  tech_stack: DOCS/{需求号}/架构设计/tech_stack.md
  architecture_design: DOCS/{需求号}/架构设计/architecture_design.md
  module_design: DOCS/{需求号}/架构设计/module_design.md
  schema: DOCS/{需求号}/架构设计/schema.sql
  data_dictionary: DOCS/{需求号}/架构设计/data_dictionary.md
  api_spec: DOCS/{需求号}/架构设计/api_spec.yaml
  api_list: DOCS/{需求号}/架构设计/api_list.md
  coding_guidelines: DOCS/{需求号}/架构设计/coding_guidelines.md
  verification_report: DOCS/{需求号}/架构设计/verification_report.md
  execution_index: DOCS/{需求号}/架构设计/execution_index.json
  error_log: DOCS/{需求号}/架构设计/error.log
```

## 降级与容错策略

| 场景 | 处理方式 |
|------|----------|
| 原型目录不存在/为空 | 记录WARN日志，跳过原型分析，仅基于需求文档进行模块设计 |
| `architecture_patterns.md` 中未找到明确的分层惯例 | 采用通用三层架构（Controller-Service-Repository），在architecture_design.md中注明 |
| API设计标准中缺少错误码体系 | 采用标准HTTP状态码 + 自定义业务错误码格式 `{code: number, message: string}` |
| 编码规范文件内容过于简略 | 补充业界通用最佳实践（如阿里巴巴Java开发手册的通用规范） |
| 需求文档中未包含完整用户故事 | 从功能点描述中反推用户故事，在verification_report.md中标记为"基于功能点推断" |
| 模块设计与任务拆分粒度不匹配 | 在module_design.md中标注映射关系，粒度差异在verification_report.md中记录 |

## 关键约束

- **步骤0不可跳过**：6个知识库文件必须全部就绪才继续。这是硬性约束。
- **步骤1不可默认**：4个技术决策必须全部有答案。不允许使用默认值替代用户确认（可能影响合规性）。
- **审计字段不可遗漏**：每个表的DDL必须包含5个审计字段。步骤6会自动检测并修复遗漏。
- **敏感数据不可忽略**：含姓名、身份证、电话、病历等关键词的字段必须标注加密/脱敏。
- **角色权限不可缺失**：每个API接口必须关联至少一个角色。
- **自动修复有上限**：步骤6自动修复不超过3轮，超出后标记待人工确认。
