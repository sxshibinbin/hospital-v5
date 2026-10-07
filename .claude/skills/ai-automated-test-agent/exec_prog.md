# 自动化测试执行进度

> **更新频率**: 每10分钟自动更新
> **文档版本**: v1.1.0
> **最后更新**: {{last_update_time}}

---

## 当前状态

| 项目 | 内容 |
|------|------|
| **任务ID** | {{task_id}} |
| **工作项ID** | {{work_item_id}} |
| **当前阶段** | {{current_stage}} |
| **执行状态** | {{status}} |
| **开始时间** | {{start_time}} |
| **已耗时** | {{elapsed_time}} |

---

## 前置Agent关联状态

### PRD解析Agent
| 项目 | 状态 | 路径 | 备注 |
|------|------|------|------|
| 产出物存在 | {{prd_exists}} | {{prd_path}} | {{prd_note}} |
| 需求功能点 | {{prd_features}} 个 | - | {{prd_features_note}} |
| 验收标准 | {{prd_criteria}} 个 | - | {{prd_criteria_note}} |

### 架构设计Agent
| 项目 | 状态 | 路径 | 备注 |
|------|------|------|------|
| 产出物存在 | {{arch_exists}} | {{arch_path}} | {{arch_note}} |
| 模块数量 | {{arch_modules}} 个 | - | {{arch_modules_note}} |
| 接口定义 | {{arch_interfaces}} 个 | - | {{arch_interfaces_note}} |

### 代码审查Agent
| 项目 | 状态 | 路径 | 备注 |
|------|------|------|------|
| 产出物存在 | {{review_exists}} | {{review_path}} | {{review_note}} |
| 问题总数 | {{review_issues}} 个 | - | {{review_issues_note}} |
| Critical问题 | {{review_critical}} 个 | - | {{review_critical_note}} |

---

## 阶段进度

### Stage1: 前置产出物收集
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 1.1 读取PRD解析结果 | {{s1_1_status}} | {{s1_1_start}} | {{s1_1_end}} | {{s1_1_note}} |
| 1.2 读取架构设计结果 | {{s1_2_status}} | {{s1_2_start}} | {{s1_2_end}} | {{s1_2_note}} |
| 1.3 读取代码审查结果 | {{s1_3_status}} | {{s1_3_start}} | {{s1_3_end}} | {{s1_3_note}} |
| 1.4 汇总测试要点 | {{s1_4_status}} | {{s1_4_start}} | {{s1_4_end}} | {{s1_4_note}} |
| **阶段状态** | {{stage1_status}} | - | - | - |

### Stage2: 测试用例设计
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 2.1 正常场景用例 | {{s2_1_status}} | {{s2_1_start}} | {{s2_1_end}} | {{s2_1_note}} |
| 2.2 接口测试用例 | {{s2_2_status}} | {{s2_2_start}} | {{s2_2_end}} | {{s2_2_note}} |
| 2.3 异常场景用例 | {{s2_3_status}} | {{s2_3_start}} | {{s2_3_end}} | {{s2_3_note}} |
| 2.4 边界值用例 | {{s2_4_status}} | {{s2_4_start}} | {{s2_4_end}} | {{s2_4_note}} |
| 2.5 医疗合规用例 | {{s2_5_status}} | {{s2_5_start}} | {{s2_5_end}} | {{s2_5_note}} |
| **阶段状态** | {{stage2_status}} | - | - | - |

### Stage3: 测试代码生成
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 3.1 选择测试框架 | {{s3_1_status}} | {{s3_1_start}} | {{s3_1_end}} | {{s3_1_note}} |
| 3.2 生成测试代码 | {{s3_2_status}} | {{s3_2_start}} | {{s3_2_end}} | {{s3_2_note}} |
| 3.3 代码审查适配 | {{s3_3_status}} | {{s3_3_start}} | {{s3_3_end}} | {{s3_3_note}} |
| **阶段状态** | {{stage3_status}} | - | - | - |

