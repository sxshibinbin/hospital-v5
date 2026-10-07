# ai-auto-dev 工作流程

## 流程总览

```
用户输入 "自动开发 123456"
  │
  ├─ Step 0: 前台执行 - 获取需求详情、匹配产品、确定仓库和技能路由
  │   ├─ Step 0.0: 前置分支检查（工作区是否干净）
  │   ├─ Step 0.1: 解析需求号、验证格式
  │   ├─ Step 0.2: 匹配产品（匹配失败则列出可选产品让用户选择）
  │   ├─ Step 0.3: 确定目标仓库和技能路由
  │   ├─ Step 0.5: 前置文档智能检查（DOCS→附件→ai-prd-auto自动补全）
  │   └─ Step 0.6: 验证子技能文件存在性（缺失则询问用户）
  │
  ├─ ↓ 委托子 Agent 在后台并行执行以下步骤
  │
  ├─ Step 1: 初始化仓库、创建隔离 worktree、复制前置文档
  │   ├─ 创建 worktree-{需求号} 目录
  │   ├─ 创建 feature/{需求号} 分支
  │   ├─ 复制 DOCS/{需求号}/ 到 worktree 内
  │   └─ 创建 sched_log.md 调度日志
  │
  ├─ Step 2: PM 分析需求，生成开发指令（dev-plan.md）
  │   ├─ 阅读需求设计文档
  │   ├─ 阅读架构设计文档
  │   ├─ 分析任务拆分清单
  │   └─ 生成开发计划指令
  │
  ├─ Step 3: 按技能路由自动编码
  │   ├─ Step 3.1: 后端编码（ai-backend-dev-pro 子Agent）
  │   │   ├─ 准入检查 → 获取任务 → 编码实现
  │   │   ├─ 验证测试 → 修复循环 → 更新状态
  │   │   ├─ Step 5.5: 更新TFS任务标签（新增AI-CODING）
  │   │   └─ 准出检查 → 静默返回
  │   │
  │   ├─ Step 3.2: 前端编码（ai-frontend-dev-pro 子Agent）
  │   │   ├─ 准入检查 → 获取任务 → 编码实现
  │   │   ├─ 验证测试 → 修复循环 → 更新状态
  │   │   └─ 准出检查 → 静默返回
  │   │
  │   └─ ⚠️ 子Agent强制调用，禁止自主执行
  │
  ├─ Step 4: 质量保障流程
  │   ├─ Step 4.1: 代码评审（ai-code-review-agent 子Agent）
  │   │   ├─ 四层规则体系审查
  │   │   ├─ 多技术栈统一审查
  │   │   ├─ 问题分级与阻断判断
  │   │   └─ 审查报告生成 → 静默返回
  │   │
  │   ├─ Step 4.2: 自动化测试（ai-automated-test-agent 子Agent）
  │   │   ├─ 前置产出物收集
  │   │   ├─ 测试用例设计（正常/异常/边界）
  │   │   ├─ 测试代码生成与执行
  │   │   └─ 测试报告生成 → 静默返回
  │   │
  │   └─ ⚠️ 子Agent强制调用，禁止自主执行
  │
  ├─ Step 5: Git 提交与 TFS 状态更新
  │   ├─ ai-git-push 子Agent执行
  │   ├─ Step 5.1: 准入检查（检查所有前置步骤状态）
  │   ├─ Step 5.2: 工作区检查（git status）
  │   ├─ Step 5.3: 自动提交代码（git add -A + commit）
  │   ├─ Step 5.4: 自动推送（git push origin feature/{需求号})
  │   ├─ Step 5.5: 更新子任务状态（TFS 子任务 → 已关闭）
  │   ├─ Step 5.6: 更新需求状态（需求 → 已解决）
  │   └─ ⚠️ Step 5.5/5.6 是 TFS 状态同步，禁止跳过
  │
  ├─ Step 6: 清理与验证
  │   ├─ Step 6.1: 清理前验证
  │   │   ├─ 验证 Git 提交状态
  │   │   ├─ 验证工作区状态
  │   │   └─ 更新 sched_log.md Step 6.1 状态
  │   │
  │   ├─ Step 6.2: 清理 Worktree
  │   │   ├─ git worktree remove worktree-{需求号}
  │   │   ├─ 验证清理结果
  │   │   └─ 更新 sched_log.md Step 6.2 状态
  │   │
  │   └─ 有下一需求号 → 回到 Step 1
  │   └─ 所有需求号处理完 → 进入 Step 7
  │
  ├─ Step 7: 生成报告与兜底操作
  │   ├─ Step 7.1: 更新调度日志最终状态
  │   │   ├─ 汇总执行结果
  │   │   ├─ 计算整体耗时
  │   │   ├─ 统计成功/失败/跳过步骤
  │   │   └─ 更新流程完成状态
  │   │
  │   ├─ Step 7.2: 生成执行汇总报告
  │   │   ├─ 各需求号完成状态
  │   │   ├─ 代码变更统计
  │   │   ├─ TFS 工作项关联
  │   │   └─ 生成汇总报告文件
  │   │
  │   ├─ Step 7.3: 兜底上传文档
  │   │   ├─ 检查是否需要上传文档到 TFS
  │   │   ├─ 上传审查报告、测试报告等
  │   │   └─ 记录上传结果
  │   │
  │   └─ Step 7.4: 更新 TFS 标签
  │       ├─ 为需求添加 'AI-DEV' 标签
  │       ├─ 标记需求已完成自动开发
  │       └─ 记录标签更新结果
  │
  └─ Step 8: 主 Agent 输出最终报告 + 通知
      ├─ ✅ 这是唯一允许输出总结的步骤
      ├─ 输出格式化执行汇总
      ├─ 列出各需求号完成状态
      ├─ 列出代码变更统计
      ├─ 列出 TFS 工作项链接
      ├─ 输出后续建议（如需合并分支）
      └─ 流程结束
```

