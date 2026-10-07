# exec_proc.md 模板

> 位置：`DOCS/{需求号}/后端编码/exec_proc.md`

```markdown
# 后端开发过程记录

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
| src/.../controller/XxxController.java | 新增 | 控制器接口 |
| src/.../service/XxxService.java | 新增 | 服务接口 |
| src/.../service/impl/XxxServiceImpl.java | 新增 | 服务实现 |
| src/.../repository/XxxRepository.java | 新增 | 数据访问 |
| src/.../entity/XxxEntity.java | 修改 | 新增字段 |

### 验证结果

- [x] 编译通过
- [x] 测试通过
- [x] 无 TODO
- [x] 无漏改
- [x] 打包成功
- [x] 启动验证通过

### Step 5.5: 更新TFS任务标签

**任务类型判定**: 后端任务
**TFS工作项ID**: {TFS_ID}
**添加标签**: AI-CODING
**添加时间**: {yyyy-mm-dd HH:mm}
**添加结果**: ✅ 成功

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
**TFS标签更新**: {成功数量}/{后端任务数量}
```