### Stage4: 测试执行
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 4.1 执行单元测试 | {{s4_1_status}} | {{s4_1_start}} | {{s4_1_end}} | {{s4_1_note}} |
| 4.2 执行接口测试 | {{s4_2_status}} | {{s4_2_start}} | {{s4_2_end}} | {{s4_2_note}} |
| 4.3 执行集成测试 | {{s4_3_status}} | {{s4_3_start}} | {{s4_3_end}} | {{s4_3_note}} |
| 4.4 重试失败用例 | {{s4_4_status}} | {{s4_4_start}} | {{s4_4_end}} | {{s4_4_note}} |
| **阶段状态** | {{stage4_status}} | - | - | - |

### Stage5: 报告生成与交付
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 5.1 解析测试结果 | {{s5_1_status}} | {{s5_1_start}} | {{s5_1_end}} | {{s5_1_note}} |
| 5.2 生成报告文件 | {{s5_2_status}} | {{s5_2_start}} | {{s5_2_end}} | {{s5_2_note}} |
| 5.3 上传TFS附件 | {{s5_3_status}} | {{s5_3_start}} | {{s5_3_end}} | {{s5_3_note}} |
| 5.4 回写工作项 | {{s5_4_status}} | {{s5_4_start}} | {{s5_4_end}} | {{s5_4_note}} |
| **阶段状态** | {{stage5_status}} | - | - | - |

---

## 测试用例统计

### 按类型
| 类型 | 已生成 | 总数 | 进度 | 通过 |
|------|--------|------|------|------|
| 正常场景 | {{normal_generated}} | {{normal_total}} | {{normal_progress}}% | {{normal_passed}} |
| 接口测试 | {{api_generated}} | {{api_total}} | {{api_progress}}% | {{api_passed}} |
| 异常场景 | {{exception_generated}} | {{exception_total}} | {{exception_progress}}% | {{exception_passed}} |
| 边界值 | {{boundary_generated}} | {{boundary_total}} | {{boundary_progress}}% | {{boundary_passed}} |
| 医疗合规 | {{medical_generated}} | {{medical_total}} | {{medical_progress}}% | {{medical_passed}} |
| **合计** | **{{total_generated}}** | **{{total_cases}}** | **{{total_progress}}%** | **{{total_passed}}** |

### 按优先级
| 优先级 | 数量 | 通过 | 失败 | 通过率 |
|--------|------|------|------|--------|
| P0 致命 | {{p0_total}} | {{p0_passed}} | {{p0_failed}} | {{p0_rate}}% |
| P1 严重 | {{p1_total}} | {{p1_passed}} | {{p1_failed}} | {{p1_rate}}% |
| P2 一般 | {{p2_total}} | {{p2_passed}} | {{p2_failed}} | {{p2_rate}}% |
| P3 轻微 | {{p3_total}} | {{p3_passed}} | {{p3_failed}} | {{p3_rate}}% |

---

## Bug汇总

### 按严重级别
| 级别 | 数量 | 占比 | 状态 |
|------|------|------|------|
| 🔴 P0 Critical | {{p0_count}} | {{p0_rate}}% | {{p0_status}} |
| 🟠 P1 High | {{p1_count}} | {{p1_rate}}% | {{p1_status}} |
| 🟡 P2 Medium | {{p2_count}} | {{p2_rate}}% | {{p2_status}} |
| 🟢 P3 Low | {{p3_count}} | {{p3_rate}}% | {{p3_status}} |
| **总计** | **{{bug_total}}** | **100%** | - |

### 按关联来源
| 来源 | Bug数量 | 验证状态 |
|------|---------|----------|
| 需求功能点 | {{bug_from_prd}} | {{bug_prd_status}} |
| 架构设计约束 | {{bug_from_arch}} | {{bug_arch_status}} |
| 代码审查问题 | {{bug_from_review}} | {{bug_review_status}} |
| 新发现 | {{bug_new}} | {{bug_new_status}} |