---

## Phase 详解

### Phase 1: 前台初始化（Step 0）

**执行方式**：主 Agent 直接执行，不委托子 Agent

#### Step 0.0: 前置分支检查

```
检查当前工作区状态
  │
  ├─ git status --porcelain
  │
  ├─ 输出为空 → ✅ 工作区干净 → 进入 Step 0.1
  │
  └─ 输出不为空 → ⛔ 有未提交更改
      │
      ├─ AskUserQuestion 询问用户：
      │   ├─ 自动提交（推荐）
      │   ├─ 人工处理
      │   └─ 取消流程
      │
      ├─ 用户选择自动提交 → 调用 ai-git-push 子Agent
      │   └─ 提交完成 → 进入 Step 0.1
      │
      ├─ 用户选择人工处理 → 流程暂停
      │   └─ 等待用户处理后重新触发
      │
      └─ 用户选择取消 → 流程终止
```

#### Step 0.1: 解析需求号

```
解析输入参数 "自动开发 123456"
  │
  ├─ 提取需求号列表：[123456]
  │
  ├─ 支持格式：
  │   ├─ 单需求号：123456
  │   ├─ 多需求号：123456,123457,123458
  │   ├─ 范围格式：123456-123460
  │   └─ 关键词触发：ai-auto-dev、多需求并行开发
  │
  └─ 验证需求号格式有效性 → 进入 Step 0.2
```

#### Step 0.2: 匹配产品

```
根据需求号匹配产品线
  │
  ├─ 查询 TFS 工作项获取产品信息
  │   ├─ 调用 ai-tfs-integration 查询工作项详情
  │   └─ 从工作项字段获取产品/项目信息
  │
  ├─ 匹配结果：
  │   ├─ ✅ 匹配成功 → 确定产品 → 进入 Step 0.3
  │   │
  │   └─ ❌ 匹配失败 → AskUserQuestion
  │       ├─ 列出可选产品列表
  │       ├─ ICIS（重症监护信息系统）
  │       ├─ HIS（医院信息系统）
  │       ├─ EMR（电子病历系统）
  │       └─ 用户选择 → 确定产品 → 进入 Step 0.3
  │
  ├─ 如本地已有仓库：
  │   ├─ 自动检测现有 Git 仓库
  │   ├─ 自动注册为可用仓库
  │   └─ 直接使用现有仓库
```

#### Step 0.3: 确定仓库和技能路由

