---
name: ai-git-merge
description: |
  Git 分支合并工作流。当用户请求合并分支、同步主分支、merge、拉取最新代码时触发此技能。
  必须触发场景：用户说"合并分支"、"同步分支"、"merge"、"拉取主分支代码"、"更新分支"。
  准入条件：分支已推送到远程仓库（无本地未推送提交）。
  准出条件：合并后的代码通过编译和测试验证，推送远程成功，并完成需求标签更新（如有需求号）。
  输出文档：DOCS/{需求号}Git合并/exec_prog.md（追加模式）。
  需求标签：推送成功后自动为关联需求打上 AI-AUTO-DONE 标签（通过 ai-tfs-integration 技能）。
tags: [git, merge, 分支合并, 工作流, devops, tfs]
keywords: [合并分支, ai-git-merge, merge, 同步分支, 拉取代码, 分支同步]
metadata:
  author: Claude
  version: 2.0.0
---

# Git Merge Skill

将主分支合并到开发分支，确保代码可编译可运行，并自动更新需求状态标签。

## 确认点

- Step 1 准入失败 → 先推送/强制继续/取消
- Step 2 首次使用 → 选择主分支
- Step 6 有冲突 → 选择解决策略
- Step 7 验证失败 → 终止/继续
- Step 9 推送前 → 是否推送
- Step 10 需求标签 → 自动/手动提供需求号/跳过

---

## Step 0: 项目检测

检测当前目录是否为 git 仓库，多模块时用户选择操作范围。

---

## Step 1: 准入检查

检查分支是否已推送远程：

```bash
git log origin/$(git branch --show-current)..HEAD --oneline
```

- 无未推送提交 → 通过
- 有未推送提交 → 选择先推送/强制继续/取消

---

## Step 2: 确定主分支

```bash
git config --get claude-merge.mainBranch
```

- 已配置 → 直接使用
- 首次配置 → 用户选择 master/main/develop/自定义

---

## Step 3: 获取远端更新

```bash
git fetch origin
```

---

## Step 4: 更新主分支

```bash
MAIN_BRANCH=$(git config --get claude-merge.mainBranch)
git checkout $MAIN_BRANCH
git pull origin $MAIN_BRANCH
```

---

## Step 5: 合到开发分支

```bash
git checkout <开发分支>
git merge <主分支>
```

- 无冲突 → 进入 Step 7
- 有冲突 → 进入 Step 6

---

## Step 6: 处理冲突

每个冲突文件选择处理策略。

详见 `references/conflict-handling.md`。

---

## Step 7: 验证代码

自动检测项目类型并执行编译+测试。

详见 `references/verification.md`。

---

## Step 8: 更新文档

写入 `DOCS/{需求号}Git合并/exec_prog.md`（追加模式），记录合并信息、冲突处理、验证结果。

详见 `references/output-format.md`。

---

## Step 9: 推送

### 用户确认推送

### 分支保护检查

禁止推送 master/main/develop 等保护分支。

```bash
git push origin $(git branch --show-current)
```

---

## Step 10: 更新需求标签

推送成功后，通过 `ai-tfs-integration` 技能为关联需求添加 `AI-AUTO-DONE` 标签。

### 10.1 获取需求号

按以下优先级获取需求号：

1. **从分支名解析**（优先）

   分支命名规则通常包含需求号，常见模式：
   - `AI/260514` → 需求号 `260514`
   - `feature/12345` → 需求号 `12345`
   - `bugfix/67890` → 需求号 `67890`
   - `需求12345` → 需求号 `12345`

   解析逻辑：从分支名中提取数字序列（至少5位）

   ```bash
   # 获取当前分支名
   CURRENT_BRANCH=$(git branch --show-current)
   ```

2. **用户手动提供**

   如果分支名无法解析出需求号，询问用户：
   - "请提供关联的需求号（如 260514），如无需求号可输入 '跳过'"

3. **跳过此步骤**

   如果用户选择跳过或无需求号，记录日志并继续

### 10.2 调用 ai-tfs-integration 打标签

使用 `ai-tfs-integration` 技能的 `addTags` 方法：

```javascript
// 调用 TFSClient.addTags 方法
const client = new TFSClient();
await client.addTags(需求号, 'AI-AUTO-DONE');
```

**命令行方式**：
```bash
# 使用 tfs-query.mjs 工具（如果支持）
node .claude/skills/ai-tfs-integration/tools/tfs-query.mjs add-tag <需求号> AI-AUTO-DONE
```

**注意**：如果 `tfs-query.mjs` 不直接支持添加标签，需要使用 `tfs-client.mjs`：
```javascript
import TFSClient from './tfs-client.mjs';
const client = new TFSClient();
await client.addTags(需求号, 'AI-AUTO-DONE');
```

### 10.3 处理结果

- **成功**：记录 "✅ 已为需求 [需求号] 添加标签 AI-AUTO-DONE"
- **失败**：记录 "⚠️ 添加标签失败：[错误信息]，请手动添加标签"
- **跳过**：记录 "⏭️ 无需求号，跳过标签更新"

### 10.4 完成提醒

在技能完成报告中提醒用户：

```
💡 提醒：
- 如需手动添加标签，请在 TFS 中为工作项添加 "AI-AUTO-DONE" 标签
- 完整流程已完成（Step 0-10）
```

---

## 输出报告

推送成功后输出完整报告，包含需求标签更新状态，提示下一步操作。

报告格式详见 `references/output-format.md`。

---

## 参考文件

- `references/verification.md` - 验证命令映射
- `references/conflict-handling.md` - 冲突处理策略
- `references/output-format.md` - 过程文档模板、报告格式
