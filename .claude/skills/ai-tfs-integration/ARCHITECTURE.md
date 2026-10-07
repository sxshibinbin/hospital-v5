# TFS Skills 架构设计文档

> 基于资深软件架构师视角的设计建议
>
> 创建日期: 2026-02-10

---

## 📋 背景

用户需要在现有 `ai-tfs-integration` skill 基础上，新增日常工作项处理功能：
- 检查需求是否有自测报告
- 分析软质单

**核心问题**：是扩展现有 skill 还是新建 skill？

---

## 🎯 推荐方案：新建 skill + 共享 TFS Client

```
skills/
├── ai-tfs-integration/          # 核心：TFS 集成层（基础设施）
│   ├── tools/tfs-client.mjs      # TFS 客户端（可被其他 skill 引用）
│   └── SKILL.md                  # 基础查询、工作项获取等通用功能
│
├── workitem-qa/                  # 新建：工作项质量检查（领域层）
│   ├── SKILL.md
│   ├── package.json
│   └── tools/
│       ├── check-selftest-report.mjs   # 检查自测报告
│       └── analyze-quality-task.mjs    # 分析软质单
│
└── shared/                       # 共享层（可选）
    └── tfs-client-wrapper.mjs    # TFS 客户端封装（如果需要进一步抽象）
```

---

## 📊 架构原则分析

| 原则 | 分析 | 结论 |
|------|------|------|
| **单一职责 (SRP)** | ai-tfs-integration 专注于 TFS 集成；质量检查是业务领域逻辑 | ✅ 分离 |
| **开放封闭 (OCP)** | 扩展新功能不应修改核心集成层 | ✅ 新 skill |
| **依赖倒置 (DIP)** | 业务层依赖 TFS 抽象，而非具体实现 | ✅ 共享 TFS Client |
| **内聚性** | 质量检查功能内部高度相关 | ✅ 独立 skill |
| **复用性** | TFS Client 可被多个 skill 复用 | ✅ 共享依赖 |

---

## 🔄 方案对比

### 方案 A：扩展 ai-tfs-integration

```javascript
skills/ai-tfs-integration/
├── tools/
│   ├── tfs-client.mjs
│   ├── auto-assign-workitems.mjs  # 已有
│   ├── check-selftest-report.mjs  # 新增
│   └── analyze-quality-task.mjs   # 新增
└── SKILL.md  # 变得越来越大
```

**优点：**
- 集中管理，文件少
- 部署简单

**缺点：**
- ❌ 违反单一职责原则
- ❌ SKILL.md 会变得臃肿（通用 + 业务逻辑）
- ❌ 触发关键词会冲突/混乱
- ❌ 不同团队的工作流耦合在一起
- ❌ 难以独立测试和维护

### 方案 B：新建 skill（推荐）✅

```javascript
skills/ai-tfs-integration/        # 核心：TFS 集成
├── tools/tfs-client.mjs           # 可被其他 skill 引用
└── SKILL.md                        # 通用 TFS 操作

skills/workitem-qa/                 # 新建：工作项质量检查
├── SKILL.md
├── package.json
└── tools/
    ├── check-selftest-report.mjs
    └── analyze-quality-task.mjs
```

**优点：**
- ✅ 职责清晰分离
- ✅ 每个 skill 有独立的触发关键词
- ✅ 可独立演进和测试
- ✅ 复用 ai-tfs-integration 的 TFS Client
- ✅ 符合微服务/微内核架构思想

**缺点：**
- 稍微增加文件数量
- 需要处理跨 skill 引用

---

## 🎨 Skill 职责划分

### ai-tfs-integration（基础设施层）

**职责**：TFS 2018 系统的通用集成功能

**功能范围**：
- 工作项查询（按 ID、按 WIQL）
- 工作项详情获取
- 代码提交关联查询
- 仓库缓存管理
- 多集合支持
- TFS 客户端封装（`tfs-client.mjs`）

**触发关键词**：
- 工作项、需求、bug、Bug、BUG、任务、Task、issue、问题

**输出**：
- 通用的工作项数据
- 代码关联信息
- TFS 系统状态

### workitem-qa（业务领域层）

**职责**：工作项质量相关的业务工作流

**功能范围**：
- 自测报告完整性检查
- 软质单分析和分配
- 测试覆盖率统计
- 质量指标计算

**触发关键词**：
- 自测报告、质量检查、软质分析、QA、测试、自测

**依赖**：
- 引用 `ai-tfs-integration/tools/tfs-client.mjs`

---

## 🔧 实现细节

### 1. TFS Client 复用方式

**方案 1：直接引用（推荐）**

```javascript
// skills/workitem-qa/tools/check-selftest-report.mjs
import TFSClient from '../../ai-tfs-integration/tools/tfs-client.mjs';

async function checkSelfTestReport(requirementId) {
  const client = new TFSClient();
  const requirement = await client.getWorkItem(requirementId);

  // 获取子工作项
  const children = await client.getWorkItemRelations(requirementId, 'children');

  // 检查是否有自测报告
  const hasSelfTestReport = children.some(wi =>
    wi.fields['System.WorkItemType'] === '测试用例' ||
    wi.fields['System.Title'].includes('自测')
  );

  return {
    requirementId,
    hasSelfTestReport,
    children: children.map(c => ({ id: c.id, title: c.fields['System.Title'] }))
  };
}
```

**方案 2：封装层（可选，用于更复杂的场景）**

