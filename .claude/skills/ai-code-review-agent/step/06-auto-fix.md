# Stage 6: 自动修复

## 输入
- issues: 问题列表（仅 critical + warning）
- review_round: 当前审查轮次（从 Stage 1 传入，初始值为 1）
- source_files: 源文件内容映射
- fix_config: 修复配置（@references/fix-config.json）
- failed_fix_history: 历史修复失败记录（跨轮次累积）

## 前置条件
1. 审查结果为 `blocked`
2. review_round <= max_review_rounds（默认3）
3. 存在 `auto_fixable: true` 的问题
4. 问题严重级别 ∈ [critical, warning]

## 处理步骤

### Step 6.1: 轮次检查

```python
def check_review_round(review_round, max_review_rounds):
    """
    检查是否超过最大审查轮次

    Returns:
        tuple: (can_continue: bool, message: str)
    """
    if review_round > max_review_rounds:
        return False, f"已达到最大审查轮次({max_review_rounds})，剩余问题需人工处理"
    return True, f"当前第{review_round}轮，还可执行{max_review_rounds - review_round}轮"
```

**超过轮次处理**:
- 状态: `fix_failed`
- 标签: `AI-FIX-FAILED`
- 输出剩余问题清单
- 终止流程

### Step 6.2: 修复可行性评估

```python
def assess_fix_feasibility(issues, fix_registry, failed_fix_history):
    """
    评估问题可修复性

    注意：上一轮修复失败的问题会被标记，本轮不再重复尝试

    Returns:
        dict: {
            "fixable_issues": [...],      # 可自动修复
            "unfixable_issues": [...],    # 需人工处理（含历史失败项）
            "fix_plan": [...]             # 修复计划
        }
    """
    # 1. 过滤严重级别
    fixable_severities = ["critical", "warning"]
    target_issues = [i for i in issues if i["severity"] in fixable_severities]

    # 2. 检查规则是否支持自动修复
    fixable = []
    unfixable = []

    for issue in target_issues:
        rule_id = issue["rule_id"]
        issue_key = f"{issue['file_path']}:{issue['line_number']}:{rule_id}"

        # 检查是否在历史失败记录中
        if issue_key in failed_fix_history:
            issue["unfixable_reason"] = f"历史修复失败: {failed_fix_history[issue_key]}"
            unfixable.append(issue)
            continue

        strategy = fix_registry["rule_fix_strategies"].get(rule_id, {})

        if strategy.get("auto_fixable", False):
            issue["fix_strategy"] = strategy
            issue["risk_level"] = strategy.get("risk_level", "medium")
            fixable.append(issue)
        else:
            issue["unfixable_reason"] = strategy.get("reason", "不支持自动修复")
            unfixable.append(issue)

    # 3. 按风险级别和优先级排序（低风险优先）
    fixable.sort(key=lambda x: (
        {"critical": 0, "warning": 1}.get(x["severity"], 2),
        {"low": 0, "medium": 1, "high": 2}.get(x.get("risk_level", "medium"), 1)
    ))

    return {
        "fixable_issues": fixable,
        "unfixable_issues": unfixable,
        "fix_plan": generate_fix_plan(fixable)
    }
```

**无可修复项处理**:
- 状态: `no_fixable`
- 标签: `AI-MANUAL-REQUIRED`
- 输出需人工处理的问题清单
- 终止流程

### Step 6.3: 生成修复计划

```python
def generate_fix_plan(fixable_issues):
    """
    生成修复计划，按文件分组

    Returns:
        list: [
            {
                "file_path": "...",
                "issues": [...],
                "engine": "java",
                "estimated_changes": 3
            }
        ]
    """
    from collections import defaultdict

    plan_by_file = defaultdict(lambda: {"issues": [], "engine": None})

    for issue in fixable_issues:
        file_path = issue["file_path"]
        plan_by_file[file_path]["issues"].append(issue)
        plan_by_file[file_path]["engine"] = get_engine_by_tech_stack(issue["tech_stack"])

    return [
        {
            "file_path": fp,
            "issues": data["issues"],
            "engine": data["engine"],
            "estimated_changes": len(data["issues"])
        }
        for fp, data in plan_by_file.items()
    ]
```

### Step 6.4: 执行修复