```
确定目标仓库和技能路由
  │
  ├─ 仓库确定：
  │   ├─ 产品匹配成功 → 使用对应仓库
  │   ├─ 本地已有仓库 → 自动检测并注册
  │   └─ 需新建仓库 → 提供克隆指令
  │
  ├─ 技能路由确定：
  │   ├─ 扫描 .claude/skills/ 目录
  │   ├─ 构建可用技能索引
  │   ├─ 确定技能调用顺序：
  │   │   ├─ ai-backend-dev-pro（后端编码）
  │   │   ├─ ai-frontend-dev-pro（前端编码）
  │   │   ├─ ai-code-review-agent（代码评审）
  │   │   ├─ ai-automated-test-agent（自动化测试）
  │   │   └─ ai-git-push（Git提交）
  │   │
  │   └─ 根据任务类型调整路由：
  │       ├─ 纯后端任务 → 跳过前端编码
  │       ├─ 纯前端任务 → 跳过后端编码
  │       └─ 混合任务 → 执行完整流程
  │
  └─ 进入 Step 0.5
```

#### Step 0.5: 前置文档智能检查

```
检查需求前置文档
  │
  ├─ Phase 1: DOCS 目录检查
  │   ├─ Glob DOCS/{需求号}/需求设计/requirement.md
  │   ├─ Glob DOCS/{需求号}/任务拆分/任务索引.md
  │   │
  │   ├─ 全部存在 → ✅ 前置文档完整 → 进入 Step 0.6
  │   └─ 部分缺失 → 进入 Phase 2
  │
  ├─ Phase 2: 需求附件检查
  │   ├─ 检查 ai-tfs-integration 技能可用性
  │   │
  │   ├─ 技能可用 → 调用子Agent查询 TFS 附件
  │   │   ├─ 有附件 → 复制到 DOCS 目录 → 进入 Step 0.6
  │   │   └─ 无附件 → 进入 Phase 3
  │   │
  │   └─ 技能不可用 → 进入 Phase 3
  │
  ├─ Phase 3: 自动补全（ai-prd-auto）
  │   ├─ 检查 ai-prd-auto 技能可用性
  │   │
  │   ├─ 技能可用 → 调用子Agent执行需求分析
  │   │   ├─ 步骤0-7：可行性验证→需求收集→需求分析→编写PRD→生成原型→任务拆分
  │   │   ├─ 产物验证 → ✅ 生成成功 → 进入 Step 0.6
  │   │   └─ 产物验证失败 → AskUserQuestion（重试/跳过/暂停）
  │   │
  │   └─ 技能不可用 → AskUserQuestion（跳过/暂停/取消）
  │
  └─ 进入 Step 0.6
```

#### Step 0.6: 验证子技能存在性

```
验证所有子技能文件存在
  │
  ├─ 必须验证的技能：
  │   ├─ ai-backend-dev-pro（后端编码）
  │   ├─ ai-frontend-dev-pro（前端编码）
  │   ├─ ai-code-review-agent（代码评审）
  │   ├─ ai-automated-test-agent（自动化测试）
  │   └─ ai-git-push（Git提交）
  │
  ├─ 验证方法：
  │   ├─ Glob .claude/skills/{技能名}/SKILL.md
  │   └─ 检查文件是否存在
  │
  ├─ 验证结果：
  │   ├─ ✅ 所有技能存在 → 进入 Step 1（委托子Agent）
  │   │
  │   └─ ❌ 有技能缺失 → AskUserQuestion（必须询问用户）
  │       ├─ 跳过该步骤 → 记录到调度日志 → 继续验证下一个
  │       ├─ 暂停流程 → 等待安装技能
  │       └─ 取消流程 → 流程终止
  │
  └─ ⛔ 禁止自主跳过，必须询问用户
```

---

### Phase 2: 后台执行（委托子 Agent）

**执行方式**：主 Agent 委托子 Agent 并行执行，子 Agent 静默返回

#### Step 1: 初始化仓库、创建隔离 worktree

