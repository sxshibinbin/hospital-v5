# Stage 3: 代码审查

## 输入
- files: 待审查文件列表
- rules: 生效规则集
- tech_stack_tags: 技术栈标签

## 处理步骤

### Step 3.1: 按技术栈分组文件
```python
files_by_stack = {
    "java": [file for file in files if file.tech_stack == "java"],
    "vue": [file for file in files if file.tech_stack == "vue"],
    "sql": [file for file in files if file.tech_stack == "sql"],
    ...
}
```

### Step 3.2: 并行执行各技术栈审查器

对每个技术栈执行**四轮审查法**：

#### 第一轮：逐行分析
- 命名规范检查
- 代码格式检查
- 注释完整性检查
- 异常处理检查
- 空值检查

#### 第二轮：结构分析
- 类职责划分检查
- 方法复杂度检查
- 循环嵌套深度检查
- 事务边界检查
- 资源释放检查

#### 第三轮：安全审计
- SQL注入检查
- XSS风险检查
- 敏感信息泄露检查
- 权限控制检查
- 加密算法检查

#### 第四轮：性能评估
- N+1查询检测
- 深分页识别
- 大集合操作检查
- 循环内RPC检查
- 缓存使用检查

### Step 3.3: 规则匹配与问题收集

对每个文件：
1. 读取文件内容
2. 遍历生效规则
3. 执行正则匹配或语义分析
4. 收集匹配的问题

### Step 3.4: 结果标准化
按统一格式输出每个问题：
```json
{
  "issue_id": "ISSUE-20260515-001",
  "rule_id": "JAVA-SEC-001",
  "rule_name": "SQL拼接风险",
  "category": "security",
  "severity": "critical",
  "file_path": "src/main/java/.../UserService.java",
  "line_number": 45,
  "code_snippet": "...",
  "description": "...",
  "fix_suggestion": "...",
  "fix_example": "..."
}
```

## 技术栈审查器

### Java审查器
重点检查：
- Controller/Service/Mapper/Entity/VO/DTO
- MyBatis XML SQL注入
- Spring注解使用
- 事务边界

### Vue3审查器
重点检查：
- 组件规范
- Props定义
- 响应式使用
- 组合式API
- v-html XSS风险

### SQL审查器
重点检查：
- SQL注入
- 索引缺失
- JOIN过多
- 分页优化

## 输出
```json
{
  "issues": [
    { "issue_id": "...", "severity": "critical", ... },
    { "issue_id": "...", "severity": "warning", ... }
  ],
  "files_scanned": 45,
  "scan_time": "2026-05-15T14:30:00Z"
}
```
