# ai-frontend-dev-pro

卫宁健康多前端技术栈自适应编码执行 Agent Skill。

## 功能特性

- **技术栈自适应**：自动识别 Vue 2/3 + Spark、RDF、HTML 等技术栈
- **需求驱动**：从 TFS 工作项或 PRD 文档获取需求
- **知识先行**：编码前先阅读项目知识库理解技术规范
- **循环验证**：代码生成后自动验证，失败自动修复
- **进度反馈**：每个步骤完成后主动输出标准化反馈

## 触发关键词

- "前端开发" + 数字
- "前端开发需求" + 数字
- "实现前端功能"
- "开发页面" / "写组件"
- Vue2 迁移 Vue3
- "快开框架" + 开发/实现
- "RDF开发" / "pageCode"

## 目录结构

```
ai-frontend-dev-pro/
├── SKILL.md                    # 技能主文件（精简版）
├── README.md                   # 说明文件
├── evals/                      # 技能评测数据
│   └── evals.json
├── references/                 # 参考文档
│   ├── workflow-guide.md       # 详细执行步骤
│   ├── feedback-spec.md        # 反馈机制规范
│   ├── tech-standards.md       # 技术栈规范
│   ├── spark-api.md            # Spark框架API
│   ├── win-design-components.md # WinDesign组件库
│   ├── form-patterns.md        # 表单高级模式
│   ├── table-patterns.md       # 表格高级模式
│   ├── select-patterns.md      # 选择器高级模式
│   ├── page-patterns.md        # 页面级模式
│   ├── rdf-development.md      # 快开框架RDF开发
│   └── vue3-migration.md       # Vue2到Vue3迁移
└── templates/                  # 模板文件
    ├── exec_proc-template.md   # 过程记录模板
    └── task-index-template.md  # 任务索引模板
```

## 使用方式

触发技能后，按照 Step 0-6 的流程执行开发任务。

详细步骤请参考 [references/workflow-guide.md](references/workflow-guide.md)。

## 技术栈支持

| 技术栈 | 框架/库 | 组件库 |
|--------|---------|--------|
| Vue 2 + Spark | Vue 2.6+ | win-design@^2.6 |
| Vue 3 + Spark | Vue 3.3+ | win-design-next |
| HTML 静态原型 | HTML5 + CSS3 | WinDesign CSS |
| 快开框架 RDF | TypeScript + XML | pango-framework |
| TypeScript 纯模块 | TypeScript 5.0+ | - |

## 反馈机制

每个步骤完成后输出标准化 `<FEEDBACK>` JSON 格式，供总调度技能追踪进度。

详细规范请参考 [references/feedback-spec.md](references/feedback-spec.md)。

## 版本历史

## 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| v1.2.1 | 2026-05-29 | 新增 Step 5.5 更新TFS任务标签逻辑：通过任务名称判断前端任务，新增'AI-CODING'标签 |
| v1.1.0 | 2026-05-27 | 新增 Step 3.5 启动验证环节，包含开发服务器启动、页面白屏检测、路由检查 |
| v1.0.0 | 2026-05-19 | 初始提交 |