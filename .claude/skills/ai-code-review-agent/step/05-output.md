# Stage 5: 输出交付

## 输入
- issues: 问题列表
- summary: 统计摘要
- work_item_id: TFS工作项ID
- product_line: 产品线名称

## 处理步骤

### Step 5.1: 生成本地报告

#### Markdown报告
路径：`DOCS/{work_item_id}/代码审查/审查报告_{timestamp}.md`

模板：
```markdown
# 代码规范审查报告

## 基本信息
| 项目 | 内容 |
|------|------|
| 工作项ID | {work_item_id} |
| 产品线 | {product_line} |
| 审查时间 | {timestamp} |

## 审查摘要
| 指标 | 数量 |
|------|------|
| 问题总数 | {total} |
| 🔴 严重 | {critical} |
| 🟡 警告 | {warning} |
| 🔵 提示 | {info} |

## 阻断状态
**状态**: {status}
**原因**: {block_reason}

## 问题详情
{issues_detail}
```

#### JSON报告
路径：`DOCS/{work_item_id}/代码审查/审查报告_{timestamp}.json`

#### CSV问题清单
路径：`DOCS/{work_item_id}/代码审查/问题清单.csv`

### Step 5.2: 上传TFS附件
使用 `mcp__tfs-mcp__tfs_upload_attachment`：
```
tfs_upload_attachment(
  id: work_item_id,
  filePath: "DOCS/{work_item_id}/代码审查/审查报告_{timestamp}.md",
  comment: "代码规范审查报告"
)
```

### Step 5.3: 更新TFS工作项

#### 添加 AI-REVIEWED 标签

审查完成后，为 TFS 工作项添加 `AI-REVIEWED` 过程标签，标记代码审查已完成。

**标签说明**：
- 标签名：`AI-REVIEWED`
- 分类：过程标签（系统自动添加）
- 含义：代码规范审查已完成（含自动修复后通过审查）
- 添加范围：需求项 + 开发子Task
- 配对关系：上游 `AI-CODING` → `AI-REVIEWED`（审查完成）

**打标流程**：

##### 1. 判断是否添加标签

| 审查结果 | 是否打标 | 标签范围 | 附加标签 |
|----------|---------|---------|---------|
| `passed`（无阻断问题） | ✅ 打标 | 需求项 + 开发子Task | — |
| `no_fixable`（有阻断但无自动修复项） | ✅ 打标 | 仅需求项 | — |
| `blocked` → 进入 Stage 6 | ❌ 暂不打标 | — | 修复完成后在 Stage 6 回归时打标 |
| 审查有残留 warning | ✅ 打标 | 需求项 | `AI-VERIFY-WARN` |

##### 2. 获取子任务 TFS ID

```bash
# 获取父需求下的子任务列表
node .claude/skills/ai-tfs-integration/tools/get-workitem-relations.mjs {work_item_id} children

# 根据任务名称匹配对应的开发子任务 TFS ID
子任务列表中标题包含 "开发" 或 "编码" 的工作项 ID
```

##### 3. 添加标签

方式一 — 使用 TFS MCP 工具：
```
tfs_add_tags(
  id: {work_item_id},
  tags: "AI-REVIEWED"
)

# 如果有开发子Task，也给子Task添加
tfs_add_tags(
  id: {子任务TFS_ID},
  tags: "AI-REVIEWED"
)

# 如果审查有残留warning，追加 AI-VERIFY-WARN
tfs_add_tags(
  id: {work_item_id},
  tags: "AI-VERIFY-WARN"
)
```

方式二 — 使用 ai-tfs-integration Skill：
```markdown
Skill: ai-tfs-integration
指令: 为工作项 {TFS_ID} 添加标签 "AI-REVIEWED"
```

##### 4. 验证标签添加结果

```bash
# 查询工作项确认标签已添加
node .claude/skills/ai-tfs-integration/tools/tfs-query.mjs get {TFS_ID}

# 检查返回结果中的 tags 字段是否包含 "AI-REVIEWED"
```

##### 5. 更新 exec_prog.md 记录

在 `DOCS/{work_item_id}/代码审查/exec_prog.md` 中追加标签更新记录：

```markdown
### Step 5.3: 更新TFS标签

**工作项ID**: {work_item_id}
**标签添加**: AI-REVIEWED
**添加范围**: 需求项 + 开发子Task
**添加时间**: {yyyy-mm-dd HH:mm}
**添加结果**: ✅ 成功 / ❌ 失败（{失败原因}）
**附加标签**: AI-VERIFY-WARN（如审查有残留warning）
```

