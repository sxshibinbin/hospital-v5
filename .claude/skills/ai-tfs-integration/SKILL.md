---
name: ai-tfs-integration
description: TFS 2018 集成技能：工作项管理与代码提交检查。
  触发关键词：工作项、需求、bug、Bug、BUG、任务、Task、issue、问题。
  使用方式：用户提到上述关键词 + 工作项ID时自动触发，例如"查询工作项12345"、"分析需求67890"、"查看bug11111"。
  **v2.1.0重大更新**：父需求状态按TFS规范顺序流转（新建议→活动→已分析）；新增步骤7.5.1.6确保其他子任务状态流转到活动；与ai-prd-auto v1.28.0协同。
  **v2.0.0重大更新**：需求分析子任务完整状态流转（活动→已解决→已关闭）；父需求状态强制更新为已分析；明确其他子任务保持活动状态。
  **v1.9.0重大更新**：新增子任务创建数量验证机制，确保创建数量与任务索引一致；状态更新后强制验证实际状态，确保使用正确的状态值。
  **v1.8.0重大更新**：需求分析子任务完成后自动添加AI-AUTO-DEV和AI-ANALYSIS标签，与父需求标签保持一致；add-tags命令支持为子任务添加标签。
  **v1.7.0重大更新**：简化配置结构，移除targetProjects、collections和analysisHours配置项，使用defaultProject作为唯一项目配置。
tags: [tfs, 工作项, 需求管理, devops, 集成, 研发中心, 产品名称, 子任务标签, 子任务数量验证, 状态验证, 完整状态流转, 顺序状态流转]
keywords: [TFS, ai-tfs-integration, 工作项, 需求, bug, 任务, issue]
metadata:
  author: AI事业部
  version: 2.1.0
  changelog: |
    - v2.1.0: **顺序状态流转机制** - 父需求状态必须按TFS规范顺序流转（新建议→活动→已分析），不允许跨状态跳转；新增步骤7.5.1.6确保其他子任务状态从"已建议"流转到"活动"；与ai-prd-auto v1.28.0协同
    - v2.0.0: **完整状态流转机制** - 需求分析子任务必须完整流转到已关闭状态（活动→已解决→已关闭两步流转）；父需求状态强制更新为已分析并验证；其他子任务保持活动状态不修改；与ai-prd-auto v1.27.0协同
    - v1.9.0: **子任务创建与状态验证机制** - 新增子任务创建数量验证；状态更新后强制验证实际状态值；修复子任务状态流转错误（使用resolvedState而非finalState）；修复父需求状态更新缺失（强制使用analysisCompleteState）
    - v1.8.0: **子任务标签功能** - 需求分析子任务完成后自动添加AI-AUTO-DEV和AI-ANALYSIS标签，与父需求标签保持一致；add-tags命令可同时为父需求和子任务添加标签
    - v1.7.0: **配置结构简化** - 移除targetProjects、collections和analysisHours配置项，使用defaultProject作为唯一项目配置
    - v1.6.0: **研发中心和产品名称配置** - 新增rdcCenter和productName顶层配置字段；子任务状态流转改为新建议-活动-已解决-已关闭
    - v1.5.0: **枚举值配置统一管理** - 状态流转、标签规范等枚举值统一从config/tfs-config.json读取
    - v1.4.0: 新增update-fields命令，支持批量更新工作项字段
    - v1.3.0: create-child-task命令新增子任务状态和预估工时支持
    - v1.2.0: 创建需求时自动填充"指派给"字段
    - v1.1.0: 新增TFS操作执行指令章节，支持update-state、create-child-task、add-tags命令
---

# TFS 2018 Integration

本技能提供 TFS 2018 集成，支持工作项管理和代码提交检查。

## 🎯 触发条件

当用户提到以下**关键词 + 工作项ID**时，自动触发此技能：

**关键词列表**：

- 工作项、需求、bug、Bug、BUG、任务、Task、issue、问题
- 示例触发语句：
  - "查询工作项 12345"
  - "分析需求 67890"
  - "查看 bug 11111"
  - "工作项 135557 怎么样了"
  - "帮我看看任务 99999"

**触发模式**：`关键词` + `数字ID`

## 🔧 集合管理（必读）

本技能支持多个集合，需要在首次使用时配置。

### 枚举值配置读取（v1.7.0 简化配置结构）

**核心原则**：所有枚举值（状态流转、标签规范）统一从配置文件读取，不再硬编码。

**配置文件路径**：`./config/tfs-config.json`

**配置读取方式**：
```
# 执行任何涉及枚举值的操作前，首先读取配置文件
Read .claude/skills/ai-tfs-integration/config/tfs-config.json

# 配置结构（v2.2.0）
{
  // 顶层组织信息配置（不同项目配置不同值）
  "rdcCenter": "AI事业部",       // 研发中心名称
  "productName": "WiNEX",        // 产品名称

  // 基础连接配置
  "serverUrl": "...",
  "defaultProject": "...",       // 默认项目（唯一项目配置）

  "enums": {
    "stateFlow": {          // 状态流转配置
      "requirement": { "states": [...], "initialState": "...", "analysisCompleteState": "..." },
      "task": { "states": ["新建议", "活动", "已解决", "已关闭"], "resolvedState": "已解决", "finalState": "已关闭" },
      "bug": { "states": [...], "initialState": "...", "resolvedState": "..." }
    },
    "tags": {               // TFS标签配置
      "autoDev": "AI-AUTO-DEV",
      "analysis": "AI-ANALYSIS",
      "ready": "AI-READY",
      "coding": "AI-CODING",
      "unit-test": "AI-UNIT-TEST",
      "autoDone": "AI-AUTO-DONE"
    },
    "workItemTypes": { ... }, // 工作项类型
    "childTaskNaming": { ... } // 子任务命名规则
  }
}
```

**组织信息使用示例**：
```
# 创建需求或文档时，引用研发中心和产品名称
需求标题: "{config.productName}患者卡功能优化"
研发中心: {config.rdcCenter}

# 创建PRD文档时自动填充组织信息
PRD基本信息:
  研发中心: {config.rdcCenter}
  产品名称: {config.productName}
```

