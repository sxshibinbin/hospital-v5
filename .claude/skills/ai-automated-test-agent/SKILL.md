---
name: ai-automated-test-agent
description: 全场景自动化测试Agent - 多Agent编排体系中的测试环节，通过需求号关联PRD解析/架构设计/代码审查结果，自动生成单元测试、接口测试、医疗业务场景测试、边界值测试、异常流程测试用例；执行测试并输出完整测试报告，标注bug及风险点。
tags: [test, automation, medical, multi-agent, tfs-integration]
allowed-tools: Bash(mvn:*), Bash(dotnet:*), Bash(python3:*), Read, Write, mcp__tfs-mcp__*
output_format: json_only
keywords: [自动化测试, ai-automated-test-agent, 单元测试, 接口测试, 测试报告, 测试用例]
metadata:
  author: AI事业部
  version: 1.0.0
---

## Skill名称：ai-automated-test-agent

## 功能描述
多Agent编排体系中的自动化测试Agent，通过需求号（TFS work_item_id）关联前置Agent产出物，基于需求分析、架构设计、代码审查结果自动生成并执行全场景测试用例，输出结构化测试报告。

## 核心能力
- **需求号关联**：通过 `work_item_id` 关联 PRD解析Agent、架构设计Agent、代码审查Agent 的产出物
- **智能用例生成**：结合需求文档 + 架构设计 + 代码审查结果，生成精准测试用例
- **多技术栈支持**：Java/Spring Boot（MyBatis/SQL Server）、C# WinForms/WebView2、前端项目
- **全场景覆盖**：正常场景、异常场景、极限边界、权限场景、医疗业务专项
- **测试执行与报告**：执行测试、收集结果、标注bug及风险点（P0/P1/P2/P3分级）
- **Bug修复重测闭环**：P0/P1级别Bug自动分析根因、修复代码、重测验证，最多3轮
- **TFS集成**：测试报告上传、工作项状态回写、评论添加、AI-UNIT-TEST标签自动打标

## 触发关键词
- 自动化测试、生成测试用例、测试报告、单元测试用例、接口测试
- 边界值测试、异常流程测试、医疗业务测试
- 执行测试、test case、test report、test-report-agent
- /test、/auto-test

## ⛔ 安全执行原则（必须遵守）

> **⚠️ 重要警告：Claude Code 安全层会强制拦截以下命令模式！**
>
> **无论如何配置白名单，以下命令都会触发人工确认弹窗，阻断自动执行！**

### 禁止的命令模式

| 禁止模式 | 原因 | 替代方案 |
|----------|------|----------|
| `cd path && cmd` | 安全层强制拦截 | 使用绝对路径或工具参数 |
| `cd path && git ...` | 安全层强制拦截 | `git -C path ...` |
| `cd path && mvn ...` | 安全层强制拦截 | `mvn -f path/pom.xml ...` |
| `cmd1 && cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 ; cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |
| `cmd1 | cmd2` | 安全层强制拦截 | 分开执行，各自独立调用 |

### ✅ 正确命令示例

```bash
# ✅ 正确 - 使用 git -C 参数
git -C worktree-{需求号} status --porcelain
git -C worktree-{需求号} log --oneline -3

# ✅ 正确 - 使用 -f 参数编译/测试
mvn test -f worktree-{需求号}/icis/pom.xml
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests

# ✅ 正确 - 使用绝对路径读取文件
Read worktree-{需求号}/icis/icis-biz-main/src/test/java/...

# ✅ 正确 - 使用 Glob 搜索测试文件
Glob worktree-{需求号}/icis/**/*Test.java

# ✅ 正确 - 单独执行命令（不组合）
# 第一条命令
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests
# 第二条命令（单独调用）
mvn test -f worktree-{需求号}/icis/pom.xml
```

### ⛔ 禁止命令示例（切勿执行）

以下命令会被安全层拦截，导致流程中断：

```bash
# ⛔ 禁止 - 组合命令（安全层拦截）
cd worktree-{需求号} && mvn test
cd worktree-{需求号} && git status

# ⛔ 禁止 - 管道连接符
mvn compile && mvn test
git add -A && git commit -m "msg"