```javascript
// skills/shared/tfs-wrapper.mjs
import TFSClient from '../ai-tfs-integration/tools/tfs-client.mjs';

export { TFSClient };

export function createTFSClient(collection) {
  return new TFSClient(collection);
}

// 提供更高级的抽象
export async function getRequirementWithTests(requirementId) {
  const client = new TFSClient();
  const [requirement, children] = await Promise.all([
    client.getWorkItem(requirementId),
    client.getWorkItemRelations(requirementId, 'children')
  ]);

  return {
    requirement,
    testCases: children.filter(wi =>
      ['测试用例', 'Test Case'].includes(wi.fields['System.WorkItemType'])
    )
  };
}
```

### 2. package.json 依赖管理

```json
// skills/workitem-qa/package.json
{
  "name": "workitem-qa",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "azure-devops-node-api": "*"
  }
}
```

**注意**：TFS Client 通过相对路径引用，无需将 ai-tfs-integration 作为依赖。

### 3. Skill 触发设计

#### ai-tfs-integration 触发

```yaml
触发关键词:
  - 工作项 + 数字ID
  - 需求 + 数字ID
  - bug + 数字ID
  - 任务 + 数字ID

示例:
  - "查询工作项 12345"
  - "分析需求 67890"
  - "查看 bug 11111"
```

#### workitem-qa 触发

```yaml
触发关键词:
  - 自测报告 + 需求ID
  - 质量检查 + 工作项ID
  - 软质分析 + 任务ID
  - 检查测试 + 需求ID

示例:
  - "检查需求 12345 的自测报告"
  - "质量检查工作项 67890"
  - "分析软质单 11111"
```

---

## 📁 workitem-qa Skill 结构示例

```
skills/workitem-qa/
├── SKILL.md                    # Skill 文档
├── package.json                # NPM 配置
├── tools/
│   ├── check-selftest-report.mjs
│   │   └── 功能：
│   │       - 检查需求是否关联自测报告工作项
│   │       - 统计测试用例数量
│   │       - 输出缺失的自测报告列表
│   │
│   ├── analyze-quality-task.mjs
│   │   └── 功能：
│   │       - 分析软质单的完整性
│   │       - 检查分配信息
│   │       - 生成质量分析报告
│   │
│   └── check-test-coverage.mjs
│       └── 功能：
│           - 统计需求的测试覆盖率
│           - 分析测试用例分布
│           - 生成覆盖率报告
│
└── config/
    ├── qa-rules.template.json   # 质量检查规则配置
    └── test-standards.json      # 测试标准配置
```

### SKILL.md 示例

```markdown
---
name: |
  workitem-qa
description: |
  工作项质量检查技能。
  触发关键词：自测报告、质量检查、软质分析、QA、测试。
  使用方式：用户提到上述关键词 + 工作项ID时自动触发。
---

# WorkItem QA - 工作项质量检查

## 🎯 触发条件

- "检查需求 12345 的自测报告"
- "质量检查工作项 67890"
- "分析软质单 11111"

## 🔧 功能

### 1. 自测报告检查
- 验证需求是否关联自测报告工作项
- 统计测试用例数量
- 输出缺失的自测报告列表

### 2. 软质单分析
- 分析软件质量单的完整性
- 检查分配信息
- 生成质量分析报告

### 3. 测试覆盖率检查
- 统计需求的测试覆盖率
- 分析测试用例分布
- 生成覆盖率报告

## 📦 依赖

本技能依赖 `ai-tfs-integration` 的 TFS Client：

\`\`\`javascript
import TFSClient from '../../ai-tfs-integration/tools/tfs-client.mjs';
\`\`\`
```

---

## 🚀 实施步骤

### 第一步：创建 workitem-qa skill

```bash
mkdir -p skills/workitem-qa/tools
mkdir -p skills/workitem-qa/config
```

### 第二步：创建基础文件

```bash
# SKILL.md
# package.json
# tools/check-selftest-report.mjs
# tools/analyze-quality-task.mjs
```

### 第三步：实现 TFS Client 引用

```javascript
// tools/check-selftest-report.mjs
import TFSClient from '../../ai-tfs-integration/tools/tfs-client.mjs';
```

### 第四步：测试复用

```bash
# 验证 TFS Client 可以正常引用
cd skills/workitem-qa
node tools/check-selftest-report.mjs 12345
```

---

## 📌 总结

### 核心原则

| 层次 | Skill | 职责 |
|------|-------|------|
| **基础设施层** | ai-tfs-integration | TFS 系统集成、通用查询 |
| **业务领域层** | workitem-qa | 质量检查业务工作流 |
| **共享层** | shared/（可选） | 通用抽象和工具 |

### 设计优势

- ✅ **单一职责**：每个 skill 职责清晰
- ✅ **分层架构**：基础设施层 vs 业务层
- ✅ **易于扩展**：新增业务逻辑无需修改核心层
- ✅ **易于维护**：独立测试和演进
- ✅ **清晰边界**：触发关键词不冲突

### 未来扩展

这种架构可以轻松支持更多业务 skill：

```
skills/
├── ai-tfs-integration/     # 核心：TFS 集成
├── workitem-qa/             # 质量检查
├── workitem-planning/        # 计划管理（新增）
├── workitem-reporting/       # 报表生成（新增）
└── workitem-automation/      # 自动化工作流（新增）
```

每个业务 skill 都可以：
- 引用 ai-tfs-integration 的 TFS Client
- 定义自己的触发关键词
- 实现特定的业务逻辑
- 独立演进和维护