**枚举值使用示例**：
```
# 更新状态时，从enums.stateFlow读取状态值
node tools/tfs-query.mjs update-state <ID> "{config.enums.stateFlow.requirement.analysisCompleteState}" "需求分析已完成"

# 打标签时，从enums.tags读取标签名
node tools/tfs-query.mjs add-tags <ID> {config.enums.tags.autoDev}
```

> **v1.7.0 变更**：移除targetProjects、collections和analysisHours配置项，简化配置结构。项目使用defaultProject作为唯一配置，子任务预估工时根据任务内容实际估算。

### 默认集合选择规则

1. **初次使用或默认集合未设置时**：
   - 必须询问用户："请选择默认集合"
   - 用户选择后，使用 `set-collection` 命令保存为默认集合

2. **用户说"切换集合"时**：
   - 列出所有集合供用户选择
   - 使用 `set-collection` 命令更新默认集合

3. **查询工作项时的行为（完整流程）**：

   **步骤1：搜索需求分析内容**
   - 工作项 ID 触发时，首先读取 `./assets/references/user/content.md`
   - 在文件中搜索该工作项 ID 的相关内容
   - 使用 Grep 工具：`Grep -pattern "<工作项ID>" -path "./assets/references/user" -output_mode content`
   - 如果找到相关内容，提取并记录

   **步骤2：查询 TFS 工作项详情**
   - 如果用户只提供工作项 ID（如 "查询 135557"）：
     - 先在默认集合中查找
     - 如果找不到，提示用户该工作项不在默认集合中，询问是否切换集合
   - 如果用户明确指定集合（如 "查询 WINNING-6.0 中的 135557"）：
     - 使用指定集合查询（临时，不改变默认集合）

   **步骤3：结合展示**
   - 将步骤1的需求分析内容与步骤2的 TFS 工作项详情结合
   - 提供完整的分析报告

4. **查询项目时的行为**：
   - 自动识别项目所属集合并切换（临时，不改变默认集合）

### 集合管理命令

```bash
# 查看所有集合
node tools/tfs-query.mjs collections

# 设置默认集合（用户选择后执行）
node tools/tfs-query.mjs set-collection <集合名>

# 查看当前默认集合
node tools/tfs-query.mjs collections | grep "默认"
```

## 🔍 代码变更分析流程（工作项关联代码提交时）

当用户提到需求/工作项/bug **并提交代码**时，执行以下完整分析流程：

### 场景1：用户提到"需求" + 需求号

**分析步骤**：

1. **查询需求详情**：获取需求的基本信息和需求分析内容
2. **查询子工作项**：获取该需求下的所有子任务和Bug
3. **列举上下级关系**：在输出中明确展示需求与子项的层级关系
4. **查询关联提交**：对每个子工作项，查询关联的代码提交
5. **分析代码变更**：汇总所有代码变更内容，分析实现范围

**命令流程**：

```bash
# 1. 获取需求详情（含需求分析）
node tools/tfs-query.mjs get <需求ID>

# 2. 获取子工作项列表（使用 workitem-relations 工具）
node tools/get-workitem-relations.mjs <需求ID> children

# 3. 对每个子工作项查询关联的代码提交
node tools/get-workitem-commits.mjs <子工作项ID>

# 4. 汇总分析代码变更内容
```

### 场景2：用户提到"工作项/任务/bug" + 工作项号

**分析步骤**：

1. **查询工作项详情**
2. **向上追溯父需求**：查找父级需求工作项
3. **列举完整层级关系**：展示父需求及其所有子项的树状结构
4. **查询所有子项的关联提交**：获取每个子项关联的代码变更
5. **综合分析**：汇总所有代码变更，分析整体实现情况

**命令流程**：

```bash
# 1. 获取工作项详情
node tools/tfs-query.mjs get <工作项ID>

# 2. 向上追溯父需求
node tools/get-workitem-relations.mjs <工作项ID> parent

# 3. 获取父需求的所有子项
node tools/get-workitem-relations.mjs <父需求ID> children

# 4. 对所有子项查询关联的代码提交
node tools/get-all-related-commits.mjs <父需求ID>
```

### 工作项层级关系

```
需求 (Requirement)
├── 任务 1 (Task)
├── 任务 2 (Task)
├── Bug 1
└── Bug 2
```

**规则**：

- 需求可能包含多个子任务和Bug
- 任务/Bug通过"父工作项"链接关联到需求
- 代码提交可能关联到任意层级的工作项

### 代码变更分析内容

对每个关联的代码提交，分析：

1. **提交信息**：提交说明、作者、时间
2. **变更文件**：修改了哪些文件
3. **变更类型**：新增/修改/删除
4. **代码行数**：增加/删除的行数
5. **影响范围**：涉及的模块和功能

### 输出格式

```
========== 需求分析 ==========
需求ID | 标题 | 状态 | 项目
需求分析内容摘要

========== 需求与子项层级关系 ==========
需求 [需求ID] 标题
├── 任务 [子任务ID1] 标题 | 状态
├── 任务 [子任务ID2] 标题 | 状态
├── Bug [BugID1] 标题 | 状态
└── Bug [BugID2] 标题 | 状态

========== 代码变更汇总 ==========
按子项分组的提交记录：
[子任务ID1] - 标题
  提交1: 仓库、文件变更、代码行数
  提交2: 仓库、文件变更、代码行数

[BugID1] - 标题
  提交1: 仓库、文件变更、代码行数

总计: X个提交 | Y个文件变更

========== 合理性分析 ==========
需求合理性分析
代码变更逻辑合理性分析
```

## 🗄️ 仓库缓存系统

### 缓存的作用

由于 TFS 包含大量仓库，如果每次查询都遍历所有仓库会非常慢。仓库缓存系统预先将所有仓库的 ID 和信息保存到本地，实现快速查找。

### 缓存文件

- **位置**：`config/repos-cache.json`（相对于技能目录）
- **内容**：仓库 ID → 仓库信息的映射
- **有效期**：24 小时（过期后自动刷新）

### 更新仓库缓存

用户可以手动更新仓库缓存：

```bash
# 更新仓库缓存（查询所有集合的所有仓库）
node tools/get-repos-cache.mjs
```

**输出示例**：

