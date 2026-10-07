# Stage 4: 测试执行

## 目标
执行生成的测试用例，收集测试结果，通过重试机制保障结果可靠性。

## ⚠️ 安全约束
**禁止使用组合命令**：CodeBuddy 底层有安全沙箱限制，禁止使用 `&&`、`;`、`|` 等管道/连接符组合多个命令。每个命令必须单独执行，各自独立调用。如需切换工作目录，使用工具的 `cwd` 参数，不要用 `cd` 命令。

## 执行步骤

### 4.1 执行单元测试

单个命令执行，使用绝对路径或 `cwd` 参数指定工作目录：

```bash
# Java 项目（单独执行，不要用 && 或 ; 组合）
mvn test -Dtest={TestClass1},{TestClass2} -DfailIfNoTests=false
```

```bash
# C# 项目（单独执行）
dotnet test --filter "FullyQualifiedName~target_namespace" --no-restore
```

### 4.2 执行接口测试

```bash
# Java 项目 - 仅运行接口测试类（单独执行）
mvn test -Dtest="*ControllerTest" -DfailIfNoTests=false
```

### 4.3 执行集成测试

```bash
# 如果项目有集成测试 Profile（单独执行）
mvn verify -P integration-test -Dtest="*IntegrationTest"
```

### 4.4 重试失败用例

对于失败的测试用例，自动重试1次：
- 重试仍然失败 → 标记为 Bug
- 重试成功 → 标记为 Flaky Test，在报告中单独列出

### 结果收集

收集以下测试结果文件：
- `target/surefire-reports/*.xml` — JUnit XML 格式（Java）
- `TestResults/*.trx` — TRX 格式（C#）
- `coverage-reports/` — 覆盖率报告（如存在）

## 产出物
- 原始测试结果（XML / TRX）
- `test_results_summary.json` — 汇总结果

## 检查点
- [ ] 测试执行完成，无挂起进程
- [ ] 原始结果文件已保存
- [ ] 失败用例已记录详细堆栈跟踪
- [ ] 重试机制已执行

## 关联的 exec_prog.md 字段
- `s4_1_*` ~ `s4_4_*` — 各步骤状态
- `java_*`, `csharp_*`, `vue_*` — 技术栈进度
- `p0_*` ~ `p3_*` — 优先级通过率
- `total_*` — 总计统计数据
