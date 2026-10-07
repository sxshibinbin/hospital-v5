# Stage 4.5: Bug分析与修复重测循环

## 目标
Stage 4 测试执行发现 P0/P1 级别失败后，自动分析根因、定位代码、生成修复、编译验证、重测确认，形成闭环。最多重试 3 轮，P2/P3 仅记录不阻断。

## 触发条件
- Stage 4 测试结果中存在 **P0（Critical）** 或 **P1（High）** 级别失败用例
- `auto_fix_enabled` 参数为 `true`（默认）

## ⚠️ 安全约束
- **禁止使用组合命令**：每个命令单独执行，禁止 `&&`、`;`、`|`
- **修复前必须备份**：修改源文件前，先复制为 `.bak` 备份文件
- **禁止修改生产配置**：不得修改 application-prod.yml、web.config 等生产环境配置
- **禁止删除测试用例**：不得通过删除/跳过测试用例来提高通过率
- **医疗关键修复需标记**：涉及剂量计算、患者数据、权限控制的修复，必须在报告中标记"需人工复核"

---

## 执行步骤

### 4.5.0 初始化修复上下文

1. 更新 `exec_prog.md` 状态为 `Stage 4.5 - Bug修复重测`
2. 创建输出目录：
   ```bash
   mkdir -p DOCS/{work_item_id}/Bug修复
   ```
3. 从 Stage 4 测试结果提取失败用例列表，按优先级排序：P0 → P1
4. P2/P3 级别 Bug 仅记录到 Bug 清单，不进入修复流程
5. 读取配置 `config/bug-fix-config.template.json`（如存在项目级配置则优先使用）
6. 记录修复前通过率 `pass_rate_before`

**数据结构**：
```json
{
  "fix_queue": [
    {
      "bug_id": "BUG-001",
      "severity": "P0",
      "test_class": "PatientServiceTest",
      "test_method": "testFindPatientById",
      "error_type": "NullPointerException",
      "error_message": "Cannot invoke method on null object",
      "stack_trace": "...",
      "source_file_hint": "PatientService.java:45"
    }
  ],
  "p2_p3_only_record": ["BUG-005", "BUG-008"],
  "retry_round": 1,
  "max_rounds": 3
}
```

### 4.5.1 根因分析（逐 Bug）

对修复队列中的每个 Bug，执行根因分析：

1. **加载分析规则**：读取 `references/bug-analysis-rules.md`，匹配错误类型
2. **提取关键词**：从错误堆栈、测试输出中提取匹配关键词
3. **分类 Bug 类型**：匹配 13 种规则之一（如 NULL_POINTER、SQL_INJECTION 等）
4. **记录分析结果**：

```json
{
  "bug_id": "BUG-001",
  "matched_rule": "NULL_POINTER",
  "root_cause": "patientService.findById() 返回 null 后直接调用 .getName()，未做判空",
  "affected_file": "src/main/java/.../service/PatientService.java",
  "affected_line": 45,
  "confidence": "HIGH"
}
```

### 4.5.2 代码定位

1. **Grep 搜索**：用堆栈中的类名/方法名搜索源文件
   ```
   Grep pattern="class PatientService" path="{project_root}/src"
   ```
2. **Glob 定位**：
   ```
   Glob pattern="**/PatientService.java" path="{project_root}"
   ```
3. **读取上下文**：读取目标文件，定位问题代码前后 30 行
4. **关联审查问题**：检查 `DOCS/{work_item_id}/代码审查/` 中是否有对应问题的审查记录

### 4.5.3 生成修复

1. **加载修复策略**：读取 `references/fix-strategies.md`，按 Bug 类型选择修复模板
2. **生成修复方案**：
   - 优先使用策略模板中的标准修复模式
   - 结合上下文代码调整变量名、类名、异常类型
   - 每个 Bug 最多准备 3 种修复策略（A/B/C）
3. **安全检查**：
   - 修复不得引入新的硬编码值
   - 修复不得修改公共 API 签名（除非必要）
   - 医疗相关修复（剂量/权限/数据完整性）标记 `require_human_review: true`