```
获取最新仓库数据...
项目 WiNEX-BasicInfoService: 226 个仓库
项目 W.in-MVP: 472 个仓库
...

仓库缓存已保存: 1914 个仓库

========== 仓库映射统计 ==========
总计: 1914 个仓库
更新时间: 2026-01-29T10:30:00.000Z
```

### 缓存自动提醒

当查询工作项关联提交时，如果遇到以下情况会自动提醒用户：

1. **缓存不存在**：

   ```
   仓库缓存不存在，请先运行: node tools/get-repos-cache.mjs
   ```

2. **匹配不到仓库**（可能新增了仓库）：
   ```
   未找到关联的代码提交
   可能原因:
     1. 该工作项没有关联代码提交
     2. 仓库缓存可能过期，请运行: node tools/get-repos-cache.mjs
   ```

### 首次使用建议

**首次使用代码变更分析功能前，强烈建议先更新仓库缓存**：

```bash
# 1. 更新仓库缓存
node tools/get-repos-cache.mjs

# 2. 然后查询工作项的代码提交
node tools/get-workitem-commits.mjs <工作项ID>
```

## 🔧 集合管理（必读）

本技能支持以下集合：

| 集合名称           | 描述                         | URL                                                       |
| ------------------ | ---------------------------- | --------------------------------------------------------- |
| **WINNING-6.0**    | 主集合（31个项目）           | http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0    |
| **WN_PH-Platform** | 公共卫生平台集合（19个项目） | http://tfs2018-web.winning.com.cn:8080/tfs/WN_PH-Platform |
| **WN_TECH**        | 技术平台集合（27个项目）     | http://tfs2018-web.winning.com.cn:8080/tfs/WN_TECH        |
| **wn_his**         | HIS产品集合（71个项目）      | http://tfs2018-web.winning.com.cn:8080/tfs/wn_his         |

### ⚠️ 工作项 ID 冲突说明

**重要**：不同集合中的工作项 ID 可能重复（如 135557 在两个集合中都存在，但内容完全不同）。

## 首次使用 - 认证配置

本技能使用相对路径存储配置，配置文件位于技能目录内，支持跨电脑迁移。

### 获取 PAT Token

1. 登录你的 TFS 服务器
2. 点击右上角用户头像 → **安全** → **+添加** → **个人访问令牌**
3. 设置令牌名称（如 "Claude Code"）和有效期
4. 选择权限：**工作项** (读取、管理)、**代码** (读取)
5. 复制生成的令牌

### 配置文件

配置文件位于技能目录内（相对于 SKILL.md）：

```
./config/tfs-config.json
```

配置文件格式：

```json
{
  "serverUrl": "http://your-tfs-server:8080/tfs/DefaultCollection",
  "pat": "your-personal-access-token",
  "defaultCollection": "DefaultCollection",
  "defaultProject": "Your-Project-Name"
}
```

**配置字段说明**:
- `serverUrl`: TFS 服务器地址（必填）
- `pat`: 个人访问令牌（必填，需要工作项读写权限）
- `defaultCollection`: 默认集合名称（可选，默认 WINNING-6.0）
- `defaultProject`: 默认项目名称（可选，创建工作项时自动使用）
- `defaultAssignee`: 默认分配人（可选，创建需求时自动填充"指派给"字段）

**defaultAssignee 配置说明**（v1.2.0 新增）:

创建需求时会自动填充"指派给"字段，优先级如下：
1. **命令行参数**：若在命令中明确指定分配人，使用指定值
2. **配置文件**：若设置了 `defaultAssignee`，使用配置值
3. **自动检测**：尝试通过 PAT 获取当前用户身份

配置格式支持两种：
- 完整格式：`"WINNING\\jia_wl"`（推荐，标准 TFS 格式）
- 简写格式：`"jia_wl"`（自动补全为 `WINNING\jia_wl`）

**示例配置**:
```json
{
  "serverUrl": "http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0",
  "pat": "your-pat-token",
  "defaultCollection": "WINNING-6.0",
  "defaultProject": "WiNEX-Agent",
  "defaultAssignee": "WINNING\\jia_wl"
}
```

> **注意**: 若无法自动获取分配人，系统会提示在配置文件中手动设置 `defaultAssignee` 字段，或在命令中明确指定。

### 使用 Claude Code 配置

首次使用时，直接告诉我：

- "配置 TFS 认证信息，服务器是 xxx，PAT 是 xxx"

我会自动创建配置文件。

## 服务器配置（内置）

**服务器地址**: `http://tfs2018-web.winning.com.cn:8080/tfs/`

**支持集合**:

- `WINNING-6.0` - 主集合（默认）
- `WN_PH-Platform` - 公共卫生平台集合
- `WN_TECH` - 技术平台集合
- `wn_his` - HIS产品集合

**完整 URL**:

- WINNING-6.0: `http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0`
- WN_PH-Platform: `http://tfs2018-web.winning.com.cn:8080/tfs/WN_PH-Platform`
- WN_TECH: `http://tfs2018-web.winning.com.cn:8080/tfs/WN_TECH`
- wn_his: `http://tfs2018-web.winning.com.cn:8080/tfs/wn_his`

> 默认使用 WINNING-6.0 集合。如需查询其他集合的项目，请切换集合。

## 项目列表（内置）

### WINNING-6.0 集合项目

