# Git Worktree 操作指南

## Worktree 简介

Git Worktree 允许在同一仓库中同时检出多个分支到不同目录，每个目录有独立的工作区。

### 优势
- **隔离开发环境**：不同需求号在不同目录开发，互不干扰
- **避免频繁切换分支**：无需 stash 或 checkout
- **并行开发支持**：多个需求可同时开发

## Worktree 在 ai-auto-dev 中的应用

### 创建规则
- Worktree路径：`worktree-{需求号}`
- 分支名：`feature/{需求号}`
- 基于基础分支（如 develop/master）创建

### 管理职责
| 操作 | 负责方 |
|------|--------|
| 创建 worktree | 总调度 |
| 切换目录 | 总调度 |
| 清理 worktree | 总调度 |
| 在 worktree 中工作 | 子Agent |

## 常用命令

### 创建 Worktree
```bash
# 从当前分支创建新 worktree 和新分支
git worktree add worktree-REQ-001 -b feature/REQ-001 --no-track

# 从已有分支创建 worktree
git worktree add worktree-REQ-001 feature/REQ-001
```

### 查看 Worktree 列表
```bash
git worktree list
```

### 删除 Worktree
```bash
# 正常删除
git worktree remove worktree-REQ-001

# 强制删除（有未提交变更时）
git worktree remove worktree-REQ-001 --force
```

### 清理 Worktree
```bash
# 清理已删除的 worktree 记录
git worktree prune
```

## ai-auto-dev Worktree 脚本

### init-worktree.sh
```bash
#!/bin/bash
# 初始化 worktree
# 用法: ./init-worktree.sh <需求号> <基础分支> <仓库路径>

REQ_ID=$1
BASE_BRANCH=$2
REPO_PATH=$3

WORKTREE_PATH="${REPO_PATH}/worktree-${REQ_ID}"
FEATURE_BRANCH="feature/${REQ_ID}"

cd "$REPO_PATH"

# 检查 worktree 是否已存在
if [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree 已存在: $WORKTREE_PATH"
    exit 0
fi

# 创建 worktree
git worktree add "$WORKTREE_PATH" -b "$FEATURE_BRANCH" --no-track

echo "Worktree 创建成功: $WORKTREE_PATH ($FEATURE_BRANCH)"
```

### cleanup-worktree.sh
```bash
#!/bin/bash
# 清理 worktree
# 用法: ./cleanup-worktree.sh <需求号> <仓库路径>

REQ_ID=$1
REPO_PATH=$2

WORKTREE_PATH="${REPO_PATH}/worktree-${REQ_ID}"
FEATURE_BRANCH="feature/${REQ_ID}"

cd "$REPO_PATH"

# 删除 worktree
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null

# 删除分支
git branch -D "$FEATURE_BRANCH" 2>/dev/null

echo "Worktree 和分支已清理: $WORKTREE_PATH, $FEATURE_BRANCH"
```

## 常见问题

### Q: Worktree 创建失败？
A: 检查分支名是否已存在、路径是否被占用。

### Q: 如何在 worktree 中工作？
A: 子Agent会被总调度切换到 worktree 目录，在该目录中执行开发工作。

### Q: Worktree 中的变更如何提交？
A: 在 worktree 目录中执行 git add/commit，然后 push 到远程。

### Q: 多个 worktree 之间冲突？
A: 每个 worktree 是独立的 Git 工作区，不会冲突。但 push 到远程时可能有分支冲突。

### Q: 如何恢复中断的开发？
A: Worktree 目录保持存在，子Agent重新进入目录后可从断点继续。

---

## ⛔ 禁止的命令模式（安全层强制拦截）

> **⚠️ 警告：以下命令模式会被 Claude Code 安全层强制拦截，触发人工确认弹窗！**
>
> **无论如何配置白名单，这些命令都会被阻止！请勿尝试执行！**

### 禁止模式一：`cd` 与 `git` 组合命令

```bash
# ⛔ 禁止执行 - 会触发安全层拦截
cd worktree-26051901 && git status
cd worktree-26051901 && git log
cd worktree-26051901 && git add -A
cd worktree-26051901 && git commit -m "msg"
cd worktree-26051901 && git push
```

**替代方案**：使用 `git -C` 参数（见下方推荐方案）

### 禁止模式二：在 worktree 目录内执行 git 命令

```bash
# ⛔ 禁止执行 - 当 pwd = /path/worktree-26051901 时
git status  # 会触发确认弹窗
git log     # 会触发确认弹窗
```

**替代方案**：在项目根目录使用 `git -C` 参数

---

## ✅ 推荐命令模式（安全可执行）

### 推荐方案一：使用 `git -C` 指定目录

**适用场景**：从项目根目录操作 worktree

```bash
# ✅ 推荐 - 从根目录操作 worktree（不会触发安全层拦截）
git -C worktree-26051901 status --porcelain
git -C worktree-26051901 log --oneline -3
git -C worktree-26051901 diff
git -C worktree-26051901 add -A
git -C worktree-26051901 commit -m "message"
git -C worktree-26051901 push
```

### ⛔ 禁止使用 EnterWorktree 工具

**EnterWorktree 工具会创建 `.claude/worktrees/` 下的 worktree，与规范不一致！**

```
# ⛔ 禁止 - EnterWorktree 工具（创建错误路径）
EnterWorktree({name: "worktree-26051901"})
# 这会在 .claude/worktrees/worktree-26051901 创建目录，而不是项目根目录

# ✅ 正确 - 使用 git worktree 命令（创建正确路径）
git worktree add worktree-26051901 -b feature/26051901 --no-track
# 这在项目根目录创建 worktree-26051901
```

---

## 命令对照表（禁止 → 推荐）

| 场景 | ⛔ 禁止命令（会触发拦截） | ✅ 推荐命令（安全执行） |
|------|--------------------------|------------------------|
| 查看状态 | `cd path && git status` | `git -C path status` |
| 查看日志 | `cd path && git log` | `git -C path log` |
| 添加文件 | `cd path && git add -A` | `git -C path add -A` |
| 提交代码 | `cd path && git commit` | `git -C path commit -m "msg"` |
| 推送代码 | `cd path && git push` | `git -C path push` |
| 进入工作 | ⛔ 禁止 EnterWorktree | ✅ 使用 git -C 参数或绝对路径 |

### 非 git 命令的处理

非 git 命令（如 `ls`、`mvn`、`npm`）不受安全层限制：

```bash
# ✅ 允许 - 非 git 命令组合
cd worktree-26051901 && ls -la
cd worktree-26051901 && mvn compile

# ✅ 或使用路径参数
ls -la worktree-26051901/
mvn -f worktree-26051901/pom.xml compile
```

### 白名单配置说明

白名单配置 `Bash(cd * && git *)` 仅控制**权限询问**，不影响**安全层检查**：

```
用户配置权限白名单 ──→ 控制：是否需要用户批准执行命令
Claude Code 安全层 ──→ 控制：强制拦截危险命令模式（不可配置）
```

两者独立运作，安全层优先级更高。