### Top 10 Bug
| 排名 | Bug ID | 关联功能点 | 严重级别 | 状态 |
|------|--------|-----------|----------|------|
| 1 | {{bug1_id}} | {{bug1_feature}} | {{bug1_severity}} | {{bug1_status}} |
| 2 | {{bug2_id}} | {{bug2_feature}} | {{bug2_severity}} | {{bug2_status}} |
| 3 | {{bug3_id}} | {{bug3_feature}} | {{bug3_severity}} | {{bug3_status}} |
| 4 | {{bug4_id}} | {{bug4_feature}} | {{bug4_severity}} | {{bug4_status}} |
| 5 | {{bug5_id}} | {{bug5_feature}} | {{bug5_severity}} | {{bug5_status}} |
| 6 | {{bug6_id}} | {{bug6_feature}} | {{bug6_severity}} | {{bug6_status}} |
| 7 | {{bug7_id}} | {{bug7_feature}} | {{bug7_severity}} | {{bug7_status}} |
| 8 | {{bug8_id}} | {{bug8_feature}} | {{bug8_severity}} | {{bug8_status}} |
| 9 | {{bug9_id}} | {{bug9_feature}} | {{bug9_severity}} | {{bug9_status}} |
| 10 | {{bug10_id}} | {{bug10_feature}} | {{bug10_severity}} | {{bug10_status}} |

---

## 测试执行进度

| 技术栈 | 已执行 | 总数 | 进度 | 通过率 | Bug数 |
|--------|--------|------|------|--------|-------|
| Java | {{java_executed}} | {{java_total}} | {{java_progress}}% | {{java_pass_rate}}% | {{java_bugs}} |
| C# | {{csharp_executed}} | {{csharp_total}} | {{csharp_progress}}% | {{csharp_pass_rate}}% | {{csharp_bugs}} |
| Vue/前端 | {{vue_executed}} | {{vue_total}} | {{vue_progress}}% | {{vue_pass_rate}}% | {{vue_bugs}} |
| **合计** | **{{total_executed}}** | **{{total_cases}}** | **{{total_progress}}%** | **{{total_pass_rate}}%** | **{{total_bugs}}** |

---

## 执行日志

### 最近10条日志
```
[{{log1_time}}] [{{log1_level}}] {{log1_message}}
[{{log2_time}}] [{{log2_level}}] {{log2_message}}
[{{log3_time}}] [{{log3_level}}] {{log3_message}}
[{{log4_time}}] [{{log4_level}}] {{log4_message}}
[{{log5_time}}] [{{log5_level}}] {{log5_message}}
[{{log6_time}}] [{{log6_level}}] {{log6_message}}
[{{log7_time}}] [{{log7_level}}] {{log7_message}}
[{{log8_time}}] [{{log8_level}}] {{log8_message}}
[{{log9_time}}] [{{log9_level}}] {{log9_message}}
[{{log10_time}}] [{{log10_level}}] {{log10_message}}
```

---

## 预估信息

| 项目 | 预估值 | 说明 |
|------|--------|------|
| 预计总耗时 | {{estimated_total_time}} | 基于用例数量和技术栈 |
| 预计完成时间 | {{estimated_completion}} | {{estimated_completion_note}} |
| 剩余用例数 | {{remaining_cases}} | 待生成/执行 |
| 剩余测试执行 | {{remaining_execution}} | 待执行 |

---

## 更新历史

| 更新时间 | 阶段 | 进度变化 | 备注 |
|----------|------|----------|------|
| {{update1_time}} | {{update1_stage}} | {{update1_progress}} | {{update1_note}} |
| {{update2_time}} | {{update2_stage}} | {{update2_progress}} | {{update2_note}} |
| {{update3_time}} | {{update3_stage}} | {{update3_progress}} | {{update3_note}} |

---

## 状态说明

| 状态 | 说明 |
|------|------|
| ⏳ Pending | 等待执行 |
| 🔄 Running | 执行中 |
| ✅ Completed | 已完成 |
| ⚠️ Warning | 完成但有警告 |
| ❌ Failed | 执行失败 |
| ⏭️ Skipped | 已跳过 |

---

*本文档由 ai-automated-test-agent 自动生成和维护*
*关联需求号: {{work_item_id}}*