| 项目名称                     | 项目ID                                 | 描述                                               |
| ---------------------------- | -------------------------------------- | -------------------------------------------------- |
| OA4.0                        | `4150312b-3a53-4da7-a8a7-e2bfe7fd970f` | OA系统                                             |
| win-cloud                    | `b46e3a4d-0b96-4d7b-aa4a-216121a1ef73` | -                                                  |
| WiNEX-Copilot                | `a3f67cbb-d375-4a58-a6c8-da448150c495` | -                                                  |
| 售前演示                     | `ddbd09b1-59ea-420d-843d-2f70ef9aa8e8` | -                                                  |
| WiNEX-DCP                    | `f4e79b7d-13e6-4e47-9a17-570d72d4f6ef` | 数据中台                                           |
| W.in-DEMO                    | `fa4a1591-32d3-4e3f-82c2-761005d119a2` | 6.0技术和原型验证项目                              |
| WiNEX-PatientInterests       | `6a84d2a9-b5ce-44e5-bce0-171ad6cd96e1` | 患者权益管理系统                                   |
| W.in-MVP                     | `8c3c22dc-6d35-49b5-8589-3375adb60a84` | 卫宁6.0产品首批交付项目                            |
| WiNEX-MDM                    | `aa8c3418-9ec5-4c9e-8209-e229aeda3cfa` | 卫宁主数据                                         |
| HUMANITY                     | `595b77d4-6f9a-46cf-9aeb-ea2afdef59d6` | 厦门弘爱                                           |
| WiNEX-Cloud                  | `d4361d76-6ff9-4fc3-851c-536d9305c40c` | -                                                  |
| WiNEX-MiddlePlatform         | `8ef8a81d-59bd-455e-a86c-2687ba9b6e03` | WiNEX业务中台                                      |
| WiNEX-Inpatient-2            | `fa2bf9fc-fdc9-4167-ae72-feef8525e1f5` | -                                                  |
| WiNEX-Outpatient             | `e17bb6a1-2677-4695-8202-c3c296bbd05c` | 门诊医生站                                         |
| WiNEX-General                | `250f7599-5c8c-4e93-892c-71157224ae73` | -                                                  |
| WiNEX-Integration            | `7c4d1061-6885-4c24-8096-1e1fc9795432` | 集成组相关项目（FHIR对接、主数据对接、第三方接口） |
| MiddlePlatform               | `5c6e7482-f12f-418d-8994-bc5aeaea75a8` | -                                                  |
| WiNEX-CaseHistory            | `739645d0-5770-4efc-98d3-33c98e749837` | 6.0病案                                            |
| Public Query                 | `bad35cc1-f0d6-4f80-8ba0-6f166b3ef6be` | 仅做公共共享查询                                   |
| WiNEX_WXP                    | `89f17307-4986-4251-a04f-e534f9a1b99d` | -                                                  |
| UED                          | `58e8e9b0-5975-48d2-af2d-2719222c7ff0` | UED                                                |
| WiNEX-Inpatient              | `9e4a971d-4027-4c9a-b55b-f0b74487afb5` | 住院大临床项目                                     |
| WiNEX-Triage                 | `af9ab1c7-72ef-42cf-91a3-ef771be43f5a` | WiNEX门诊护士站                                    |
| WiNEX-Emergency              | `5f498025-58dd-4ba0-8137-3fc962e1acaf` | WINEX 急诊                                         |
| WiNEX-Management             | `e92e726a-8dbe-4385-998f-58182a4ddb1c` | 智慧管理类产品                                     |
| WiNEX-Taikang                | `af798a82-646e-467a-8f90-8f3b2c9c39a4` | 泰康合作人员专用项目                               |
| WiNEX-BasicInfoService       | `7dfa9b49-818c-4765-8aae-aec1304af4e9` | -                                                  |
| WiNEX-Specialized            | `8f70e3be-75e3-4969-a3fb-93481dc2c589` | WiNEX专科项目                                      |
| WINEX-ConfigManage           | `18eb3c40-2667-435f-80df-51ce43b24935` | -                                                  |
| WiNEX-HospitalAdministration | `6dcd7f28-99b5-4f43-8877-82230e999906` | -                                                  |
| WiNEX-MY                     | `6cdb1969-bbbc-4ea2-818a-ae29389df42e` | -                                                  |

### WN_PH-Platform 集合项目

| 项目名称             | 项目ID                                 | 描述          |
| -------------------- | -------------------------------------- | ------------- |
| PerformanceAppraisal | `b173ae90-c623-4573-9365-fee7fa0d6cef` | 绩效考核      |
| NETHIS5.5            | `0cdc2e36-9e43-46d1-bd33-07d5f0e9bb51` | -             |
| REPC                 | `f306bba8-fae2-4ed6-91e0-a0d26713aed6` | -             |
| VTE                  | `b3d28916-ddc0-49a6-a2bd-c5dd0e3d46d0` | -             |
| RegionalHealth       | `63288f13-4c4c-47b1-8d4d-eef71161018c` | 区域健康      |
| RCIS                 | `6ba0cd93-729f-42cc-a3fa-d5610c5fd3b6` | -             |
| RFDS                 | `c304239f-158d-4ac5-ad53-035b888da0e4` | -             |
| M-360                | `88ae4488-02e5-49e4-a527-5cce9e5ac0dd` | -             |
| CDC-Software         | `77a3e392-b5de-49bd-bb93-21cf8c01b5c4` | -             |
| GCP                  | `47813526-b35b-489f-b6a4-1f59e6b9c99b` | -             |
| RPES                 | `449cd3b0-d7d1-477a-98d9-6e1a7132bbcc` | -             |
| 健康医养             | `9c1e3237-e3e8-46ab-9af7-770c3a7ceb8d` | -             |
| RMCHS                | `5d01544b-3365-4970-ba64-75acc131eca0` | -             |
| 区域院感             | `628905fd-df70-43ef-a98f-dbf268c66661` | -             |
| RPHIS                | `2d76773b-ace4-4861-aea5-ebe03119a5a0` | -             |
| WiNEX-PublicHealth   | `d5a8550c-3ced-4742-83ae-9dd4c7a548aa` | WiNEX公共卫生 |
| 家庭医生             | `5d84c707-3f96-4c3f-94f9-1bcc2304c77c` | -             |
| 基本医疗             | `f68e2fb9-c732-45cc-a102-4b9f3c38b57f` | -             |
| Cloud_His60          | `10640cd1-567d-4586-aa7c-3942e1627010` | -             |

### WN_TECH 集合项目

