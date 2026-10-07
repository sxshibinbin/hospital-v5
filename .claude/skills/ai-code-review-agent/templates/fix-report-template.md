# 修复报告模板

## 基本信息

| 项目 | 内容 |
|------|------|
| 工作项ID | {work_item_id} |
| 审查轮次 | {review_round} / {max_rounds} |
| 修复时间 | {timestamp} |

## 修复摘要

| 指标 | 数量 |
|------|------|
| 可修复问题 | {total_fixable} |
| 已修复 | {fixed} |
| 修复失败 | {failed} |
| 需人工处理 | {manual_required} |

## 修复详情

### 成功修复的问题

{#each fixed_issues as issue}
#### {issue.rule_id}: {issue.rule_name}

- **文件**: `{issue.file_path}:{issue.line_number}`
- **修复策略**: {issue.fix_strategy}
- **修复内容**: {issue.fix_applied}

```{issue.language}
// 修复前
{issue.before_code}

// 修复后
{issue.after_code}
```
{/each}

### 修复失败的问题

{#each failed_fixes as fix}
#### {fix.issue.rule_id}: {fix.issue.rule_name}

- **文件**: `{fix.issue.file_path}:{fix.issue.line_number}`
- **失败原因**: {fix.reason}
- **建议**: 需人工检查并修复
{/each}

### 需人工处理的问题

{#each unfixable_issues as issue}
#### {issue.rule_id}: {issue.rule_name}

- **文件**: `{issue.file_path}:{issue.line_number}`
- **严重级别**: {issue.severity}
- **无法自动修复原因**: {issue.unfixable_reason}
- **建议修复方案**: {issue.fix_guidance}
{/each}

## 验证结果

| 检查项 | 结果 |
|--------|------|
| 语法检查 | {syntax_ok} |
| 问题解决 | {issues_resolved} 个 |
| 新增问题 | {new_issues} 个 |

## 修改的文件

{#each modified_files as file}
- `{file}`
{/each}

## 下一步

{#if next_action == "re_review"}
已成功修复 {fixed} 个问题，将进行第 {next_round} 轮审查。
{elseif next_action == "manual_fix_required"}
已达到最大审查轮次（{max_rounds}轮），剩余问题需人工处理。
{elseif next_action == "terminate"}
修复验证失败，已回滚修改。
{/if}

---

*报告生成时间: {generated_at}*
