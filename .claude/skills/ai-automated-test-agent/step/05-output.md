# Stage 5: 报告生成与交付

## 目标
汇总所有测试结果，生成结构化测试报告，上传TFS并更新工作项状态。

## 执行步骤

### 5.1 解析测试结果

使用 `scripts/generate_test_report.py` 解析原始测试结果：

```bash
python3 {skill_dir}/scripts/generate_test_report.py \
  --input-dir {project_root}/target/surefire-reports/ \
  --output-dir DOCS/{work_item_id}/自动化测试/ \
  --work-item {work_item_id} \
  --prd-file DOCS/{work_item_id}/PRD解析/*报告*.md \
  --arch-file DOCS/{work_item_id}/架构设计/*架构*.md \
  --review-file DOCS/{work_item_id}/代码审查/*报告*.md
```

脚本功能：
- 解析 JUnit XML / TRX 结果
- 按 P0/P1/P2/P3 分级标注 Bug
- 关联需求功能点、架构接口、审查问题
- 生成 Markdown 报告 + JSON 数据文件
- 生成 HTML 报告（含图表）

### 5.2 生成报告文件

报告输出目录：`DOCS/{work_item_id}/自动化测试/`

| 文件 | 格式 | 内容 |
|------|------|------|
| `测试报告_{work_item_id}_{date}.md` | Markdown | 完整结构化报告 |
| `测试报告_{work_item_id}_{date}.html` | HTML | 带图表的可读报告 |
| `test_results_{work_item_id}.json` | JSON | 结构化数据 |
| `用例清单_{work_item_id}.csv` | CSV | 每条用例及其结果 |
| `bug清单_{work_item_id}.csv` | CSV | Bug列表 |

### 5.3 上传TFS附件

通过 TFS MCP 工具上传报告文件到工作项附件：

```json
{
  "work_item_id": {work_item_id},
  "attachments": [
    "DOCS/{work_item_id}/自动化测试/测试报告_{work_item_id}_{date}.md",
    "DOCS/{work_item_id}/自动化测试/bug清单_{work_item_id}.csv"
  ],
  "comment": "自动化测试完成，共执行 {total_cases} 条用例，通过率 {pass_rate}%"
}
```

### 5.4 回写工作项

更新 TFS 工作项状态：

```json
{
  "work_item_id": {work_item_id},
  "fields": {
    "测试结果": "{pass_rate}% 通过率，{bug_count} 个Bug",
    "阶段状态": "测试完成"
  }
}
```

如果存在 P0 级 Bug，设置阻断标记：
```json
{
  "block_next_stage": true,
  "block_reason": "发现 {p0_count} 个P0级Bug，需修复后重新测试"
}
```

## 报告内容结构

### Markdown 报告模板（@templates/report-template.md）

```markdown
# 自动化测试报告

- **需求号**: {work_item_id}
- **产品线**: {product_line}
- **技术栈**: {tech_stack_tags}
- **测试时间**: {start_time} ~ {end_time}

## 1. 测试概要

| 指标 | 数值 |
|------|------|
| 总用例数 | {total_cases} |
| 通过 | {passed} |
| 失败 | {failed} |
| 跳过 | {skipped} |
| 通过率 | {pass_rate}% |

## 2. 前置Agent关联

| Agent | 状态 | 产出物路径 |
|-------|------|-----------|
| PRD解析 | {prd_agent_status} | {prd_path} |
| 架构设计 | {arch_agent_status} | {arch_path} |
| 代码审查 | {review_agent_status} | {review_path} |

## 3. Bug清单（按P0/P1/P2/P3）

...

## 4. 用例-需求追溯表

| 用例ID | 测试类型 | 关联功能点 | 关联接口 | 关联审查问题 | 结果 |
|--------|---------|-----------|---------|------------|------|
| TC-PRD-001 | 正常场景 | 患者列表查询 | - | - | ✅ |
| TC-ARCH-005 | 接口测试 | - | GET /api/patient | - | ✅ |
| TC-REVIEW-003 | 异常场景 | - | - | NPE风险 #3 | ❌ |

## 5. 医疗合规检查

...

## 6. 改进建议

...
```

## 产出物
- 完整报告文件（Markdown / HTML / JSON / CSV）
- TFS 工作项更新结果

## 检查点