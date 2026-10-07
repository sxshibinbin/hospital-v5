# sched_log.md 模板

> **用途**：ai-auto-dev 执行进度追踪日志
> **路径**：`worktree-{需求号}/DOCS/{需求号}/sched_log.md`
> **更新方式**：使用 Edit 工具替换对应步骤的占位符区块

---

## 模板完整内容

```markdown
# 调度日志 - 需求 {需求号}

> 需求名称：{需求名称}
> 启动时间：{时间}
> 调度模式：子Agent强制调用
> DOCS路径：worktree-{需求号}/DOCS/{需求号}/
> 前置依赖：需求设计文档已就绪（DOCS/{需求号}/需求设计/）

---

## 步骤执行记录

<!-- STEP0_BLOCK -->
### Step 0: 初始化
- **状态**：pending
- **前置验证**：-
<!-- STEP0_END -->

<!-- STEP1_BLOCK -->
### Step 1: 创建 Worktree 和分支 + 复制DOCS文档
- **状态**：pending
- **Worktree路径**：worktree-{需求号}
- **分支名称**：feature/{需求号}
- **DOCS目录**：worktree-{需求号}/DOCS/{需求号}/
- **前置产出物复制**：-
<!-- STEP1_END -->

<!-- STEP2_BLOCK -->
### Step 2: 后端编码
- **状态**：pending
- **调度方式**：子Agent强制调用（ai-backend-dev-pro）
- **技能文件**：.claude/skills/ai-backend-dev-pro/SKILL.md
- **前置产出物路径**：worktree-{需求号}/DOCS/{需求号}/需求设计/
<!-- STEP2_END -->

<!-- STEP3_BLOCK -->
### Step 3: 前端编码
- **状态**：pending
- **调度方式**：子Agent强制调用（ai-frontend-dev-pro）
- **技能文件**：.claude/skills/ai-frontend-dev-pro/SKILL.md
- **前置产出物路径**：worktree-{需求号}/DOCS/{需求号}/需求设计/
<!-- STEP3_END -->

<!-- STEP4_BLOCK -->
### Step 4: 代码评审
- **状态**：pending
- **调度方式**：子Agent强制调用（ai-code-review-agent）
- **技能文件**：.claude/skills/ai-code-review-agent/SKILL.md
- **评审记录**：worktree-{需求号}/DOCS/{需求号}/代码审查/
<!-- STEP4_END -->

<!-- STEP5_BLOCK -->
### Step 5: 自动化测试
- **状态**：pending
- **调度方式**：子Agent强制调用（ai-automated-test-agent）
- **技能文件**：.claude/skills/ai-automated-test-agent/SKILL.md
- **测试记录**：worktree-{需求号}/DOCS/{需求号}/自动化测试/
<!-- STEP5_END -->

<!-- STEP6_BLOCK -->
### Step 6: Git提交
- **状态**：pending
- **调度方式**：子Agent强制调用（ai-git-push）
- **技能文件**：.claude/skills/ai-git-push/SKILL.md
- **提交内容**：代码 + DOCS文档
<!-- STEP6_END -->

<!-- STEP7_BLOCK -->
### Step 7: 清理前验证
- **状态**：pending
- **验证项**：-
- **验证结果**：-
- **执行时间**：-
- **备注**：-
<!-- STEP7_END -->

<!-- STEP8_BLOCK -->
### Step 8: 清理 Worktree
- **状态**：pending
- **清理操作**：-
- **清理结果**：-
- **执行时间**：-
- **备注**：-
<!-- STEP8_END -->

---

<!-- COMPLETION_BLOCK -->
## 流程完成状态

- **整体状态**：进行中
- **启动时间**：{从文档头部读取}
- **完成时间**：-
- **整体耗时**：-
- **成功步骤**：0/8
- **失败步骤**：-
- **跳过步骤**：-
- **备注**：-
<!-- COMPLETION_END -->
```