| 项目名称                 | 项目ID                                 | 描述 |
| ------------------------ | -------------------------------------- | ---- |
| BIS60                    | `1d989ffb-59c3-487c-9d09-c0b6362d3a40` | -    |
| UED                      | `f286da57-ca5d-4525-b66d-bf21ff2ed66d` | -    |
| LIS60                    | `95ce4d88-d5cf-43dd-8c19-cfe57e51cc10` | -    |
| MIIS                     | `f596a6ab-558f-491c-8ce5-36f3d908c77f` | -    |
| PACSPLUS_PEM_CLoudView   | `ddd08d7f-71c4-4578-80f5-3440891440a5` | -    |
| TechBookCenter           | `748161b2-80d5-48a3-94f3-576b8bc7ea8d` | -    |
| HDIS                     | `c7dabbab-5a27-4f8d-b7f3-241116ccb4fc` | -    |
| 01 PACS-区域影像诊断系统 | `047a723f-118b-4777-b412-dfce8f4efbf6` | -    |
| MIIS_APPLYSHEET          | `36b0ae9d-3d92-482c-b99a-c4b5ec5fe0b2` | -    |
| PACS_Viewer              | `6cc17d90-ab03-4223-82f3-17563f858bff` | -    |
| COMMON_WJZ               | `222b5054-73b7-42f8-bca0-836645c65489` | -    |
| MIIS_BL                  | `a48f079b-d20f-4268-a274-a3c1fdcff424` | -    |
| PACSPLUS_Platform        | `24291c93-f7e3-4354-bff4-3186a3afab34` | -    |
| HLE                      | `aa17466a-99d3-4a4e-a210-d4711b6ecd0d` | -    |
| 全院检查预约             | `f9dd07ea-a4ab-4f60-913c-ac66b23d56a4` | -    |
| LIS60_KS                 | `3dff956f-3f7f-439b-b619-fc121fd6ad38` | -    |
| MIIS_RMC                 | `7d5e640d-4168-4274-bf3a-344b0f1d70f2` | -    |
| LIS60_WSW                | `d0053b6d-a8ce-4a85-acf9-68b6e065b8d0` | -    |
| PACS_DICOMServer         | `e6101d04-72af-4dd0-855a-89b41b485be1` | -    |
| LIS60_ZK                 | `20f22ad0-de5c-4904-911c-cb5e64a2efe1` | -    |
| LIS60_LJ                 | `c1f6b664-8684-4a87-aa92-7ef982854e5f` | -    |
| LIS60_CG                 | `a31c733c-0b73-48d4-9d77-ef5836a26925` | -    |
| CLOUD_RIS                | `7e334cd2-6cda-4d53-aaf5-5a68e09ab507` | -    |
| LIS50                    | `400a0e87-6fab-430b-b488-7f101c994d70` | -    |
| BIS60_SQD                | `c9482856-4442-44f3-8f4c-dfe4ea3e5f91` | -    |
| WiNEX_PACS               | `08817ae4-e290-482b-9271-9a20d003409e` | -    |
| COMMON_FRAME             | `ff925c08-2aa3-4a41-aae3-a52ac3dfe0c9` | -    |
| COMMON_WEBREPORT         | `8c7489ef-8b3d-4c29-b013-791d793fa6b7` | -    |

### wn_his 集合项目

| 项目名称          | 项目ID                                 | 描述 |
| ----------------- | -------------------------------------- | ---- |
| EAHis             | `202b20c2-d536-491f-80cb-75fee0acc1ba` | -    |
| WinningReport     | `72a40fda-43c2-40fe-9408-b32aa31419b1` | -    |
| Framework_His     | `c63e4f11-006c-4f13-906d-4311d872138e` | -    |
| 患者服务平台      | `a24b77e6-b5f1-48a0-a5d8-926d89307318` | -    |
| DMS               | `9154bc39-d8f8-45f4-abe6-c16289a39ea1` | -    |
| 传染病疫情监测    | `a9d19e50-f8a3-4f22-80d3-d878d53430ff` | -    |
| WiNEX-HOCC        | `97f8d3d0-c949-4ad4-8aef-d0b1de7322b0` | -    |
| ACIS              | `2969d9de-1d7a-410f-8d5c-bb39610f6a9d` | -    |
| 移动医生站        | `7a3c28f2-861f-4046-b79e-6dede52a4d8f` | -    |
| Framework         | `76afaec7-fac6-404e-a758-1de96e5c7f72` | -    |
| MDM               | `0ada6b32-9023-4a07-aeb8-0ef0e2c6f021` | -    |
| ConfigTest        | `5ef9025e-fa6e-4166-83ce-33611a1d340e` | -    |
| Manage            | `5aff193f-ca33-483a-9d62-0a385bbd5e07` | -    |
| CIS               | `6330259e-25fe-40a8-949f-e75043742644` | -    |
| 体检管理          | `995ee813-a3a2-4a87-a998-9dbd55c1bf50` | -    |
| DRG               | `ebb866c7-b321-4e98-adaa-f48965a566d2` | -    |
| ONDS              | `5aa95afb-5cbb-4f96-b436-a8e82f3c6b8f` | -    |
| 智能导医机器人    | `edb39a45-4c76-4aa9-a5db-0ff197691e15` | -    |
| EC                | `65bfb1c1-c22f-442b-96e9-15ce474f475d` | -    |
| NIS               | `77acde39-5acb-473d-8cfb-96c6ee4a555d` | -    |
| PublicTech        | `5185b220-eb7a-415c-933c-7d140069f370` | -    |
| QA                | `afd04791-e5e9-4719-8666-80b333beda83` | -    |
| 4.0产品后台       | `7a9b4296-d6e6-40d6-860f-630b3bab4a62` | -    |
| 移动护理          | `d0458819-d170-4968-b41e-d15dc29bb3df` | -    |
| 智能预问诊        | `7a8fd1c5-a84d-4aeb-b9f4-07b3c33f5b36` | -    |
| EDIS              | `7d239b65-9108-40b8-bd5e-3b8503d2d75c` | -    |
| 自助机(HSS)       | `74656d37-4852-47ae-ad3d-e5add5afb95b` | -    |
| 863计划           | `7a57edef-290a-4183-8aae-8cde94c83623` | -    |
| TestDept          | `0ae9b5b8-2e82-41bf-9d2b-fb350d5c1436` | -    |
| 一站式住院服务    | `93ac68c2-3468-4b38-a16a-46cdb5e9140e` | -    |
| CHD               | `feba9583-3e53-497f-aa5d-22809dbe9189` | -    |
| 控费管理          | `79bd010e-d0c7-41a0-841d-4a3a02b8be46` | -    |
| EMPI              | `7cf73c28-ce7d-4bf8-a9ec-592a405823d2` | -    |
| 院感产品          | `382aaaa0-feec-4df6-9988-36364b77a7d2` | -    |
| ET-INTERNET       | `8b959d05-77f1-44d6-90e5-0d2dba1bec75` | -    |
| EMNIS             | `a74fe9b7-8a17-4d22-8b4e-d6d998823e2a` | -    |
| Cost              | `b9f34327-4229-4a29-8dc9-05ab5fa58613` | -    |
| 数据底座          | `415eb214-b908-4587-a740-fbfbcd7821dc` | -    |
| His_Service       | `2985ed32-c6ea-42f3-997d-ec1ff56626c6` | -    |
| ICIS              | `dc772203-102b-419e-ae52-caf345098648` | -    |
| 口腔门诊          | `8184611b-ec8b-49a3-a39f-655139cf89ac` | -    |
| HPEMS             | `7cc218c0-32e1-434e-9974-44a399257830` | -    |
| Other             | `cc6571ec-11fe-4c44-9d74-d6ed3fd70577` | -    |
| 治疗管理系统      | `ce8262de-b89e-45d8-9e30-7b93c81c45b1` | -    |
| 医院集成平台(ESB) | `f575155c-e507-4f0a-a614-0039bb2d65f5` | -    |
| 移动业务研发中心  | `dba20954-c6af-4ccf-b9f6-0fa71ad39247` | -    |
| MIMIICSP          | `897984fa-fa67-453c-b509-6b3018829dcd` | -    |
| 医疗质量管理      | `2572ff82-ce68-48c5-9eaa-cddc4c2a1ac2` | -    |
| SSO               | `da151662-da3c-4cf0-a7d1-32de20222586` | -    |
| 家床系统          | `4e0c24e8-ab80-48c7-9b6e-d62ab194aef4` | -    |
| HDevManage        | `da249f86-23fd-4cba-9cc7-ca997eb68583` | -    |
| 智慧病区          | `b906ddc1-3db6-4cfc-aed6-b06df70cff8d` | -    |
| COVIDTest         | `bafdf2d3-643a-415c-a4b5-eb9f5553ad2a` | -    |
| 院内互联网服务    | `a9f23fa2-c1fa-434d-b334-5fbbe997ca72` | -    |
| ASMC              | `3a5d40d6-5f30-4afa-bb87-5a2710b23ba8` | -    |
| 康复产品          | `36b731de-e625-4f1a-907f-96b94912134b` | -    |
| CTMS              | `7aa44a50-0e2f-4079-8dae-334a6b6b3762` | -    |
| UED               | `1d9e6213-d799-408e-aa0f-81c242dbf2c4` | -    |
| 人力资源管理      | `3f0c4117-5fe5-47b6-9dd5-309018315585` | -    |
| 护士站分诊        | `2bbd8c7d-7a53-41e8-9b9d-0338e75b9b47` | -    |
| WITECH            | `7d4ece89-7600-41e0-9818-5f50c6f9ceb5` | -    |
| DataHealth        | `ae2351a3-18e8-4f77-90b7-e8d41da11cfd` | -    |
| 手术管理          | `ecd3e07c-6dc3-4c41-94b7-e0b68202cec6` | -    |
| 基础HIS           | `f8c6bb4c-a233-4236-ab2f-3ba50ab507bf` | -    |
| IntegrationTest   | `a409c9b0-8b50-4f13-8933-4cd16b7503c3` | -    |
| TADHIS            | `a74ba90e-12b1-4c45-9dc7-d67c022f416f` | -    |
| THIS5.0解耦       | `494f4d98-7a5c-42fe-a8ef-56186f1dfe4e` | -    |
| 集成平台框架      | `5c74b08c-5c17-4eec-9618-6b8fc609429b` | -    |
| 门诊输液          | `621e10e9-cf47-4b2f-8272-db6b52776b60` | -    |
| IOT               | `20f1b62f-94fd-4c58-bed3-ced4fcfb4ed7` | -    |
| CDSS              | `fc3b14a2-400c-47a0-9135-c7c8b47e6832` | -    |