```python
def execute_fixes(fix_plan, source_files, fix_engines, fix_mode):
    """
    执行自动修复

    Args:
        fix_mode: 修复模式（interactive/semi_auto/full_auto）
                  来自 fix_config.fix_modes

    Returns:
        dict: {
            "fixed_issues": [...],
            "failed_fixes": [...],
            "modified_files": [...]
        }
    """
    fixed_issues = []
    failed_fixes = []
    modified_files = set()

    for file_plan in fix_plan:
        file_path = file_plan["file_path"]
        engine_name = file_plan["engine"]

        # 获取修复引擎
        engine = fix_engines.get(engine_name)
        if not engine:
            for issue in file_plan["issues"]:
                failed_fixes.append({
                    "issue": issue,
                    "reason": f"未找到修复引擎: {engine_name}"
                })
            continue

        # 备份原文件
        backup_file(file_path)

        # 执行修复
        try:
            original_content = source_files[file_path]
            fixed_content = original_content

            for issue in file_plan["issues"]:
                # 根据风险策略决定是否需要确认
                if need_confirmation(issue, fix_mode):
                    if not user_confirm(issue):
                        failed_fixes.append({
                            "issue": issue,
                            "reason": "用户取消修复"
                        })
                        continue

                fix_result = engine.apply_fix(
                    content=fixed_content,
                    issue=issue
                )

                if fix_result["success"]:
                    fixed_content = fix_result["content"]
                    fixed_issues.append({
                        "issue": issue,
                        "fix_applied": fix_result["fix_applied"]
                    })
                else:
                    failed_fixes.append({
                        "issue": issue,
                        "reason": fix_result["reason"]
                    })

            # 写入修复后的文件
            if fixed_content != original_content:
                write_file(file_path, fixed_content)
                modified_files.add(file_path)

        except Exception as e:
            for issue in file_plan["issues"]:
                failed_fixes.append({
                    "issue": issue,
                    "reason": f"修复异常: {str(e)}"
                })

    return {
        "fixed_issues": fixed_issues,
        "failed_fixes": failed_fixes,
        "modified_files": list(modified_files)
    }

def need_confirmation(issue, fix_mode):
    """
    根据修复模式决定是否需要用户确认
    """
    if fix_mode == "full_auto":
        return False
    if fix_mode == "interactive":
        return True
    # semi_auto: 根据风险级别决定
    return issue.get("risk_level", "medium") != "low"
```

### Step 6.5: 修复验证

```python
def verify_fixes(fixed_issues, modified_files):
    """
    验证修复结果

    验证项:
    1. 语法检查：编译通过
    2. 规则匹配：问题已解决
    3. 不引入新问题

    Returns:
        dict: {
            "verified": bool,
            "syntax_ok": bool,
            "issues_resolved": int,
            "new_issues": [...]
        }
    """
    results = {
        "verified": True,
        "syntax_ok": True,
        "issues_resolved": len(fixed_issues),
        "new_issues": []
    }

    for file_path in modified_files:
        # 1. 语法检查
        if not check_syntax(file_path):
            results["syntax_ok"] = False
            results["verified"] = False
            # 回滚文件
            rollback_file(file_path)

    return results
```

### Step 6.6: 更新失败历史

```python
def update_failed_fix_history(failed_fixes, failed_fix_history):
    """
    将本轮修复失败的问题记录到历史

    下一轮不再尝试修复这些问题
    """
    for fix in failed_fixes:
        issue = fix["issue"]
        issue_key = f"{issue['file_path']}:{issue['line_number']}:{issue['rule_id']}"
        failed_fix_history[issue_key] = fix["reason"]

    return failed_fix_history
```

### Step 6.7: 决定下一步

