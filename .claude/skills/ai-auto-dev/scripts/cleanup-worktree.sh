#!/bin/bash
# cleanup-worktree.sh - 清理 Git Worktree
# 用法: ./cleanup-worktree.sh <需求号> <仓库路径>

set -e

REQ_ID="${1:-}"
REPO_PATH="${2:-.}"

if [ -z "$REQ_ID" ]; then
    echo "错误: 缺少需求号参数"
    echo "用法: ./cleanup-worktree.sh <需求号> <仓库路径>"
    exit 1
fi

WORKTREE_PATH="${REPO_PATH}/worktree-${REQ_ID}"
FEATURE_BRANCH="feature/${REQ_ID}"

cd "$REPO_PATH"

echo "=== 清理 Worktree ==="
echo "需求号: $REQ_ID"
echo "仓库路径: $REPO_PATH"
echo "Worktree路径: $WORKTREE_PATH"
echo "需求分支: $FEATURE_BRANCH"

# 删除 worktree
if [ -d "$WORKTREE_PATH" ]; then
    echo "删除 Worktree..."
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || {
        echo "警告: 无法删除 Worktree，可能存在未清理的引用"
        # 尝试清理 worktree 记录
        git worktree prune
    }
    echo "✅ Worktree 已删除: $WORKTREE_PATH"
else
    echo "Worktree 目录不存在，跳过删除"
fi

# 删除分支
if git show-ref --verify --quiet "refs/heads/${FEATURE_BRANCH}"; then
    echo "删除分支..."
    git branch -D "$FEATURE_BRANCH" 2>/dev/null || {
        echo "警告: 无法删除本地分支"
    }
    echo "✅ 分支已删除: $FEATURE_BRANCH"
else
    echo "分支不存在，跳过删除"
fi

# 清理 worktree 记录
git worktree prune 2>/dev/null

echo "✅ Worktree 和分支清理完成"