```
创建隔离开发环境
  │
  ├─ 创建 Worktree
  │   ├─ git worktree add worktree-{需求号} -b feature/{需求号} --no-track
  │   ├─ ⛔ 禁止使用 EnterWorktree 工具（路径不正确）
  │   └─ 验证创建结果：git worktree list
  │
  ├─ 创建 DOCS 目录结构（在 worktree 内）
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/需求设计
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/架构设计
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/任务拆分
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/后端编码
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/前端编码
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/代码评审
  │   ├─ mkdir -p worktree-{需求号}/DOCS/{需求号}/自动化测试
  │   └─ mkdir -p worktree-{需求号}/DOCS/{需求号}/Git提交
  │
  ├─ 复制前置文档到 worktree
  │   ├─ cp -r DOCS/{需求号}/需求设计/* worktree-{需求号}/DOCS/{需求号}/需求设计/
  │   ├─ cp -r DOCS/{需求号}/架构设计/* worktree-{需求号}/DOCS/{需求号}/架构设计/
  │   └─ cp -r DOCS/{需求号}/任务拆分/* worktree-{需求号}/DOCS/{需求号}/任务拆分/
  │
  ├─ 创建调度日志
  │   └─ Write worktree-{需求号}/DOCS/{需求号}/sched_log.md
  │
  └─ 更新 sched_log.md Step 1 状态为 success → 进入 Step 2
```

#### Step 2: PM 分析需求，生成开发指令

```
需求分析生成开发计划
  │
  ├─ 阅读前置文档
  │   ├─ Read worktree-{需求号}/DOCS/{需求号}/需求设计/requirement.md
  │   ├─ Read worktree-{需求号}/DOCS/{需求号}/架构设计/module_design.md
  │   ├─ Read worktree-{需求号}/DOCS/{需求号}/任务拆分/任务索引.md
  │   └─ Read worktree-{需求号}/DOCS/{需求号}/任务拆分/任务{n}.md
  │
  ├─ 分析开发任务
  │   ├─ 确定任务类型（后端/前端/混合）
  │   ├─ 确定任务优先级和依赖关系
  │   ├─ 确定技术栈和框架版本
  │   └─ 确定测试覆盖要求
  │
  ├─ 生成开发指令文件
  │   ├─ Write worktree-{需求号}/DOCS/{需求号}/dev-plan.md
  │   ├─ 包含：
  │   │   ├─ 任务执行顺序
  │   │   ├─ 编码规范引用
  │   │   ├─ 技术栈说明
  │   │   ├─ API 接口规范
  │   │   ├─ 数据库变更脚本
  │   │   └─ 测试用例设计要求
  │   │
  │   └─ 更新 sched_log.md Step 2 状态为 success
  │
  └─ 进入 Step 3
```

#### Step 3: 按技能路由自动编码

**⚠️ 子 Agent 强制调用，禁止自主执行**

```
按任务类型自动编码
  │
  ├─ Step 3.1: 后端编码（ai-backend-dev-pro 子Agent）
  │   │
  │   ├─ Agent({
  │   │     description: "后端编码 - 需求号 {需求号}",
  │   │     prompt: "严格执行 ai-backend-dev-pro 技能文件定义的流程..."
  │   │   })
  │   │
  │   ├─ 子Agent执行流程：
  │   │   ├─ Step 0: 准入检查
  │   │   ├─ Step 1: 获取任务（阅读项目知识库）
  │   │   ├─ Step 2: 编码实现
  │   │   ├─ Step 3: 验证测试（编译+单元测试）
  │   │   ├─ Step 4: 修复循环（如需要）
  │   │   ├─ Step 5: 更新状态
  │   │   ├─ Step 5.5: 更新TFS任务标签（新增AI-CODING）✨
  │   │   └─ Step 6: 准出检查
  │   │
  │   ├─ ⛔ 禁止跳过任何步骤
  │   ├─ ⛔ 禁止自主简化流程
  │   └─ 静默返回，不输出状态报告
  │   │
  │   └─ 更新 sched_log.md Step 3.1 状态为 success
  │
  ├─ Step 3.2: 前端编码（ai-frontend-dev-pro 子Agent）
  │   │
  │   ├─ Agent({
  │   │     description: "前端编码 - 需求号 {需求号}",
  │   │     prompt: "严格执行 ai-frontend-dev-pro 技能文件定义的流程..."
  │   │   })
  │   │
  │   ├─ 子Agent执行流程：
  │   │   ├─ Step 0: 准入检查
  │   │   ├─ Step 1: 获取任务
  │   │   ├─ Step 2: 编码实现
  │   │   ├─ Step 3: 验证测试
  │   │   ├─ Step 4: 修复循环
  │   │   ├─ Step 5: 更新状态
  │   │   └─ Step 6: 准出检查
  │   │
  │   ├─ ⛔ 禁止跳过任何步骤
  │   └─ 静默返回
  │   │
  │   └─ 更新 sched_log.md Step 3.2 状态为 success
  │
  └─ 进入 Step 4
```