```python
def decide_next_step(review_round, fix_result, verify_result, remaining_issues):
    """
    决定下一步动作
    """
    # 更新轮次
    next_round = review_round + 1

    # 统计剩余问题
    critical_remaining = sum(1 for i in remaining_issues if i["severity"] == "critical")
    warning_remaining = sum(1 for i in remaining_issues if i["severity"] == "warning")

    if verify_result["verified"] and fix_result["fixed_issues"]:
        # 修复成功，检查是否还有阻断问题
        if critical_remaining == 0 and warning_remaining == 0:
            return {
                "next_stage": "Stage 3",  # 回归验证确保无新问题
                "review_round": next_round,
                "status": "fixing",
                "message": f"成功修复{len(fix_result['fixed_issues'])}个问题，触发第{next_round}轮验证"
            }
        else:
            return {
                "next_stage": "Stage 3",
                "review_round": next_round,
                "status": "fixing",
                "message": f"修复{len(fix_result['fixed_issues'])}个问题，剩余{critical_remaining + warning_remaining}个待处理"
            }
    else:
        # 修复验证失败
        return {
            "next_stage": "terminate",
            "review_round": next_round,
            "status": "fix_failed",
            "message": "修复验证失败，终止流程"
        }
```

## 修复引擎调用

根据技术栈调用对应修复引擎：

| 技术栈 | 引擎文件 | 支持规则数 |
|--------|----------|-----------|
| java | @fix-engines/java-fix-engine.md | 4 |
| vue | @fix-engines/vue-fix-engine.md | 2 |
| sql | @fix-engines/sql-fix-engine.md | 1 |

## 输出

```json
{
  "stage": "Stage 6: 自动修复",
  "review_round": 2,
  "fix_summary": {
    "total_fixable": 10,
    "fixed": 8,
    "failed": 1,
    "manual_required": 1,
    "cumulative_fixed": 15
  },
  "fixed_issues": [
    {
      "issue_id": "ISSUE-001",
      "rule_id": "COMMON-SEC-002",
      "fix_applied": "移除敏感日志参数",
      "file_path": "src/.../UserService.java",
      "line_number": 45
    }
  ],
  "failed_fixes": [
    {
      "issue_id": "ISSUE-005",
      "rule_id": "COMMON-SEC-001",
      "reason": "规则不支持自动修复"
    }
  ],
  "modified_files": [
    "src/.../UserService.java",
    "src/.../OrderService.java"
  ],
  "verify_result": {
    "verified": true,
    "syntax_ok": true,
    "issues_resolved": 8
  },
  "next_stage": "Stage 3",
  "next_action": "re_review"
}
```

## 状态流转（完整）

```
Stage 5 阻断判断
     │
     ↓
┌─────────────────┐
│ status=blocked? │
└────────┬────────┘
         │
   ┌─────┴─────┐
   ↓           ↓
[passed]   [blocked]
   │           │
   ↓           ↓
 结束    ┌──────────────────┐
         │ Stage 6: 自动修复 │
         └────────┬─────────┘
                  │
           ┌──────┴──────┐
           ↓             ↓
      [超限]        [未超限]
           │             │
           ↓             ↓
   status=fix_failed   ┌──────────────┐
   标签=AI-FIX-FAILED  │ 可修复性评估  │
                       └──────┬───────┘
                              │
                       ┌──────┴──────┐
                       ↓             ↓
                 [无可修复项]    [有可修复项]
                       │             │
                       ↓             ↓
                status=no_fixable  ┌──────────────┐
                标签=AI-MANUAL-    │ 执行修复      │
                REQUIRED           └──────┬───────┘
                                         │
                                  ┌──────┴──────┐
                                  ↓             ↓
                              [验证通过]    [验证失败]
                                  │             │
                                  ↓             ↓
                            回归Stage 3   回滚+记录失败
                            review_round++    │
                                              ↓
                                        更新 failed_fix_history
                                              │
                                              ↓
                                        检查下一轮是否可继续
```

## 跨轮次数据传递

| 数据 | 传递方式 | 说明 |
|------|----------|------|
| review_round | Stage 1 初始化，每轮 +1 | 当前审查轮次 |
| failed_fix_history | Stage 6 维护，传递到下一轮 | 记录历史修复失败的问题 |
| fix_summary.cumulative_fixed | 累加所有轮次 | 累计修复数量 |

## 异常处理

| 异常类型 | 处理方式 |
|----------|----------|
| 文件读取失败 | 跳过该文件，记录到 failed_fix_history |
| 修复引擎异常 | 标记失败，记录原因到 failed_fix_history |
| 语法验证失败 | 回滚文件，标记失败 |
| 写入失败 | 回滚，终止当前轮次 |
| 用户取消修复 | 记录到 failed_fix_history，继续其他修复 |