4. **文件大小检查**：目标文件不超过 `max_file_size_kb`（默认 500KB）

### 4.5.4 应用修复 + 编译验证

对每个修复方案，按以下顺序执行（**每个命令单独执行**）：

1. **备份原文件**：
   ```bash
   cp {target_file} {target_file}.bak
   ```

2. **应用修复**：使用 Edit 工具精确替换问题代码

3. **编译验证**（单独执行，不要用 && 组合）：
   ```bash
   # Java 项目
   mvn compile -q -f {project_root}/pom.xml
   ```
   ```bash
   # C# 项目
   dotnet build --no-restore {project_root}/{project}.csproj
   ```
   ```bash
   # Vue/前端项目
   npm run build --prefix {project_root}
   ```

4. **编译失败处理**：
   - 编译失败 → 回滚备份文件：
     ```bash
     cp {target_file}.bak {target_file}
     ```
   - 尝试下一种修复策略（回到 4.5.3）

### 4.5.5 重测该用例

编译通过后，仅重测当前 Bug 关联的测试类/方法：

```bash
# Java - 仅测试失败的类（单独执行）
mvn test -Dtest={TestClass} -f {project_root}/pom.xml
```

```bash
# C# - 仅测试失败的方法（单独执行）
dotnet test --filter "FullyQualifiedName~{TestName}" --no-restore
```

```bash
# Vue/前端（单独执行）
npm test --prefix {project_root} -- --testPathPattern={TestFile}
```

**结果判定**：
- ✅ 测试通过 → 标记 `fix_status: "FIXED"`，删除 `.bak` 备份，进入下一个 Bug（4.5.6）
- ❌ 测试仍失败 → 回滚 `.bak`，尝试下一种修复策略
  - 3 种策略均失败 → 标记 `fix_status: "NEED_MANUAL_FIX"`，恢复原文件，进入下一个 Bug

### 4.5.6 下一个 Bug

1. 更新 `exec_prog.md` 中当前 Bug 修复进度
2. 从修复队列取出下一个 P0/P1 Bug
3. 回到 4.5.1 继续处理
4. 所有 P0/P1 Bug 处理完毕后，进入 4.5.7

### 4.5.7 全量重测

所有可修复 Bug 处理完毕后，重跑全部测试用例进行回归验证：

```bash
# Java（单独执行）
mvn test -f {project_root}/pom.xml
```

```bash
# C#（单独执行）
dotnet test --no-restore
```

**结果判定**：
- ✅ 全部通过 → 更新 `exec_prog.md` 为 `Stage 4.5 完成`，进入 Stage 5
- ❌ 仍有 P0/P1 失败：
  - `retry_round < max_rounds` → 回到 4.5.0，开始下一轮修复
  - `retry_round >= max_rounds` → 标记剩余 Bug 为 `NEED_MANUAL_FIX`，进入 Stage 5

---

## 产出物

| 文件 | 路径 | 说明 |
|------|------|------|
| Bug修复报告 | `DOCS/{work_item_id}/Bug修复/bug_fix_report.md` | 每个 Bug 的修复详情 |
| 修复汇总JSON | `DOCS/{work_item_id}/Bug修复/fix_summary.json` | 结构化修复统计 |
| 备份文件 | `{source_file}.bak` | 修复前的源文件备份（修复成功后删除） |

## 检查点
- [ ] 所有 P0/P1 Bug 已处理（修复或标记需人工介入）
- [ ] 每个修复都有对应的 `.bak` 备份（或修复成功后已清理）
- [ ] 编译通过，无新增编译错误
- [ ] 全量重测已执行
- [ ] `exec_prog.md` 已更新修复进度
- [ ] 医疗相关修复已标记人工复核
- [ ] 修复报告已生成

## 关联的 exec_prog.md 字段
- `s45_status` — Stage 4.5 状态
- `s45_retry_round` — 当前修复轮次
- `s45_bugs_total` — 待修复 Bug 总数
- `s45_bugs_fixed` — 已修复数
- `s45_bugs_failed` — 修复失败数
- `s45_pass_rate_before` — 修复前通过率
- `s45_pass_rate_after` — 修复后通过率
