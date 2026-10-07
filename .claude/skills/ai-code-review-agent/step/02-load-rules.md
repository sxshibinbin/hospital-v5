# Stage 2: 规则加载

## 输入
- tech_stack_tags: 技术栈标签数组
- product_line: 产品线名称
- scan_type: 扫描类型（full/security/quality）

## 处理步骤

### Step 2.1: 加载通用编码规则
读取 `rules/common/common-rules.json`：
- 过滤 `tech_stack` 字段匹配当前技术栈的规则
- 约120条规则

### Step 2.2: 加载医疗通用规则
读取 `rules/medical/medical-rules.json`：
- 过滤 `tech_stack` 字段匹配当前技术栈的规则
- 约45条规则

### Step 2.3: 加载产品线规则
根据 `product_line` 参数读取对应目录：
- AI-MY → `rules/product/AI-MY/ai-my-rules.json`
- AI重症 → `rules/product/AI重症/`
- 病历质控 → `rules/product/病历质控/`
- CDSS → `rules/product/CDSS/`
- 医保控费 → `rules/product/医保控费/`

### Step 2.4: 按扫描类型过滤规则

| scan_type | 包含的category |
|-----------|---------------|
| full | security, performance, quality, standard, medical |
| security | security, medical |
| quality | quality, standard |

### Step 2.5: 合并去重
按 `rule_id` 去重：
- 后加载的规则覆盖先加载的规则
- 项目级规则 > 产品线规则 > 医疗规则 > 通用规则

## 输出
```json
{
  "rules": [
    {
      "rule_id": "COMMON-SEC-001",
      "rule_name": "SQL注入风险检查",
      "category": "security",
      "severity": "critical",
      "tech_stack": ["java"],
      "detection": { ... },
      "fix_guidance": { ... }
    }
  ],
  "total_rules": 85
}
```

## 规则加载优先级
1. 通用编码规则（必选）
2. 医疗通用规则（医疗项目必选）
3. 产品线规则（按产品线选择）
4. 项目规则（可选覆盖）
