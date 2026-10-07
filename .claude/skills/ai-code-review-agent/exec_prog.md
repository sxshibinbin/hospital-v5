# 代码规范审查执行进度

> **更新频率**: 每10分钟自动更新
> **文档版本**: v1.0.0
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

## 阶段进度

### Stage 1: 预处理
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 1.1 参数验证 | {{s1_1_status}} | {{s1_1_start}} | {{s1_1_end}} | {{s1_1_note}} |
| 1.2 TFS连接 | {{s1_2_status}} | {{s1_2_start}} | {{s1_2_end}} | {{s1_2_note}} |
| 1.3 分支获取 | {{s1_3_status}} | {{s1_3_start}} | {{s1_3_end}} | {{s1_3_note}} |
| **阶段状态** | {{stage1_status}} | - | - | - |

### Stage 2: 规则加载
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 2.1 通用规则 | {{s2_1_status}} | {{s2_1_start}} | {{s2_1_end}} | {{s2_1_note}} |
| 2.2 医疗规则 | {{s2_2_status}} | {{s2_2_start}} | {{s2_2_end}} | {{s2_2_note}} |
| 2.3 产品线规则 | {{s2_3_status}} | {{s2_3_start}} | {{s2_3_end}} | {{s2_3_note}} |
| 2.4 规则合并 | {{s2_4_status}} | {{s2_4_start}} | {{s2_4_end}} | {{s2_4_note}} |
| **阶段状态** | {{stage2_status}} | - | - | - |

### Stage 3: 代码审查
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 3.1 文件扫描 | {{s3_1_status}} | {{s3_1_start}} | {{s3_1_end}} | {{s3_1_note}} |
| 3.2 第一轮-逐行分析 | {{s3_2_status}} | {{s3_2_start}} | {{s3_2_end}} | {{s3_2_note}} |
| 3.3 第二轮-结构分析 | {{s3_3_status}} | {{s3_3_start}} | {{s3_3_end}} | {{s3_3_note}} |
| 3.4 第三轮-安全审计 | {{s3_4_status}} | {{s3_4_start}} | {{s3_4_end}} | {{s3_4_note}} |
| 3.5 第四轮-性能评估 | {{s3_5_status}} | {{s3_5_start}} | {{s3_5_end}} | {{s3_5_note}} |
| **阶段状态** | {{stage3_status}} | - | - | - |

### Stage 4: 结果聚合
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 4.1 问题去重 | {{s4_1_status}} | {{s4_1_start}} | {{s4_1_end}} | {{s4_1_note}} |
| 4.2 评分计算 | {{s4_2_status}} | {{s4_2_start}} | {{s4_2_end}} | {{s4_2_note}} |
| 4.3 统计摘要 | {{s4_3_status}} | {{s4_3_start}} | {{s4_3_end}} | {{s4_3_note}} |
| **阶段状态** | {{stage4_status}} | - | - | - |

### Stage 5: 输出交付
| 步骤 | 状态 | 开始时间 | 完成时间 | 备注 |
|------|------|----------|----------|------|
| 5.1 生成本地报告 | {{s5_1_status}} | {{s5_1_start}} | {{s5_1_end}} | {{s5_1_note}} |
| 5.2 上传TFS附件 | {{s5_2_status}} | {{s5_2_start}} | {{s5_2_end}} | {{s5_2_note}} |
| 5.3 更新TFS工作项 | {{s5_3_status}} | {{s5_3_start}} | {{s5_3_end}} | {{s5_3_note}} |
| 5.4 阻断判断 | {{s5_4_status}} | {{s5_4_start}} | {{s5_4_end}} | {{s5_4_note}} |
| **阶段状态** | {{stage5_status}} | - | - | - |

---

## 扫描统计

### 文件扫描进度
| 技术栈 | 扫描文件数 | 总文件数 | 进度 | 问题数 |
|--------|-----------|----------|------|--------|
| Java | {{java_scanned}} | {{java_total}} | {{java_progress}}% | {{java_issues}} |
| Vue | {{vue_scanned}} | {{vue_total}} | {{vue_progress}}% | {{vue_issues}} |
| TypeScript | {{ts_scanned}} | {{ts_total}} | {{ts_progress}}% | {{ts_issues}} |
| SQL | {{sql_scanned}} | {{sql_total}} | {{sql_progress}}% | {{sql_issues}} |
| **合计** | {{total_scanned}} | {{total_files}} | {{total_progress}}% | {{total_issues}} |

