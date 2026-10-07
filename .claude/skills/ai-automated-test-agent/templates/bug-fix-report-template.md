# Bug修复报告

- **需求号**: {work_item_id}
- **产品线**: {product_line}
- **技术栈**: {tech_stack_tags}
- **修复时间**: {fix_start_time} ~ {fix_end_time}
- **修复轮次**: {retry_round}/{max_rounds}

---

## 修复汇总

| 指标 | 数值 |
|------|------|
| 待修复Bug数 | {bugs_total} |
| 修复成功 | {bugs_fixed} |
| 修复失败（需人工介入） | {bugs_failed} |
| P0修复 | {p0_fixed}/{p0_total} |
| P1修复 | {p1_fixed}/{p1_total} |
| 修复前通过率 | {pass_rate_before}% |
| 修复后通过率 | {pass_rate_after}% |

### Bug修复清单

| BugID | 级别 | 类型 | 关联文件 | 修复策略 | 结果 | 需人工复核 |
|-------|------|------|----------|---------|------|-----------|
| BUG-001 | P0 | SQL_INJECTION | PatientMapper.xml | 参数化查询替换${} | ✅ 已修复 | 否 |
| BUG-002 | P1 | NULL_POINTER | PatientService.java:45 | 防御性判空 | ✅ 已修复 | 否 |
| BUG-003 | P1 | MEDICAL_DATA_INTEGRITY | TransferService.java:23 | 添加@Transactional | ✅ 已修复 | ⚠️ 是 |
| BUG-004 | P0 | MEDICAL_DOSAGE_CALC | PrescriptionService.java:67 | 添加剂量范围校验 | ❌ 需人工介入 | ⚠️ 是 |

---

## 修复详情

### Bug #{bug_id}: {bug_title}

**基本信息**：
- **级别**: {severity}
- **类型**: {rule_id}
- **测试类**: {test_class}#{test_method}
- **错误信息**: `{error_message}`

**根因分析**：
{root_cause_analysis}

**定位文件**：`{file_path}:{line_number}`

**修复策略**：{strategy_name}（来自 fix-strategies.md #{rule_id}）

**修复Diff**：
```diff
--- a/{file_path}
+++ b/{file_path}
@@ -{line},3 +{line},5 @@
- {old_code}
+ {new_code}
```

**编译验证**：✅ 通过
**重测结果**：✅ 通过
**需人工复核**：{require_human_review}

---

### Bug #{bug_id}: {bug_title}

（同上格式，重复每个 Bug 的修复详情）

---

## 未修复Bug（需人工介入）

| BugID | 级别 | 类型 | 失败原因 | 尝试策略数 | 建议 |
|-------|------|------|---------|-----------|------|
| BUG-004 | P0 | MEDICAL_DOSAGE_CALC | 修复后编译失败，涉及复杂业务逻辑 | 3/3 | 建议由业务开发人员人工修复 |

---

## 重测结果

### 修复前
| 指标 | 数值 |
|------|------|
| 总用例数 | {total_cases} |
| 通过 | {passed_before} |
| 失败 | {failed_before} |
| 通过率 | {pass_rate_before}% |

### 修复后
| 指标 | 数值 |
|------|------|
| 总用例数 | {total_cases} |
| 通过 | {passed_after} |
| 失败 | {failed_after} |
| 通过率 | {pass_rate_after}% |

### 通过率变化
- 修复前: {pass_rate_before}%
- 修复后: {pass_rate_after}%
- 提升: +{improvement}%

---

## 医疗合规修复备注

（如有涉及医疗合规的修复，在此列出需人工复核的项目）

| BugID | 修复内容 | 复核要点 |
|-------|---------|---------|
| BUG-003 | 添加事务注解保证数据一致性 | 确认事务隔离级别和传播行为是否正确 |
| BUG-004 | 剂量范围校验（修复失败） | 需确认剂量上下限的业务规则 |
