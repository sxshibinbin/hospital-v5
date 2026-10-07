# 重试机制详细说明

## 重试机制概述

ai-auto-dev 对子Agent步骤执行失败提供自动重试机制，支持断点续传。

## 重试触发条件

| 条件 | 说明 |
|------|------|
| 子Agent返回失败 | 子Agent执行过程中遇到错误 |
| 步骤超时 | 步骤执行时间超过配置的超时时间 |
| exec_prog.md 状态异常 | 监控轮询发现状态为 failed 或 timeout |

## 重试流程

```
检测失败
  ↓
读取 exec_prog.md 获取断点位置
  ↓
暂停 RETRY_DELAY_SECONDS 秒
  ↓
重新发起该步骤，从断点继续
  ↓
记录重试事件到 sched_log.md
  ↓
检查重试次数是否超过 MAX_RETRY_COUNT
  ↓
是 → 发送 fail 通知，停止后续步骤
否 → 继续监控
```

## 断点续传机制

### 断点记录
在 exec_prog.md 中记录：
```markdown
## 执行状态
- 状态: failed | retrying
- 当前断点: 后端编码-Service.java-第3次编译失败
- 重试次数: 1
```

### 断点恢复
子Agent重新执行时：
1. 读取 exec_prog.md 的断点位置
2. 从断点处继续执行
3. 不重复已完成的工作

## 配置参数

| 配置键 | 默认值 | 说明 |
|--------|--------|------|
| MAX_RETRY_COUNT | 3 | 最大重试次数 |
| RETRY_DELAY_SECONDS | 10 | 重试前等待时间(秒) |

### 配置建议
- MAX_RETRY_COUNT：建议2-5次，过多重试浪费资源
- RETRY_DELAY_SECONDS：建议5-30秒，过短可能导致连续失败

## 超时判定

### 超时检测逻辑
```bash
# 检查 exec_prog.md 最后更新时间
LAST_UPDATE=$(stat -c %Y "DOCS/${REQ_ID}/${STEP}/exec_prog.md")
NOW=$(date +%s)
DIFF=$((NOW - LAST_UPDATE))

if [ $DIFF -gt $CHECK_INTERVAL_SECONDS ]; then
    echo "步骤执行停滞: ${STEP}"
    # 触发超时处理
fi

# 检查步骤执行时长
START_TIME=$(grep "开始时间" "DOCS/${REQ_ID}/${STEP}/exec_prog.md" | cut -d' ' -f3)
ELAPSED=$(计算时长)

if [ $ELAPSED -gt $STEP_TIMEOUT_CODER ]; then
    echo "步骤执行超时: ${STEP}"
    # 触发超时处理
fi
```

### 超时配置
| 配置键 | 默认值(分钟) | 说明 |
|--------|--------------|------|
| STEP_TIMEOUT_CODER | 60 | 编码步骤超时 |
| STEP_TIMEOUT_REVIEW | 30 | 评审步骤超时 |
| STEP_TIMEOUT_TEST | 45 | 测试步骤超时 |
| STEP_TIMEOUT_GIT | 15 | Git步骤超时 |

## 重试日志记录

### sched_log.md 格式
```markdown
| 时间戳 | 需求号 | 步骤 | 事件类型 | 详细信息 |
|--------|--------|------|----------|----------|
| 2026-05-14 10:35:00 | REQ-001 | 代码评审 | failed | 评审发现问题 |
| 2026-05-14 10:35:10 | REQ-001 | 代码评审 | retry | 第1次重试启动 |
| 2026-05-14 10:40:00 | REQ-001 | 代码评审 | failed | 第1次重试失败 |
| 2026-05-14 10:40:10 | REQ-001 | 代码评审 | retry | 第2次重试启动 |
| 2026-05-14 10:45:00 | REQ-001 | 代码评审 | success | 第2次重试成功 |
```

## 超过重试上限处理

当步骤重试次数超过 MAX_RETRY_COUNT 后：
1. 停止该需求号后续步骤执行
2. 更新 exec_prog.md 状态为 failed
3. 记录失败信息到 sched_log.md
4. 发送 fail 类型企业微信通知
5. 等待人工介入处理

## 人工介入后恢复

### 手动修复后继续
1. 人工修复问题后，更新 exec_prog.md 状态为 pending
2. 总调度检测到状态变化后重新触发该步骤
3. 从断点位置继续执行

### 强制跳过失败步骤
如需跳过某个失败步骤（风险操作）：
1. 更新 exec_prog.md 状态为 success（手动标记）
2. 手动补齐产出物
3. 后续步骤会继续执行

## 常见问题

### Q: 重试为什么会失败？
A: 可能原因：环境问题、依赖缺失、代码错误、网络问题等。

### Q: 如何查看重试历史？
A: 查看 DOCS/{需求号}/sched_log.md 的日志记录。

### Q: 重试次数如何调整？
A: 修改 DOCS/config.env 的 MAX_RETRY_COUNT 值。

### Q: 如何手动触发重试？
A: 更新 exec_prog.md 状态为 retrying，总调度会检测并重新触发。