##### 6. 异常处理

| 异常情况 | 处理方式 |
|----------|----------|
| TFS 查询失败 | 记录 ERROR，继续流程（不阻塞） |
| 标签添加失败 | 重试3次，仍失败记录 ERROR，继续流程（不阻塞） |
| 已有 AI-REVIEWED 标签 | 记录 INFO，跳过添加，继续流程 |
| 无子任务 TFS ID | 仅给需求项添加标签，记录 WARN |

#### 添加评论
使用 `mcp__tfs-mcp__tfs_add_comment`：
```
tfs_add_comment(
  id: work_item_id,
  comment: "## 代码规范审查完成\n\n- 问题总数: {total}\n- 严重: {critical}\n- 状态: {status}"
)
```

### Step 5.4: 阻断判断与流程分支

读取 `@references/block-config.json`，按产品线获取阈值：

```python
def check_block(summary, product_line):
    config = load_block_config()
    thresholds = config["product_line_overrides"].get(product_line, config["block_thresholds"])

    if summary["critical"] > thresholds["critical"]["count"]:
        return "blocked", f"发现{summary['critical']}个严重问题需修复"

    if summary["warning"] > thresholds["warning"]["count"]:
        return "blocked", f"警告问题过多({summary['warning']}个)"

    return "passed", "审查通过"
```

**流程分支**：

| 审查结果 | 下一步动作 | 说明 |
|----------|------------|------|
| `passed` | 输出最终结果，流程结束 | Step 5.6 |
| `blocked` | 检查是否有可修复项 | Step 5.5 |

### Step 5.5: 检查可修复项（blocked 时执行）

```python
def check_fixable_issues(issues, fix_registry):
    """
    检查是否存在可自动修复的问题

    Returns:
        dict: {
            "has_fixable": bool,
            "fixable_count": int,
            "unfixable_count": int
        }
    """
    fixable_severities = ["critical", "warning"]
    target_issues = [i for i in issues if i["severity"] in fixable_severities]

    fixable_count = 0
    for issue in target_issues:
        rule_id = issue["rule_id"]
        strategy = fix_registry["rule_fix_strategies"].get(rule_id, {})
        if strategy.get("auto_fixable", False):
            fixable_count += 1

    return {
        "has_fixable": fixable_count > 0,
        "fixable_count": fixable_count,
        "unfixable_count": len(target_issues) - fixable_count
    }
```

**分支处理**：

| 可修复项 | 下一步动作 | status |
|----------|------------|--------|
| 有可修复项 | 进入 Stage 6 自动修复 | 不输出最终结果 |
| 无可修复项 | 输出最终结果 | `no_fixable` |

### Step 5.6: 更新执行进度文档

路径：`DOCS/{work_item_id}/代码审查/exec_prog.md`

**更新规则**：
- 每10分钟自动更新一次
- 记录当前阶段进度
- 更新扫描统计和问题汇总
- 记录执行日志

**更新内容**：
```python
def update_exec_progress(work_item_id, current_stage, progress_data):
    """
    更新执行进度文档

    Args:
        work_item_id: 工作项ID
        current_stage: 当前阶段
        progress_data: 进度数据
    """
    exec_prog_path = f"DOCS/{work_item_id}/代码审查/exec_prog.md"

    # 读取模板
    template = load_template("exec_prog.md")

    # 填充数据
    content = template.format(
        last_update_time=datetime.now().isoformat(),
        current_stage=current_stage,
        **progress_data
    )

    # 写入文件
    write_file(exec_prog_path, content)
```

### Step 5.6: 输出最终结果
按输出协议格式返回：
```json
{
  "task_id": "REVIEW-20260515-001",
  "work_item_id": 1500229,
  "status": "blocked",
  "summary": {...},
  "report_files": {...},
  "block_reason": "...",
  "next_action": "fix_and_retry",
  "completed_at": "2026-05-15T14:30:00Z"
}
```

## 状态映射（完整）

| 审查结果 | 可修复项 | status | next_action | 下一步 |
|----------|----------|--------|-------------|--------|
| 无阻断问题 | - | passed | proceed | 流程结束 |
| 有阻断问题 | 有 | blocked | auto_fix | 进入 Stage 6 |
| 有阻断问题 | 无 | no_fixable | manual_fix_required | 流程结束 |
| 系统错误 | - | error | manual_review | 流程结束 |

**注意**：Stage 5 只在 `passed`、`no_fixable`、`error` 时输出最终结果。`blocked` 状态会直接进入 Stage 6。