#### Step 4: 质量保障流程

**⚠️ 子 Agent 强制调用，禁止自主执行**

```
质量保障检查
  │
  ├─ Step 4.1: 代码评审（ai-code-review-agent 子Agent）
  │   │
  │   ├─ Agent({
  │   │     description: "代码评审 - 需求号 {需求号}",
  │   │     prompt: "严格执行 ai-code-review-agent 技能文件定义的流程..."
  │   │   })
  │   │
  │   ├─ 子Agent执行流程：
  │   │   ├─ Stage 1: 预处理（参数验证、TFS连接、分支差异）
  │   │   ├─ Stage 2: 规则加载（四层规则体系）
  │   │   ├─ Stage 3: 代码审查（多技术栈、四轮审查法）
  │   │   ├─ Stage 4: 结果聚合（问题去重、评分计算）
  │   │   └─ Stage 5: 输出交付（报告生成、阻断判断）
  │   │
  │   ├─ ⛔ 禁止跳过任何步骤
  │   └─ 静默返回
  │   │
  │   └─ 更新 sched_log.md Step 4.1 状态为 success
  │
  ├─ Step 4.2: 自动化测试（ai-automated-test-agent 子Agent）
  │   │
  │   ├─ Agent({
  │   │     description: "自动化测试 - 需求号 {需求号}",
  │   │     prompt: "严格执行 ai-automated-test-agent 技能文件定义的流程..."
  │   │   })
  │   │
  │   ├─ 子Agent执行流程：
  │   │   ├─ Stage 1: 前置产出物收集
  │   │   ├─ Stage 2: 测试用例设计（正常/异常/边界）
  │   │   ├─ Stage 3: 测试代码生成
  │   │   ├─ Stage 4: 测试执行（单元测试、接口测试）
  │   │   └─ Stage 5: 报告生成与交付
  │   │
  │   ├─ ⛔ 禁止跳过任何步骤
  │   └─ 静默返回
  │   │
  │   └─ 更新 sched_log.md Step 4.2 状态为 success
  │
  └─ 进入 Step 5
```

#### Step 5: Git 提交与 TFS 状态更新

**⚠️ 子 Agent 强制调用，禁止自主执行**
**⚠️ Step 5.5/5.6 是 TFS 状态同步，禁止跳过**

```
Git 提交与 TFS 状态同步
  │
  ├─ Agent({
  │     description: "Git提交 - 需求号 {需求号}",
  │     prompt: "严格执行 ai-git-push 技能文件定义的流程，包含 Step 7/8 TFS 状态更新..."
  │   })
  │
  ├─ 子Agent执行流程：
  │   ├─ Step 0: 项目检测与模式判断
  │   ├─ Step 1: 准入检查（检测 sched_log.md 所有步骤状态）
  │   ├─ Step 2: 工作区检查
  │   ├─ Step 3: 自动提交代码（git add -A + commit）
  │   ├─ Step 4: 更新文档
  │   ├─ Step 5: 准出检查
  │   ├─ Step 6: 自动推送（git push origin feature/{需求号})
  │   │
  │   ├─ ⚠️ Step 7: 更新子任务状态（推送成功后必须执行）
  │   │   ├─ 获取 TFS 子任务列表
  │   │   ├─ 将所有子任务状态更新为"已关闭"
  │   │   └─ 记录更新结果
  │   │
  │   ├─ ⚠️ Step 8: 更新需求状态（所有子任务已关闭后必须执行）
  │   │   ├─ 将需求状态更新为"已解决"
  │   │   └─ 记录更新结果
  │   │
  │   ├─ ⛔ 禁止跳过 Step 7 和 Step 8
  │   ├─ ⛔ 禁止跳过任何步骤
  │   └─ 静默返回
  │
  └─ 更新 sched_log.md Step 5 状态为 success → 进入 Step 6
```

#### Step 6: 清理与验证

```
清理开发环境
  │
  ├─ Step 6.1: 清理前验证
  │   ├─ Read sched_log.md 检查 Step 5 状态
  │   ├─ git -C worktree-{需求号} status --porcelain
  │   ├─ 验证 Git 提交状态
  │   ├─ 验证工作区状态
  │   └─ Edit sched_log.md 更新 Step 6.1 状态
  │
  ├─ Step 6.2: 清理 Worktree
  │   ├─ git worktree remove worktree-{需求号} --force
  │   ├─ git worktree list 验证清理结果
  │   └─ Edit sched_log.md 更新 Step 6.2 状态
  │
  ├─ 有下一需求号 → 回到 Step 1
  └─ 所有需求号处理完 → 进入 Step 7
```