## TFS 2018 限制与注意事项

### WIQL 查询限制

1. **日期格式**: TFS 2018 要求日期格式为 `YYYY-MM-DD`，不能包含时间部分

   ```javascript
   // 正确的格式
   AND[System.ChangedDate] >= '2026-01-07';

   // 错误的格式（会导致查询失败）
   AND[System.ChangedDate] >= '2026-01-07T10:30:00Z';
   ```

2. **不支持的字段**: TFS 2018 不支持以下字段
   - `System.ClosedDate` - 已关闭日期
   - `System.ResolvedDate` - 已解决日期
   - 替代方案：使用 `System.ChangedDate` 进行日期过滤

### Git API 限制

1. **日期过滤**: `getCommits` API 的 `fromDate` 和 `toDate` 参数在 TFS 2018 中可能不工作
   - 解决方案：客户端已实现日期过滤逻辑
   - 使用 `getCommits(repoId, project, top, days)` 方法，其中 `days` 参数会在客户端进行过滤

2. **性能考虑**: 获取提交详细变更（`getChanges`）非常耗时
   - 建议避免批量获取每个提交的详细变更
   - 优先使用提交中的 `workItems` 数组来判断工作项关联

### 推荐实践

```javascript
// 获取近10天的已解决工作项
const resolvedItems = await client.getRecentResolvedWorkItems(
  'ProjectName', // 项目名称
  10, // 最近10天
  ['Resolved', 'Closed'] // 状态列表
);

// 获取近7天的代码提交（客户端日期过滤）
const commits = await client.getCommits(
  repositoryId,
  project,
  100, // 获取数量
  7 // 最近7天，会自动过滤
);
```

## 📋 TFS操作执行指令（v1.1.0 新增）

**核心原则**：当需要执行TFS操作（改状态、建子任务、打标签）时，**必须使用明确的命令行调用**，而非模糊的自然语言指令。

### 改状态（更新工作项状态）

```bash
# 更新工作项状态
node tools/tfs-query.mjs update-state <工作项ID> <新状态> [评论]

# 示例
node tools/tfs-query.mjs update-state 135557 "已分析" "需求分析已完成"
node tools/tfs-query.mjs update-state 1626166 "Closed" "开发任务已完成"
```

**状态流转规范（从config/tfs-config.json读取）**：

**执行步骤**：
1. 先读取配置文件：`Read .claude/skills/ai-tfs-integration/config/tfs-config.json`
2. 从 `enums.stateFlow` 获取对应工作项类型的状态流转规则
3. 确保状态值符合配置定义的 `states` 数组

