# Stage 4: 结果聚合

## 输入
- issues: 原始问题列表

## 处理步骤

### Step 4.1: 问题去重
按 `(file_path, line_number, rule_id)` 三元组去重：
- 同一文件、同一行、同一规则只保留一条

### Step 4.2: 按严重级别排序
排序优先级：critical > warning > info > suggestion

### Step 4.3: 按规则分组
将问题按 `rule_id` 分组，生成修复建议汇总：

```json
{
  "rule_id": "JAVA-SEC-001",
  "rule_name": "SQL注入风险检查",
  "severity": "critical",
  "issue_count": 3,
  "affected_files": [
    "src/.../UserService.java",
    "src/.../OrderService.java"
  ],
  "fix_guidance": {
    "description": "使用参数化查询...",
    "code_example": "..."
  }
}
```

### Step 4.4: 生成统计摘要
```json
{
  "total_issues": 15,
  "critical": 2,
  "warning": 5,
  "info": 8,
  "suggestion": 0,
  "by_category": {
    "security": 5,
    "performance": 3,
    "quality": 4,
    "standard": 3
  },
  "by_tech_stack": {
    "java": 10,
    "vue": 5
  }
}
```

### Step 4.5: 生成修复优先级
按严重级别和影响范围生成修复优先级：
- P0: critical级别问题
- P1: warning级别且影响超过3个文件
- P2: warning级别问题
- P3: info/suggestion级别问题

## 输出
```json
{
  "issues": [...],
  "summary": {
    "total_issues": 15,
    "critical": 2,
    "warning": 5,
    "info": 8
  },
  "fix_suggestions": [...],
  "priority_order": ["P0", "P1", "P2", "P3"]
}
```
