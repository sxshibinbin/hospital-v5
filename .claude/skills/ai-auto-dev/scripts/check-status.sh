#!/bin/bash
# check-status.sh - 检查步骤执行状态
# 用法: ./check-status.sh <需求号> <步骤名称> <DOCS路径>
#
# 注意：此脚本需要在项目根目录下执行，DOCS路径默认为项目根目录下的DOCS目录

set -e

REQ_ID="${1:-}"
STEP_NAME="${2:-}"
DOCS_PATH="${3:-DOCS}"

if [ -z "$REQ_ID" ] || [ -z "$STEP_NAME" ]; then
    echo "错误: 缺少必要参数"
    echo "用法: ./check-status.sh <需求号> <步骤名称> <DOCS路径>"
    exit 1
fi

EXEC_PROG_FILE="${DOCS_PATH}/${REQ_ID}/${STEP_NAME}/exec_prog.md"

if [ ! -f "$EXEC_PROG_FILE" ]; then
    echo "状态: missing"
    echo "文件不存在: $EXEC_PROG_FILE"
    exit 0
fi

echo "=== 检查执行状态 ==="
echo "需求号: $REQ_ID"
echo "步骤: $STEP_NAME"
echo "文件: $EXEC_PROG_FILE"

# 提取状态
STATUS=$(grep -E "^- 状态:" "$EXEC_PROG_FILE" | head -1 | sed 's/^- 状态: //' | tr -d ' ')
echo "当前状态: $STATUS"

# 提取开始时间
START_TIME=$(grep -E "^- 开始时间:" "$EXEC_PROG_FILE" | head -1 | sed 's/^- 开始时间: //')
echo "开始时间: $START_TIME"

# 提取重试次数
RETRY_COUNT=$(grep -E "^- 重试次数:" "$EXEC_PROG_FILE" | head -1 | sed 's/^- 重试次数: //' | tr -d ' ')
echo "重试次数: $RETRY_COUNT"

# 提取当前断点
BREAKPOINT=$(grep -E "^- 当前断点:" "$EXEC_PROG_FILE" | head -1 | sed 's/^- 当前断点: //')
echo "当前断点: $BREAKPOINT"

# 检查文件最后更新时间
LAST_UPDATE=$(stat -c %Y "$EXEC_PROG_FILE" 2>/dev/null || stat -f %m "$EXEC_PROG_FILE" 2>/dev/null)
NOW=$(date +%s)
DIFF=$((NOW - LAST_UPDATE))
echo "最后更新: ${DIFF}秒前"

# 输出状态摘要
echo ""
echo "=== 状态摘要 ==="
echo "status=${STATUS}"
echo "retry_count=${RETRY_COUNT}"
echo "last_update_seconds=${DIFF}"
echo "breakpoint=${BREAKPOINT}"