---

### Phase 3: 完成输出（Step 7-8）

**执行方式**：主 Agent 直接执行，最后输出报告

#### Step 7: 生成报告与兜底操作

```
生成执行报告
  │
  ├─ Step 7.1: 更新调度日志最终状态
  │   ├─ Read sched_log.md 获取启动时间和各步骤状态
  │   ├─ 计算统计数据：
  │   │   ├─ 整体耗时
  │   │   ├─ 成功步骤数
  │   │   ├─ 失败步骤数
  │   │   └─ 跳过步骤数
  │   │
  │   └─ Edit sched_log.md 更新流程完成状态部分
  │
  ├─ Step 7.2: 生成执行汇总报告
  │   ├─ 收集各需求号完成状态
  │   ├─ 统计代码变更（git diff --stat）
  │   ├─ 收集 TFS 工作项关联信息
  │   └─ Write 汇总报告文件
  │
  ├─ Step 7.3: 兜底上传文档
  │   ├─ 检查是否需要上传文档到 TFS
  │   ├─ 上传审查报告、测试报告等（如未上传）
  │   └─ 记录上传结果
  │
  ├─ Step 7.4: 更新 TFS 标签
  │   ├─ 调用 ai-tfs-integration 为需求添加 'AI-DEV' 标签
  │   ├─ 标记需求已完成自动开发流程
  │   └─ 记录标签更新结果
  │
  └─ 进入 Step 8
```

#### Step 8: 主 Agent 输出最终报告 + 通知

**✅ 这是唯一允许输出总结的步骤**

```
输出最终报告
  │
  ├─ 输出格式化执行汇总：
  │   │
  │   ├─ ┌────────────────────────────────────────┐
  │   │   │  ✅ ai-auto-dev 执行完成              │
  │   │   ├────────────────────────────────────────┤
  │   │   │  需求号：123456                        │
  │   │   │  产品线：ICIS                          │
  │   │   │  分支：feature/123456                  │
  │   │   │                                        │
  │   │   │  执行结果：                            │
  │   │   │  ├─ 后端编码：✅ 成功                  │
  │   │   │  ├─ 前端编码：✅ 成功                  │
  │   │   │  ├─ 代码评审：✅ 通过                  │
  │   │   │  ├─ 自动化测试：✅ 通过                │
  │   │   │  ├─ Git 提交：✅ 成功                  │
  │   │   │  ├─ TFS 状态更新：✅ 完成              │
  │   │   │  │                                        │
  │   │   │  代码变更统计：                        │
  │   │   │  ├─ 新增文件：12 个                    │
  │   │   │  ├─ 修改文件：8 个                     │
  │   │   │  ├─ 删除文件：0 个                     │
  │   │   │  ├─ 总变更行数：+450 -120              │
  │   │   │  │                                        │
  │   │   │  TFS 工作项：                          │
  │   │   │  ├─ 需求：123456 → 已解决              │
  │   │   │  ├─ 子任务：123456-1 → 已关闭          │
  │   │   │  ├─ 子任务：123456-2 → 已关闭          │
  │   │   │  │                                        │
  │   │   │  整体耗时：45 分钟                     │
  │   │   │  Token 消耗：125,000                   │
  │   │   └────────────────────────────────────────┘
  │   │
  │   ├─ 输出 TFS 工作项链接
  │   │   ├─ http://tfs2018-web.winning.com.cn:8080/tfs/WN_HIS/_workitems?id=123456
  │   │
  │   ├─ 输出后续建议：
  │   │   ├─ 如需合并分支：使用 ai-git-merge 技能
  │   │   ├─ 如需创建 PR：使用 gh pr create 命令
  │   │   ├─ 如发现 Bug：请新开对话处理
  │   │
  │   └─ 流程结束
```

---

## ⚠️ 核心约束（必须遵守）

### 1. 禁止流程简化