| 工作项类型 | 状态流转路径（从配置读取） | 配置路径 |
|------------|----------------------------|----------|
| 需求 | `enums.stateFlow.requirement.states` | 新建议 → 活动 → **已分析** → 已解决 → 已关闭 |
| **子任务** | `enums.stateFlow.task.states` | **新建议 → 活动 → 已解决 → 已关闭** |
| Bug | `enums.stateFlow.bug.states` | 新建议 → 活动 → 已解决 → 已关闭 |

**⚠️ v2.1.0 状态流转必须按顺序执行**：

TFS要求状态必须按顺序流转，不允许跨状态跳转：
- **需求状态流转规则**：必须按顺序：新建议 → 活动 → 已分析 → 已解决 → 已关闭
- **子任务状态流转规则**：必须按顺序：新建议 → 活动 → 已解决 → 已关闭

**顺序流转实现方式**：
```
# 步骤1：查询当前状态
node tools/tfs-query.mjs get <工作项ID>
# 从输出中提取当前状态值

# 步骤2：根据当前状态和目标状态，计算需要经过的中间状态
# 若当前状态是"新建议"，目标状态是"已分析"，需要先流转到"活动"，再流转到"已分析"

# 步骤3：按顺序执行流转
# 例如：从"新建议"到"已分析"
node tools/tfs-query.mjs update-state <ID> "活动" "状态流转第一步"
node tools/tfs-query.mjs update-state <ID> "已分析" "状态流转第二步"
```

**⚠️ v2.0.0 子任务状态流转特殊规则**：

| 子任务类型 | 状态流转要求 | 最终状态 |
|------------|--------------|----------|
| **需求分析子任务** | 完整流转：活动 → 已解决 → **已关闭** | **已关闭** |
| **其他子任务**（后端开发、前端开发等） | 创建后立即流转到活动状态（步骤7.5.1.6） | **活动** |

> **v2.1.0 变更**：父需求状态必须按顺序流转（新建议→活动→已分析），新增步骤7.5.1.6确保其他子任务状态从"已建议"流转到"活动"；与ai-prd-auto v1.28.0协同。
> **v2.0.0 变更**：需求分析子任务必须完整流转到"已关闭"状态（两步流转：活动→已解决→已关闭）；其他子任务保持"活动"状态不修改；与ai-prd-auto v1.27.0协同。
> **v1.6.0 变更**：子任务状态流转改为 **新建议-活动-已解决-已关闭**，增加 `resolvedState` 和 `finalState` 字段支持完整状态流转。
> **v1.5.0 变更**：状态流转规则不再硬编码，统一从配置文件读取。不同项目可在 `tfs-config.json` 中配置不同的状态定义。

### 建子任务（创建子工作项）

```bash
# 创建任务（不关联父需求）
node tools/tfs-query.mjs create-task <项目名> <标题> [描述] [分配人]

# 创建子任务并关联父需求（需要使用create-child-task脚本）
# 注意：create-task命令不支持parentId参数，需要手动关联
# 步骤1：创建任务
node tools/tfs-query.mjs create-task "W.in-MVP" "任务标题" "任务描述" ""

# 步骤2：关联父需求（需要使用TFS UI或API）
# 或使用专门创建的脚本（如tools/create-child-tasks-*.mjs）
```

**创建子任务完整流程**：
1. 先查询父需求获取项目信息：`node tools/tfs-query.mjs get <父需求ID>`
2. 创建任务：`node tools/tfs-query.mjs create-task <项目名> <标题> <描述>`
3. 在TFS UI中关联父需求，或编写临时脚本关联

### 创建需求（v1.2.0 新增自动分配人功能）

```bash
# 创建需求（自动填充"指派给"字段）
node tools/tfs-query.mjs create-requirement [项目] <标题> [描述] [分配人]

# 示例：使用自动分配人（推荐）
node tools/tfs-query.mjs create-requirement "W.in-MVP" "患者卡功能优化" "优化患者卡显示逻辑"
# 输出：自动检测到分配人: WINNING\jia_wl

# 示例：使用默认项目和自动分配人
node tools/tfs-query.mjs create-requirement "患者卡功能优化"

# 示例：手动指定分配人
node tools/tfs-query.mjs create-requirement "W.in-MVP" "患者卡功能优化" "" "WINNING\jia_wl"
# 或简写格式（自动补全）
node tools/tfs-query.mjs create-requirement "W.in-MVP" "患者卡功能优化" "" "jia_wl"
```

**分配人获取优先级**：
1. 命令行参数：若明确指定，使用指定值
2. 配置文件：若设置了 `defaultAssignee`，使用配置值
3. 自动检测：尝试通过 PAT 获取当前用户身份

**若无法自动获取分配人**，系统会提示：
- 在配置文件中手动设置 `defaultAssignee` 字段
- 或在命令中明确指定分配人

### 打标签（添加工作项标签）

```bash
# 添加标签（通过tfs-client.mjs的addTags方法）
# 当前tfs-query.mjs未提供add-tags命令，需通过临时脚本或API调用

# 方案1：编写临时脚本
# 创建 tools/add-tags.mjs：
import TFSClient from './tfs-client.mjs';
const client = new TFSClient();
const result = await client.addTags(<工作项ID>, ['标签1', '标签2']);
console.log('标签已添加:', result);

# 方案2：使用node直接调用（单次执行）
node -e "
import('./tools/tfs-client.mjs').then(async (m) => {
  const client = new m.default();
  const result = await client.addTags(<工作项ID>, 'AI-AUTO-DEV');
  console.log('标签已添加:', result.id);
});
"
```

**TFS标签规范（从config/tfs-config.json读取）**：

**执行步骤**：
1. 先读取配置文件：`Read .claude/skills/ai-tfs-integration/config/tfs-config.json`
2. 从 `enums.tags` 获取标签名称

| 标签 | 配置路径 | 用途 | 添加时机 |
|------|----------|------|----------|
| `{enums.tags.autoDev}` | `enums.tags.autoDev` | 标记自动化开发流程已启动 | 需求分析开始时 |
| `{enums.tags.analysis}` | `enums.tags.analysis` | 标记需求分析完成 | PRD生成完成后 |
| `{enums.tags.ready}` | `enums.tags.ready` | 标记开发任务就绪 | 任务拆分完成后 |