# ⛔ 禁止 - EnterWorktree 工具（会创建错误路径）
# EnterWorktree 工具会在 .claude/worktrees/ 下创建新 worktree
```

## 输入要求

### 必需参数
| 参数名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| task_id | string | 任务唯一标识 | TEST-20260518-001 |
| work_item_id | integer | TFS工作项ID（需求号） | 1500229 |
| product_line | string | 产品线名称 | AI-MY |
| project_name | string | 项目名称 | winning-mmop-winexmy |
| repository_url | string | 代码仓库地址 | https://tfs.winning.com/... |
| source_branch | string | 源分支名称 | feature/user-auth |
| tech_stack_tags | array | 技术栈标签 | ["java", "vue"] |

### 可选参数
| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| collection | string | TFS集合名称 | 自动检测 |
| test_scope | string | 测试范围 | all（all/unit/integration/api） |
| max_fix_retries | int | 修复重测最大轮次 | 3 |
| auto_fix_enabled | bool | 是否启用自动修复 | true |
| prd_result_path | string | PRD解析Agent产出路径 | DOCS/{work_item_id}/PRD解析/ |
| arch_result_path | string | 架构设计Agent产出路径 | DOCS/{work_item_id}/架构设计/ |
| review_result_path | string | 代码审查Agent产出路径 | DOCS/{work_item_id}/代码审查/ |

## 流水线执行流程

### Stage 1: 前置产出物收集
@step/01-collect-inputs.md
- **首先创建** `DOCS/{work_item_id}/自动化测试/` 输出目录并初始化 exec_prog.md
- 通过 work_item_id 定位前置Agent产出物
- 读取 PRD解析Agent 输出（需求分析、功能点清单）
- 读取 架构设计Agent 输出（模块划分、接口定义、依赖关系）
- 读取 代码审查Agent 输出（问题清单、风险点、修复建议）
- 汇总测试要点清单 → `DOCS/{work_item_id}/自动化测试/test_points_{work_item_id}.json`

### Stage 2: 测试用例设计
@step/02-design-testcases.md
- 基于需求功能点 → 生成正常场景用例
- 基于架构接口定义 → 生成接口测试用例
- 基于代码审查问题 → 补充异常场景用例
- 应用边界值分析、等价类划分
- 生成医疗业务专项用例（患者隐私、处方合规、护理记录）
- 输出：测试用例清单（CSV/JSON）→ `DOCS/{work_item_id}/自动化测试/testcases_{work_item_id}.csv`

### Stage 3: 测试代码生成
@step/03-generate-testcode.md
- 根据技术栈选择测试框架模板
- Java/Spring Boot：JUnit 5 + Mockito + MockMvc
- C# WinForms：NUnit + Moq + WebView2 Mock
- 前端项目：Jest + React Testing Library
- 按优先级生成测试代码文件
- 输出：测试代码文件清单 → `DOCS/{work_item_id}/自动化测试/generated_test_files.json`

### Stage 4: 测试执行
@step/04-execute-tests.md
- 执行单元测试（mvn test / dotnet test）
- 执行接口测试（Spring Boot Test / REST Assured）
- 收集测试结果（通过率、失败用例、执行时间）
- 重试机制：失败用例自动重试1次
- 输出：原始测试结果（JUnit XML / TRX）

### Stage 4.5: Bug修复重测循环（自动）
@step/04b-fix-retry.md
- 触发条件：Stage 4 存在 P0/P1 级别失败用例
- 根因分析（13种规则匹配，含3种医疗扩展）
- 代码定位（Grep/Glob 搜索堆栈关键词）
- 生成修复（按 Bug 类型选策略模板，Java/C#/Vue）
- 应用修复 + 编译验证 + 重测
- 修复失败回滚(.bak)，最多重试 3 轮
- P2/P3 仅记录，不自动修复
- 输出：`DOCS/{work_item_id}/Bug修复/` 修复报告 + 汇总JSON

### Stage 5: 报告生成与交付
@step/05-output.md
- 解析测试结果，按P0/P1/P2/P3分级标注bug
- 关联需求号，标注每个用例对应的需求功能点
- 对比架构设计预期，标注偏离项
- 汇总代码审查问题验证情况
- 生成结构化测试报告（Markdown/JSON/HTML）
- 上传TFS附件，回写工作项状态
- 添加 AI-UNIT-TEST 标签（测试完成标记）
- 仅有 P2/P3 Bug 时添加 AI-VERIFY-WARN 标签

## 输出格式
@references/output-schema.json

### 输出示例
```json
{
  "task_id": "TEST-20260518-001",
  "work_item_id": 1500229,
  "status": "completed",
  "summary": {
    "total_cases": 85,
    "passed": 78,
    "failed": 5,
    "skipped": 2,
    "pass_rate": "91.8%"
  },
  "bug_summary": {
    "P0_critical": 0,
    "P1_high": 2,
    "P2_medium": 3,
    "P3_low": 5
  },
  "related_agents": {
    "prd_agent": "PRD-20260518-001",
    "arch_agent": "ARCH-20260518-001",
    "review_agent": "REVIEW-20260518-001"
  },
  "report_files": {
    "local_path": "DOCS/1500229/自动化测试/测试报告_20260518.md",
    "html_path": "DOCS/1500229/自动化测试/测试报告_20260518.html",
    "tfs_attachment_id": 12346
  },
  "next_action": "deploy",
  "completed_at": "2026-05-18T19:30:00Z"
}
```

## 与其他Agent协作协议

### 前置Agent（必须完成）

| Agent | 产出物 | 用途 | 路径模式 |
|-------|--------|------|----------|
| PRD解析Agent | 需求文档、功能点清单、验收标准 | 确定测试范围和验收标准 | `DOCS/{work_item_id}/PRD解析/` |
| 架构设计Agent | 模块划分、接口定义、数据模型 | 确定测试对象和接口契约 | `DOCS/{work_item_id}/架构设计/` |
| 代码审查Agent | 问题清单、风险点、修复建议 | 补充异常场景用例 | `DOCS/{work_item_id}/代码审查/` |

### 后续Agent
- 交付Git运维Agent: 测试通过后触发代码合并

### 协作数据流
```
TFS工作项 (work_item_id)
    │
    ├─→ PRD解析Agent ──→ 需求功能点、验收标准
    │                        │
    ├─→ 架构设计Agent ──→ 接口定义、模块划分
    │                        │
    ├─→ 代码审查Agent ──→ 问题清单、风险点
    │                        │
    │                        ▼
    └─────────────────→ ai-automated-test-agent
                            │
                            ├─ 正常场景用例 ← 需求功能点
                            ├─ 接口测试用例 ← 接口定义
                            ├─ 异常场景用例 ← 审查问题清单
                            ├─ 边界值用例   ← 架构设计约束
                            └─ 医疗合规用例 ← 医疗业务规则
                                │
                                ▼
                            测试报告 → TFS工作项回写
