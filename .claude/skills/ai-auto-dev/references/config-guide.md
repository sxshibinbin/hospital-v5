# 配置文件详细说明

## 配置文件位置

`{项目根目录}/DOCS/config.env`

> **注意**：config.env 文件在具体开发项目的 DOCS 目录下创建，每个项目可独立配置。

## 子Agent智能调度

**使用 Agent 工具替代 Skill 工具**，避免嵌套调用问题：

| 特性 | 说明 |
|------|------|
| 调用方式 | 使用 Agent 工具启动子Agent执行 |
| 技能读取 | 子Agent自主读取技能文件并执行 |
| 上下文共享 | 子Agent与主调度共享工作目录，文档写入同一位置 |
| 文档路径 | 子Agent直接写入 worktree-{需求号}/DOCS/{需求号}/ |

详见 SKILL.md 中"子Agent调度机制"章节。

> **⚠️ 重要变更**：不再使用 `isolation: "worktree"` 参数，该参数会导致子Agent在 `.claude/worktrees/` 创建独立worktree，文档写入后被清理丢失。

## 调度参数配置

| 配置键 | 默认值 | 说明 | 建议范围 |
|--------|--------|------|----------|
| MAX_CONCURRENT_TASKS | 3 | 最大并发需求号数 | 1-5，视机器性能而定 |
| CHECK_INTERVAL_SECONDS | 600 | 轮询检查间隔(秒) | 300-900，过小浪费资源 |
| MAX_RETRY_COUNT | 3 | 最大重试次数 | 2-5 |
| RETRY_DELAY_SECONDS | 10 | 重试前等待时间(秒) | 5-30 |

### 步骤超时配置（分钟）

| 配置键 | 默认值 | 说明 | 建议范围 |
|--------|--------|------|----------|
| STEP_TIMEOUT_CODER | 60 | 编码步骤超时 | 30-120，视任务复杂度 |
| STEP_TIMEOUT_REVIEW | 30 | 评审步骤超时 | 15-60 |
| STEP_TIMEOUT_TEST | 45 | 测试步骤超时 | 30-90 |
| STEP_TIMEOUT_GIT | 15 | Git步骤超时 | 5-30 |

### 需求平台API配置

| 配置键 | 说明 |
|--------|------|
| REQUIREMENT_API_URL | 需求管理平台API地址 |
| REQUIREMENT_API_TOKEN | API认证令牌 |

用于自动获取待处理状态的需求号列表。

### 知识库路径配置

| 配置键 | 说明 |
|--------|------|
| KNOWLEDGE_BASE_PATH | 项目知识库目录路径 |

知识库目录应包含：
- tech_stack.md：技术栈说明
- build_commands.md：构建命令
- test_commands.md：测试命令
- 其他项目特定配置

## 配置文件示例

```env
# ========== 调度参数配置 ==========
MAX_CONCURRENT_TASKS=3
CHECK_INTERVAL_SECONDS=600
MAX_RETRY_COUNT=3
RETRY_DELAY_SECONDS=10

# ========== 步骤超时配置（分钟） ==========
STEP_TIMEOUT_CODER=60
STEP_TIMEOUT_REVIEW=30
STEP_TIMEOUT_TEST=45
STEP_TIMEOUT_GIT=15

# ========== 需求平台API配置（可选） ==========
REQUIREMENT_API_URL=https://your-requirement-platform/api
REQUIREMENT_API_TOKEN=your-token-here

# ========== 知识库路径 ==========
KNOWLEDGE_BASE_PATH=DOCS/项目知识库
```

> **注意**：子Agent无需配置，系统自动智能识别可用技能。

## 常见问题

### Q: 如何调整并发数？
A: 修改 MAX_CONCURRENT_TASKS 值。建议根据机器性能和任务复杂度调整，一般不超过5。

### Q: 步骤超时后怎么办？
A: 超时后会触发重试机制（最多MAX_RETRY_COUNT次），超过重试上限后停止流程，等待人工介入。

### Q: 如何添加新的开发技能？
A: 1. 创建对应的技能文件（SKILL.md）；2. 在 frontmatter 中添加合适的 tags 和 keywords；3. 系统会自动识别并纳入智能调度。

### Q: 没有匹配到技能怎么办？
A: 主Agent会自主决策执行相应操作，无需担心。这保证了即使缺少专用技能，流程也能继续。