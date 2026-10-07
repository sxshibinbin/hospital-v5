# Stage 3: 测试代码生成

## 目标
根据 Stage 2 生成的用例清单，自动生成可执行的测试代码。

## 执行步骤

### 3.1 选择测试框架

根据 `tech_stack_tags` 选择对应的测试框架和模板：

| 技术栈标签 | 测试框架 | 模板位置 |
|-----------|---------|---------|
| java, spring | JUnit 5 + Mockito + MockMvc | `assets/junit5-template.java`, `assets/spring-boot-test-template.java` |
| csharp, dotnet | NUnit + Moq | `assets/csharp-nunit-template.cs` |
| vue, react | Jest + Playwright | 前端模板 |
| sql, mybatis | TestContainers + MSSQL | `assets/junit5-template.java` 中的数据层部分 |

### 3.2 生成测试代码

按以下顺序生成：

1. **单元测试**（优先级最高）：为每个 Service/Repository 类生成
   - 正常路径测试
   - Mock 依赖的边界条件
   - 异常处理测试
2. **接口测试**：为每个 REST API 端点生成
   - 请求/响应验证
   - MockMvc HTTP 链路测试
3. **集成测试**：涉及数据库/外部服务时生成
4. **UI测试**：仅前端项目生成

### 3.3 代码审查适配

检查代码审查报告中的问题列表：
- **安全漏洞**：增加对应的安全漏洞测试用例
  - SQL注入测试：在接口测试中插入恶意SQL字符
  - XSS测试：在输入参数中插入脚本标签
  - 敏感信息泄露：验证响应中是否包含明文密码/身份证
- **代码质量问题**：增加对应场景的异常测试
- **未修复问题**：标记为预期失败（`@Disabled` 或 `[Ignore]`），在报告中单独列出
- **已修复问题**：添加回归测试用例验证修复

### 测试代码目录结构

```text
{project_root}/src/test/java/com/winning/{module}/
├── service/
│   └── {ModuleName}ServiceTest.java    ← 单元测试
├── controller/
│   └── {ModuleName}ControllerTest.java ← 接口测试
├── repository/
│   └── {ModuleName}RepositoryTest.java  ← 数据层测试
└── medical/
    └── {ModuleName}ComplianceTest.java  ← 医疗合规测试
```

## 产出物
- 各测试代码文件（写入项目仓库 `{project_root}/src/test/...`）
- `DOCS/{work_item_id}/自动化测试/generated_test_files.json` — 生成的测试文件清单（记录每个文件在项目中的绝对路径）

## 检查点
- [ ] 测试代码语法正确，包路径匹配项目结构
- [ ] Mock 配置合理，不依赖真实数据库/外部服务
- [ ] 医疗测试类包含患者数据脱敏检查
- [ ] 权限测试覆盖所有角色

## 关联的 exec_prog.md 字段
- `s3_1_*` ~ `s3_3_*` — 各步骤状态