### 规则命中统计
| 规则层级 | 规则总数 | 已执行 | 命中数 | 命中率 |
|----------|----------|--------|--------|--------|
| Level 1 通用规则 | {{l1_total}} | {{l1_executed}} | {{l1_hits}} | {{l1_rate}}% |
| Level 2 医疗规则 | {{l2_total}} | {{l2_executed}} | {{l2_hits}} | {{l2_rate}}% |
| Level 3 产品线规则 | {{l3_total}} | {{l3_executed}} | {{l3_hits}} | {{l3_rate}}% |
| Level 4 项目规则 | {{l4_total}} | {{l4_executed}} | {{l4_hits}} | {{l4_rate}}% |

---

## 问题汇总

### 按严重级别
| 级别 | 数量 | 占比 |
|------|------|------|
| 🔴 Critical | {{critical_count}} | {{critical_rate}}% |
| 🟡 Warning | {{warning_count}} | {{warning_rate}}% |
| 🔵 Info | {{info_count}} | {{info_rate}}% |
| 💡 Suggestion | {{suggestion_count}} | {{suggestion_rate}}% |
| **总计** | {{issue_total}} | 100% |

### 按问题类型
| 类型 | Critical | Warning | Info | 合计 |
|------|----------|---------|------|------|
| 安全漏洞 | {{sec_critical}} | {{sec_warning}} | {{sec_info}} | {{sec_total}} |
| 代码质量 | {{qual_critical}} | {{qual_warning}} | {{qual_info}} | {{qual_total}} |
| 性能问题 | {{perf_critical}} | {{perf_warning}} | {{perf_info}} | {{perf_total}} |
| 规范违反 | {{std_critical}} | {{std_warning}} | {{std_info}} | {{std_total}} |
| 医疗合规 | {{med_critical}} | {{med_warning}} | {{med_info}} | {{med_total}} |

### Top 10 问题规则
| 排名 | 规则ID | 规则名称 | 命中次数 | 严重级别 |
|------|--------|----------|----------|----------|
| 1 | {{top1_id}} | {{top1_name}} | {{top1_count}} | {{top1_severity}} |
| 2 | {{top2_id}} | {{top2_name}} | {{top2_count}} | {{top2_severity}} |
| 3 | {{top3_id}} | {{top3_name}} | {{top3_count}} | {{top3_severity}} |
| 4 | {{top4_id}} | {{top4_name}} | {{top4_count}} | {{top4_severity}} |
| 5 | {{top5_id}} | {{top5_name}} | {{top5_count}} | {{top5_severity}} |
| 6 | {{top6_id}} | {{top6_name}} | {{top6_count}} | {{top6_severity}} |
| 7 | {{top7_id}} | {{top7_name}} | {{top7_count}} | {{top7_severity}} |
| 8 | {{top8_id}} | {{top8_name}} | {{top8_count}} | {{top8_severity}} |
| 9 | {{top9_id}} | {{top9_name}} | {{top9_count}} | {{top9_severity}} |
| 10 | {{top10_id}} | {{top10_name}} | {{top10_count}} | {{top10_severity}} |

---

## 质量评分

| 维度 | 当前得分 | 满分 | 状态 |
|------|----------|------|------|
| 安全性 | {{security_score}} | 100 | {{security_status}} |
| 可维护性 | {{maintainability_score}} | 100 | {{maintainability_status}} |
| 性能 | {{performance_score}} | 100 | {{performance_status}} |
| 规范性 | {{standard_score}} | 100 | {{standard_status}} |
| **综合评分** | **{{overall_score}}** | 100 | {{overall_status}} |

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
| 预计总耗时 | {{estimated_total_time}} | 基于文件数量和复杂度 |
| 预计完成时间 | {{estimated_completion}} | {{estimated_completion_note}} |
| 剩余文件数 | {{remaining_files}} | 待扫描文件数 |
| 剩余规则数 | {{remaining_rules}} | 待执行规则数 |

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

*本文档由 code-review-agent 自动生成和维护*