```
┌─────────────────────────────────────────────────────────────────┐
│  ⛔ 禁止流程简化原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 禁止因"简单任务"判断而简化流程                                 │
│  2. 禁止直接执行 git 命令跳过 ai-git-push 技能                     │
│  3. 禁止跳过任何子Agent调用                                        │
│  4. 禁止跳过 Step 5.5/5.6（TFS 状态更新）                         │
│  5. 禁止自主判断"任务不需要完整流程"                               │
│  6. 所有任务，无论复杂度，都必须完整执行所有步骤                    │
└─────────────────────────────────────────────────────────────────┘
```

### 2. 技能缺失必须询问用户

```
┌─────────────────────────────────────────────────────────────────┐
│  ⛔ 技能缺失处理原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 检测到技能文件不存在 → 禁止自主跳过                            │
│  2. 检测到技能文件不存在 → 必须使用 AskUserQuestion 询问用户       │
│  3. 用户选择"跳过" → 才能跳过该步骤                               │
│  4. 用户选择"暂停" → 流程暂停，等待安装技能                       │
│  5. 用户选择"取消" → 流程终止                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 3. 子Agent强制调用

```
┌─────────────────────────────────────────────────────────────────┐
│  子Agent强制执行原则                                              │
├─────────────────────────────────────────────────────────────────┤
│  1. 每个步骤必须通过 Agent 工具调用子Agent                         │
│  2. 子Agent prompt 必须明确指定技能文件路径                        │
│  3. 子Agent 必须严格执行技能定义的流程（禁止自主判断）              │
│  4. 禁止触发兜底逻辑（禁止直接用大模型处理）                        │
│  5. 子Agent执行完毕后静默返回，主调度继续下一步                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 子技能映射表

| 步骤 | 子技能名称 | 技能文件路径 | 执行方式 |
|------|------------|--------------|----------|
| Step 0.5 | ai-tfs-integration | .claude/skills/ai-tfs-integration/SKILL.md | 子Agent（Phase 2） |
| Step 0.5 | ai-prd-auto | .claude/skills/ai-prd-auto/SKILL.md | 子Agent（Phase 3） |
| Step 3.1 | ai-backend-dev-pro | .claude/skills/ai-backend-dev-pro/SKILL.md | 子Agent强制调用 |
| Step 3.2 | ai-frontend-dev-pro | .claude/skills/ai-frontend-dev-pro/SKILL.md | 子Agent强制调用 |
| Step 4.1 | ai-code-review-agent | .claude/skills/ai-code-review-agent/SKILL.md | 子Agent强制调用 |
| Step 4.2 | ai-automated-test-agent | .claude/skills/ai-automated-test-agent/SKILL.md | 子Agent强制调用 |
| Step 5 | ai-git-push | .claude/skills/ai-git-push/SKILL.md | 子Agent强制调用 |

---

## 文档路径约定

| 文档类型 | 路径格式 |
|----------|----------|
| 调度日志 | worktree-{需求号}/DOCS/{需求号}/sched_log.md |
| 开发计划 | worktree-{需求号}/DOCS/{需求号}/dev-plan.md |
| 后端执行进度 | worktree-{需求号}/DOCS/{需求号}/后端编码/exec_prog.md |
| 前端执行进度 | worktree-{需求号}/DOCS/{需求号}/前端编码/exec_prog.md |
| 代码评审报告 | worktree-{需求号}/DOCS/{需求号}/代码评审/审查报告_{日期}.md |
| 测试报告 | worktree-{需求号}/DOCS/{需求号}/自动化测试/测试报告_{日期}.md |
| Git提交记录 | worktree-{需求号}/DOCS/{需求号}/Git提交/exec_prog.md |

---

## 安全执行命令规范

```bash
# ✅ 正确 - 使用 git -C 参数
git -C worktree-{需求号} status --porcelain
git -C worktree-{需求号} log --oneline -3

# ✅ 正确 - 使用 -f 参数编译
mvn compile -f worktree-{需求号}/icis/pom.xml -DskipTests

# ✅ 正确 - 使用绝对路径读取文件
Read worktree-{需求号}/icis/icis-biz-main/src/main/java/...

# ⛔ 禁止 - 组合命令（安全层拦截）
cd worktree-{需求号} && git status
cd worktree-{需求号} && mvn compile

# ⛔ 禁止 - EnterWorktree 工具
# 会创建 .claude/worktrees/ 路径，与规范不一致
```