---

## 占位符区块说明

| 占位符 | 覆盖内容 | 更新时机 |
|--------|----------|----------|
| `<!-- STEP0_BLOCK -->` 到 `<!-- STEP0_END -->` | Step 0 初始化状态 | Step 0 完成后 |
| `<!-- STEP1_BLOCK -->` 到 `<!-- STEP1_END -->` | Step 1 Worktree创建状态 | Step 1 完成后 |
| `<!-- STEP7_BLOCK -->` 到 `<!-- STEP7_END -->` | Step 7 清理前验证详情 | Step 7 完成后 |
| `<!-- STEP8_BLOCK -->` 到 `<!-- STEP8_END -->` | Step 8 Worktree清理详情 | Step 8 完成后 |
| `<!-- COMPLETION_BLOCK -->` 到 `<!-- COMPLETION_END -->` | 流程完成状态汇总 | Step 9 完成后 |

---

## Edit 工具使用示例

### 更新 Step 7 状态

```javascript
Edit({
  file_path: "worktree-{需求号}/DOCS/{需求号}/sched_log.md",
  old_string: `<!-- STEP7_BLOCK -->
### Step 7: 清理前验证
- **状态**：pending
- **验证项**：-
- **验证结果**：-
- **执行时间**：-
- **备注**：-
<!-- STEP7_END -->`,
  new_string: `<!-- STEP7_BLOCK -->
### Step 7: 清理前验证
- **状态**：success
- **验证项**：Git提交状态验证 + 工作区状态验证
- **验证结果**：通过 - Step 6 状态为 success，工作区无未提交变更
- **执行时间**：2026-05-27 14:30:00
- **备注**：验证通过，进入清理阶段
<!-- STEP7_END -->`
})
```

### 更新 Step 8 状态

```javascript
Edit({
  file_path: "worktree-{需求号}/DOCS/{需求号}/sched_log.md",
  old_string: `<!-- STEP8_BLOCK -->
### Step 8: 清理 Worktree
- **状态**：pending
- **清理操作**：-
- **清理结果**：-
- **执行时间**：-
- **备注**：-
<!-- STEP8_END -->`,
  new_string: `<!-- STEP8_BLOCK -->
### Step 8: 清理 Worktree
- **状态**：success
- **清理操作**：git worktree remove worktree-{需求号} --force
- **清理结果**：成功清理 - worktree 已移除
- **执行时间**：2026-05-27 14:35:00
- **备注**：清理完成，流程结束
<!-- STEP8_END -->`
})
```

### 更新流程完成状态

```javascript
Edit({
  file_path: "worktree-{需求号}/DOCS/{需求号}/sched_log.md",
  old_string: `<!-- COMPLETION_BLOCK -->
## 流程完成状态

- **整体状态**：进行中
- **启动时间**：{从文档头部读取}
- **完成时间**：-
- **整体耗时**：-
- **成功步骤**：0/8
- **失败步骤**：-
- **跳过步骤**：-
- **备注**：-
<!-- COMPLETION_END -->`,
  new_string: `<!-- COMPLETION_BLOCK -->
## 流程完成状态

- **整体状态**：成功
- **启动时间**：2026-05-27 10:00:00
- **完成时间**：2026-05-27 14:35:00
- **整体耗时**：4小时35分钟
- **成功步骤**：8/8
- **失败步骤**：无
- **跳过步骤**：无
- **备注**：所有步骤执行成功，流程正常结束
<!-- COMPLETION_END -->`
})
```

---

## 状态值说明

| 字段 | 可选值 |
|------|--------|
| **状态**（Step 0-7） | pending → success → failed |
| **状态**（Step 8） | pending → success → skipped → failed |
| **整体状态** | 进行中 → 成功 → 部分成功 → 失败 |

---

*此模板文件供 ai-auto-dev 技能使用，详细执行指令见 step-execution.md*