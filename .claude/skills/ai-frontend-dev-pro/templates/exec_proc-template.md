# exec_proc.md 模板

> 位置：`DOCS/{需求号}/前端编码/exec_proc.md`

```markdown
# 前端开发过程记录

## 基本信息

| 项目 | 内容 |
|------|------|
| **需求号** | {需求号} |
| **开始时间** | {yyyy-mm-dd HH:mm} |
| **分支** | feature/{需求号} |
| **Worktree** | worktree-{需求号} |

---

## 任务{n} - {任务名称}

**状态**: 已完成
**完成时间**: {yyyy-mm-dd HH:mm}

### 修改文件清单

| 文件路径 | 操作 | 说明 |
|----------|------|------|
| src/views/UserQuery/index.vue | 新增 | 用户查询页面入口 |
| src/views/UserQuery/components/QueryForm.vue | 新增 | 查询表单组件 |
| src/views/UserQuery/components/ResultTable.vue | 新增 | 结果表格组件 |
| src/views/UserQuery/apis/user.ts | 修改 | 用户查询接口 |
| src/views/UserQuery/types/user.ts | 修改 | 类型定义 |

### 验证结果

- [x] 类型检查通过
- [x] Lint 检查通过
- [x] 编译通过
- [x] 测试通过
- [x] 无 TODO
- [x] 无漏改

---

## 任务{n+1} - {任务名称}

**状态**: 开发中
**开始时间**: {yyyy-mm-dd HH:mm}

### 问题修复记录

| 次数 | 问题 | 修复内容 | 时间 |
|------|------|----------|------|
| 1 | 编译失败：导入缺失 | 添加 import 语句 | {HH:mm} |
| 2 | 测试失败：数据缺失 | 补充测试数据 | {HH:mm} |

---

## 开发总结

**完成时间**: {yyyy-mm-dd HH:mm}
**总任务数**: {数量}
**完成任务数**: {数量}
**总修改文件数**: {数量}
**修复次数**: {数量}
```