```

## 测试框架速查

### Java/Spring Boot
| 场景 | 框架/工具 | 注解/用法 |
|------|----------|-----------|
| 单元测试 | JUnit 5 + Mockito | `@ExtendWith(MockitoExtension.class)` |
| 接口测试 | Spring Boot Test + MockMvc | `@WebMvcTest` / `MockMvc` |
| 集成测试 | Spring Boot Test | `@SpringBootTest` |
| 数据库测试 | TestContainers + MSSQL | `@Container` / TestContainers |
| 参数化测试 | JUnit 5 Params | `@ParameterizedTest` |

### C# WinForms/WebView2
| 场景 | 框架/工具 | 用法 |
|------|----------|------|
| 单元测试 | NUnit / xUnit | `[Test]` / `[Fact]` |
| Mock | Moq | `new Mock<IInterface>()` |
| WebView2 | Selenium / Playwright | 浏览器自动化 |
| PluginOK | 专用Mock类 | 模拟COM组件调用 |

## 医疗系统测试检查清单

执行测试前，确认以下医疗合规检查项：

- [ ] 患者身份信息加密存储验证
- [ ] 处方剂量范围校验（成人/儿童差异化）
- [ ] 药物相互作用检测触发验证
- [ ] 护理操作记录不可篡改验证
- [ ] 角色权限隔离（医生/护士/管理员）
- [ ] 敏感数据操作日志记录
- [ ] 事务回滚一致性（异常时数据不残留）
- [ ] 接口幂等性（重复提交处理）

## 执行进度文档

运行时生成，路径：`DOCS/{work_item_id}/自动化测试/exec_prog.md`

**更新频率**: 每10分钟自动更新

**记录内容**:
- 当前执行状态和阶段进度
- 前置Agent产出物收集状态
- 测试用例生成统计（按类型、优先级）
- 测试执行进度（已执行/总数、通过率）
- Bug汇总（按P0/P1/P2/P3）
- 与前置Agent关联状态
- 执行日志和预估信息

模板文件：@exec_prog.md

## 使用示例

### 示例1: 基本测试（自动关联前置Agent）
```
测试工作项1500229，产品线AI-MY，技术栈java和vue
```
Agent会自动查找：
- `DOCS/1500229/PRD解析/` → PRD解析结果
- `DOCS/1500229/架构设计/` → 架构设计结果
- `DOCS/1500229/代码审查/` → 代码审查结果

### 示例2: 指定测试范围
```
对工作项1500229进行接口测试，只测试新增的API
```

### 示例3: 完整参数
```json
{
  "task_id": "TEST-20260518-001",
  "work_item_id": 1500229,
  "product_line": "AI-MY",
  "project_name": "winning-mmop-winexmy",
  "repository_url": "https://tfs.winning.com/WINNING-6.0/MY/_git/winning-mmop-winexmy",
  "source_branch": "feature/user-auth",
  "tech_stack_tags": ["java", "vue"],
  "test_scope": "all"
}
```

## 错误处理

| 错误类型 | 处理方式 | 状态码 |
|----------|----------|--------|
| 前置Agent产出物缺失 | 返回错误，列出缺失文件 | 400 |
| TFS连接失败 | 重试3次后返回错误 | 503 |
| 测试用例生成失败 | 使用模板继续，标记跳过项 | 200 |
| 测试执行超时 | 返回部分结果，标记未完成 | 408 |
| 前置Agent未完成 | 等待或返回错误 | 425 |

## 注意事项
1. 首次使用需配置TFS访问权限
2. 必须先完成TFS工作项创建，再启动自动化开发流程
3. 测试数据使用Mock或测试专用数据库，禁止操作生产数据
4. 医疗系统涉及患者隐私，测试数据需脱敏处理
5. 生成的测试用例需人工复核关键业务逻辑
6. 对于MyBatis SQL测试，优先使用TestContainers而不是H2（避免方言差异）
7. 执行前检查前置Agent exec_prog.md 状态，确保已完成
8. Bug修复仅处理 P0/P1 级别，P2/P3 记录但不阻断流程
9. 同一 Bug 最多尝试 3 种修复策略，全部失败标记为"需人工介入"
10. 修复前自动备份原文件(.bak)，修复失败自动回滚
11. 医疗相关修复（剂量/权限/数据完整性）必须在报告中标记人工复核
12. 禁止通过删除/跳过测试用例来提高通过率
13. 测试完成后必须为 TFS 工作项添加 `AI-UNIT-TEST` 标签（过程标签，系统自动添加），标记自动化测试已完成
14. 仅有 P2/P3 Bug 时同时添加 `AI-VERIFY-WARN` 标签
15. `AI-UNIT-TEST` 与 `AI-REVIEWED` 形成阶段配对：审查完成→测试完成

## 报告模板
- Markdown报告：@templates/report-template.md
- Bug修复报告：@templates/bug-fix-report-template.md
- JSON报告模板：@templates/report-template.json.tmpl
- 修复汇总JSON：@templates/fix-summary-template.json
- HTML报告模板：@templates/report-template.html
- 测试用例清单CSV：@templates/testcase-list-template.csv
- Bug清单CSV：@templates/bug-list-template.csv
- Bug修复配置：@config/bug-fix-config.template.json

## 版本历史
- v1.3.0: 新增 TFS 标签 AI-UNIT-TEST + AI-VERIFY-WARN，测试完成后自动打标
- v1.2.0: 新增 Stage 4.5 Bug修复重测闭环，P0/P1自动修复→重测→最多3轮
- v1.1.0: 重构为多Agent协作模式，通过需求号关联前置产出物
- v1.0.0: 初始版本，支持Java/Spring Boot + C# WinForms双技术栈
