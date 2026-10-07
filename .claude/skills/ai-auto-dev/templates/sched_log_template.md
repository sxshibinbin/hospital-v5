# 调度日志 - 需求 {需求号}

> 需求名称：{需求名称}
> 启动时间：{时间}
> 调度模式：智能调度

---

## 技能索引

| 技能名 | Tags | 匹配步骤 |
|--------|------|----------|
| {技能名} | {tags} | {步骤名} |

---

## 步骤执行记录

### Step 1: 创建 Worktree 和分支
- **状态**：{pending/running/success/failed}
- **时间**：{时间}
- **Worktree**：worktree-{需求号}
- **分支**：feature/{需求号}

### Step 2: 后端编码
- **状态**：{pending/running/success/failed}
- **调度方式**：{Skill调用/自主执行}
- **开始时间**：{时间}
- **结束时间**：{时间}
- **文件数**：{数量}

### Step 3: 前端编码
- **状态**：{pending/running/success/failed}
- **调度方式**：{Skill调用/自主执行}
- **开始时间**：{时间}
- **结束时间**：{时间}
- **文件数**：{数量}

### Step 4: 代码评审
- **状态**：{pending/running/success/failed}
- **调度方式**：自主执行
- **开始时间**：{时间}
- **结束时间**：{时间}
- **结果**：{评审结论}

### Step 5: 自动化测试
- **状态**：{pending/running/success/failed}
- **调度方式**：自主执行
- **开始时间**：{时间}
- **结束时间**：{时间}
- **结果**：{测试结论}

### Step 6: Git提交
- **状态**：{pending/running/success/failed}
- **调度方式**：{Skill调用/自主执行}
- **开始时间**：{时间}
- **结束时间**：{时间}
- **Commit ID**：{commit_id}
- **推送状态**：{已推送/待推送}

### Step 7: 清理前验证
- **状态**：{pending/running/success/failed}
- **开始时间**：{时间}
- **验证项**：
  - Git提交状态：{success/failed}
  - 工作区状态：{干净/有变更}

### Step 8: 清理 Worktree
- **状态**：{pending/running/success/failed/skipped}
- **开始时间**：{时间}
- **结束时间**：{时间}
- **原因**：{如果skipped，说明原因}

---

## 流程完成状态

- **整体状态**：{成功/失败/部分完成}
- **完成时间**：{时间}
- **处理时长**：{分钟数}
- **分支保留**：feature/{需求号}（供后续合并）

---

## 备注

{其他需要记录的信息}