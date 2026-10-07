# 代码规范审查报告

## 基本信息
| 项目 | 内容 |
|------|------|
| 工作项ID | {{work_item_id}} |
| 产品线 | {{product_line}} |
| 项目名称 | {{project_name}} |
| 审查时间 | {{timestamp}} |
| 扫描模式 | {{scan_mode}} |
| 扫描类型 | {{scan_type}} |

## 审查摘要
| 指标 | 数量 |
|------|------|
| 问题总数 | {{summary.total_issues}} |
| 🔴 严重 (Critical) | {{summary.critical}} |
| 🟡 警告 (Warning) | {{summary.warning}} |
| 🔵 提示 (Info) | {{summary.info}} |
| 💡 建议 (Suggestion) | {{summary.suggestion}} |

## 阻断状态
| 项目 | 内容 |
|------|------|
| **状态** | {{status_text}} |
| **阻断原因** | {{block_reason}} |
| **下一步动作** | {{next_action_text}} |

## 问题详情

{{#each issues_by_severity}}
### {{severity_text}} 问题 ({{count}}个)

{{#each issues}}
#### {{rule_id}}: {{rule_name}}
| 属性 | 值 |
|------|------|
| **文件路径** | `{{file_path}}` |
| **行号** | {{line_number}} |
| **规则分类** | {{category}} |
| **技术栈** | {{tech_stack}} |

**问题描述**:
{{description}}

**修复建议**:
{{fix_guidance.description}}

{{#if fix_guidance.code_example}}
**代码示例**:
```
{{fix_guidance.code_example}}
```
{{/if}}

---
{{/each}}
{{/each}}

## 规则执行统计

| 规则层级 | 规则数量 | 命中数量 |
|----------|----------|----------|
| Level 1: 通用规则 | {{rule_stats.common.total}} | {{rule_stats.common.hits}} |
| Level 2: 医疗规则 | {{rule_stats.medical.total}} | {{rule_stats.medical.hits}} |
| Level 3: 产品线规则 | {{rule_stats.product.total}} | {{rule_stats.product.hits}} |
| Level 4: 项目规则 | {{rule_stats.project.total}} | {{rule_stats.project.hits}} |

## 代码质量评分

| 维度 | 得分 | 说明 |
|------|------|------|
| 安全性 | {{score.security}}/100 | {{score.security_desc}} |
| 可维护性 | {{score.maintainability}}/100 | {{score.maintainability_desc}} |
| 性能 | {{score.performance}}/100 | {{score.performance_desc}} |
| 规范性 | {{score.standard}}/100 | {{score.standard_desc}} |
| **综合评分** | **{{score.overall}}/100** | - |

## 技术栈分析

{{#each tech_stack_analysis}}
### {{tech_stack}}

| 指标 | 值 |
|------|------|
| 扫描文件数 | {{files_scanned}} |
| 问题数 | {{issues_found}} |
| 问题密度 | {{issue_density}} |

{{/each}}

## 改进建议

{{#each recommendations}}
{{priority}}. **{{title}}**: {{description}}
{{/each}}

---

## 附录

### 扫描配置
```json
{{scan_config}}
```

### 报告信息
- 报告生成时间: {{generated_at}}
- 报告版本: {{report_version}}
- Agent版本: {{agent_version}}
