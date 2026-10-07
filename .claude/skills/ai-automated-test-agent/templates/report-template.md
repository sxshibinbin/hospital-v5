# 自动化测试报告

- **需求号（TFS工作项）**: {{work_item_id}}
- **产品线**: {{product_line}}
- **项目**: {{project_name}}
- **技术栈**: {{tech_stack_tags}}
- **测试范围**: {{test_scope}}
- **测试时间**: {{start_time}} ~ {{end_time}}
- **测试Agent任务ID**: {{task_id}}

---

## 1. 测试概要

| 指标 | 数值 |
|------|------|
| 总用例数 | {{total_cases}} |
| 通过 ✅ | {{passed}} |
| 失败 ❌ | {{failed}} |
| 跳过 ⏭️ | {{skipped}} |
| **通过率** | **{{pass_rate}}%** |
| 总耗时 | {{total_duration}} |

---

## 2. Bug汇总

### 按严重级别
| 级别 | 数量 | 说明 |
|------|------|------|
| 🔴 P0 致命 | {{p0_count}} | 核心业务流程不可用，必须修复 |
| 🟠 P1 严重 | {{p1_count}} | 功能异常或数据错误，建议修复 |
| 🟡 P2 一般 | {{p2_count}} | 功能可用但不符合预期 |
| 🟢 P3 轻微 | {{p3_count}} | 界面、文档、建议优化项 |
| **总计** | **{{bug_total}}** | - |

### 详细Bug清单
| ID | 严重级别 | 关联功能点 | 用例ID | 错误信息 | 关联审查问题 |
|----|----------|-----------|--------|---------|------------|
{{bug_list}}

---

## 3. 前置Agent关联

| Agent | 状态 | 产出物路径 | 用例数 |
|-------|------|-----------|--------|
| **PRD解析Agent** | {{prd_agent_status}} | {{prd_path}} | {{from_prd_count}} |
| **架构设计Agent** | {{arch_agent_status}} | {{arch_path}} | {{from_arch_count}} |
| **代码审查Agent** | {{review_agent_status}} | {{review_path}} | {{from_review_count}} |
| **医疗规则库** | 内置 | `references/medical-test-cases.md` | {{from_medical_count}} |

---

## 4. 用例-需求追溯表

| 用例ID | 类型 | 来源 | 关联功能点 | 关联接口 | 关联审查问题 | 执行结果 |
|--------|------|------|-----------|---------|------------|---------|
{{case_traceability}}

---

## 5. 失败用例详情

{{failure_details}}

---

## 6. 医疗合规检查

| 检查项 | 验证结果 | 通过用例 | 失败用例 | 状态 |
|--------|---------|---------|---------|------|
| 患者信息加密存储 | {{med_encryption_result}} | {{med_encryption_pass}} | {{med_encryption_fail}} | {{med_encryption_status}} |
| 处方剂量范围校验 | {{med_dosage_result}} | {{med_dosage_pass}} | {{med_dosage_fail}} | {{med_dosage_status}} |
| 药物相互作用检测 | {{med_interaction_result}} | {{med_interaction_pass}} | {{med_interaction_fail}} | {{med_interaction_status}} |
| 护理记录完整性 | {{med_nursing_result}} | {{med_nursing_pass}} | {{med_nursing_fail}} | {{med_nursing_status}} |
| 角色权限隔离 | {{med_permission_result}} | {{med_permission_pass}} | {{med_permission_fail}} | {{med_permission_status}} |
| 数据脱敏 | {{med_desensitize_result}} | {{med_desensitize_pass}} | {{med_desensitize_fail}} | {{med_desensitize_status}} |
| 事务回滚一致性 | {{med_transaction_result}} | {{med_transaction_pass}} | {{med_transaction_fail}} | {{med_transaction_status}} |

---

## 7. 代码审查问题验证

| 审查问题ID | 严重级别 | 问题描述 | 测试验证结果 | 关联用例 |
|-----------|---------|----------|------------|---------|
{{review_issue_verification}}

---

## 8. 改进建议

### 代码层面
{{code_suggestions}}

### 测试层面
{{test_suggestions}}

### 架构层面
{{arch_suggestions}}

---

## 9. 测试文件清单

| 文件路径 | 类型 | 用例数 |
|---------|------|--------|
{{test_files}}

---

## 10. 附录

### 执行统计
- 测试代码行数: {{test_code_lines}}
- 平均用例执行时间: {{avg_case_duration}}
- Flaky Tests (重试后通过): {{flaky_tests}}

---

*报告由 automated-test-agent 自动生成*
*关联需求号: {{work_item_id}}*
*生成时间: {{generated_at}}*