> **v1.5.0 变更**：标签名称不再硬编码，统一从配置文件读取。默认值为 `AI-AUTO-DEV`、`AI-ANALYSIS`、`AI-READY`，不同项目可在 `tfs-config.json` 中配置不同的标签名称。

### 调用方式对比

| 调用方式 | 效果 | 推荐场景 |
|----------|------|----------|
| ❌ `Skill: ai-tfs-integration` + 自然语言指令 | 可能无法正确解析和执行 | 不推荐 |
| ✅ `node tools/tfs-query.mjs update-state ...` | 确定执行，效果可控 | 所有操作场景 |
| ✅ `node tools/tfs-client.mjs` 直接调用API | 完全控制，灵活 | 复杂操作场景 |

---

## 使用方式

### 通过 Claude Code 直接操作

你可以直接要求我执行工作项操作，例如：

- "查询项目中分配给我的任务"
- "获取工作项 12345 的详细信息"
- "查询项目中所有未关闭的 Bug"
- "更新工作项 12345 的状态为进行中"
- "检查项目最近的代码提交"

### 工作项查询示例

```javascript
// 按 ID 查询单个工作项
async function getWorkItem(id) {
  const witApi = await connection.getWorkItemTrackingApi();
  return await witApi.getWorkItem(id, null, null, null, ['All']);
}

// 查询分配给我的活动任务
async function getMyTasks(project) {
  const witApi = await connection.getWorkItemTrackingApi();
  const wiql = `
    SELECT [System.Id], [System.Title], [System.State]
    FROM WorkItems
    WHERE [System.WorkItemType] = 'Task'
    AND [System.State] <> 'Closed'
    AND [System.AssignedTo] = @me
    AND [System.TeamProject] = '${project}'
    ORDER BY [System.ChangedDate] DESC
  `;
  const result = await witApi.queryByWiql({ query: wiql });
  const ids = result.workItems.map((wi) => wi.id);
  return await witApi.getWorkItems(ids, null, null, 'All');
}

// 使用示例
const tasks = await getMyTasks('ProjectName');
console.log(`找到 ${tasks.length} 个任务`);
```

### 创建工作项

```javascript
async function createTask(project, title, description, assignedTo) {
  const witApi = await connection.getWorkItemTrackingApi();
  const document = [
    { op: 'add', path: '/fields/System.Title', value: title },
    { op: 'add', path: '/fields/System.Description', value: description || '' },
    { op: 'add', path: '/fields/System.AssignedTo', value: assignedTo || '' },
    { op: 'add', path: '/fields/Microsoft.VSTS.Common.Priority', value: '2' },
  ];
  return await witApi.createWorkItem(null, document, project, 'Task');
}
```

### 更新工作项状态

```javascript
async function updateState(id, newState, comment) {
  const witApi = await connection.getWorkItemTrackingApi();
  const document = [{ op: 'replace', path: '/fields/System.State', value: newState }];
  if (comment) {
    document.push({ op: 'add', path: '/fields/System.History', value: comment });
  }
  return await witApi.updateWorkItem(null, document, id);
}
```

### 代码提交检查

```javascript
// 获取项目的 Git 仓库
async function getRepositories(project) {
  const gitApi = await connection.getGitApi();
  return await gitApi.getRepositories(project);
}

// 获取最近的提交记录
async function getRecentCommits(project, repositoryId, top = 20) {
  const gitApi = await connection.getGitApi();
  return await gitApi.getCommits(repositoryId, project, null, null, null, top);
}

// 检查提交是否关联工作项
async function checkCommitWorkItems(repositoryId, projectId, commitId) {
  const gitApi = await connection.getGitApi();
  const commit = await gitApi.getCommit(commitId, repositoryId, projectId);
  const workItems = commit.workItems || [];
  return {
    hasWorkItems: workItems.length > 0,
    workItemCount: workItems.length,
    workItems: workItems,
  };
}
```

## 工具文件

技能目录包含以下可执行工具（相对于技能目录）：

| 文件                                | 说明                                                  |
| ----------------------------------- | ----------------------------------------------------- |
| `tools/tfs-client.mjs`              | 完整的 TFS 客户端封装（支持多集合）                   |
| `tools/tfs-query.mjs`               | 命令行查询工具（支持 get/collections/set-collection） |
| `tools/get-repos-cache.mjs`         | **仓库缓存生成工具**                                  |
| `tools/get-workitem-relations.mjs`  | 获取工作项的父/子关系                                 |
| `tools/get-workitem-commits.mjs`    | 查询单个工作项的关联提交（使用缓存）                  |
| `tools/get-all-related-commits.mjs` | 查询需求的所有子项及关联提交                          |
| `tools/get-full-description.mjs`    | 获取工作项完整描述                                    |
| `tools/get-projects.mjs`            | 列出所有项目                                          |
| `tools/analyze-outpatient.mjs`      | 门诊项目分析工具                                      |
| `tools/query-all-workitems.mjs`     | 查询所有工作项                                        |
| `tools/query-recent-tasks.mjs`      | 查询最近任务                                          |
| `tools/setup-config.mjs`            | 设置配置                                              |
| `tools/verify-tfs.mjs`              | 验证 TFS 连接                                         |

## 常见工作项类型和字段

### 工作项类型

- **Task** (任务): New, Active, Closed
- **Bug** (缺陷): New, Active, Resolved, Closed
- **User Story** (用户故事): New, Active, Resolved, Closed

### 常用字段

```
System.Title - 标题
System.Description - 描述
System.State - 状态
System.AssignedTo - 分配给
System.WorkItemType - 工作项类型
System.TeamProject - 所属项目
Microsoft.VSTS.Common.Priority - 优先级 (1, 2, 3)
```

## CLI Commands

```bash
# Add user content
skill-creator add-skill --pwd "./ai-tfs-integration" --title "Title" --content "Content"

# Search documentation
skill-creator search-skill --pwd "./ai-tfs-integration" "query"
```

## User Skills

<user-skills baseDir="assets/references/user">
- content.md
</user-skills>

> 提示：执行任务前请搜索相关内容（参考本文件开头的"执行任务前的必要步骤"）。

## Context7 Documentation

<!-- Context7 projects will be listed here automatically -->
