# 反馈机制规范

## 反馈方式

本 Skill 由总调度技能触发，采用双通道反馈机制：

1. **更新索引文件**：每个步骤完成后，更新 `DOCS/{需求号}/任务拆分/任务索引.md` 中的进度状态
2. **主动反馈输出**：每个步骤完成后，输出标准化 `<FEEDBACK>` JSON 格式

## 标准化反馈输出格式

**每个步骤完成后，必须输出以下格式的反馈信息**：

```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "{需求号}",
  "step": "{步骤编号}",
  "stepName": "{步骤名称}",
  "status": "{步骤状态}",
  "currentTask": {
    "id": "{任务编号}",
    "name": "{任务名称}",
    "status": "{任务状态}"
  },
  "progress": {
    "totalTasks": "{任务总数}",
    "completedTasks": "{已完成数}",
    "inProgressTasks": "{开发中数}",
    "pendingTasks": "{待开发数}"
  },
  "validation": {
    "compile": "{通过/失败/未执行}",
    "test": "{通过/失败/未执行}",
    "todoCheck": "{无遗留/有遗留/未执行}",
    "missingCheck": "{无遗漏/有遗漏/未执行}"
  },
  "timestamp": "{yyyy-mm-dd HH:mm:ss}",
  "message": "{简短描述}"
}
</FEEDBACK>
```

## 字段说明

| 字段 | 类型 | 说明 | 取值范围 |
|------|------|------|----------|
| skill | string | 技能标识 | 固定值 "ai-backend-dev-pro" |
| demandId | string | 需求号 | 从用户输入或目录推断 |
| step | string | 步骤编号 | "0" - "6" |
| stepName | string | 步骤名称 | 准入检查/获取任务/编码实现/验证测试/修复循环/更新状态/准出检查 |
| status | string | 步骤状态 | completed/failed/passed/repairing |
| currentTask | object | 当前任务 | null 或任务对象 |
| progress | object | 进度统计 | 各状态任务数量 |
| validation | object | 验证状态 | 编译、测试、TODO、漏改检查结果 |
| timestamp | string | 时间戳 | yyyy-mm-dd HH:mm:ss 格式 |
| message | string | 描述信息 | 简短的状态描述 |

## 反馈触发时机

| 步骤 | 触发时机 | status 取值 |
|------|----------|-------------|
| Step 0 | 准入检查完成 | `completed` 或 `failed` |
| Step 1 | 任务获取完成 | `completed` |
| Step 2 | 编码实现完成 | `completed` |
| Step 3 | 验证测试完成 | `passed` 或 `failed` |
| Step 4 | 修复完成（每次修复后） | `repairing` 或 `completed` |
| Step 5 | 状态更新完成 | `completed` |
| Step 6 | 准出检查完成 | `completed` 或 `failed` |

## 索引文件更新内容

每个步骤完成后，更新 `任务索引.md` 的以下字段：
- 当前步骤信息（当前步骤、步骤名称）
- 当前任务状态
- 进度统计（总数、已完成、开发中、待开发）
- 验证状态（编译、测试、TODO检查、漏改检查）
- 最近更新时间

## 反馈示例

### 准入检查通过
```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "1506090",
  "step": "0",
  "stepName": "准入检查",
  "status": "completed",
  "currentTask": null,
  "progress": {
    "totalTasks": "5",
    "completedTasks": "0",
    "inProgressTasks": "0",
    "pendingTasks": "5"
  },
  "validation": {
    "compile": "未执行",
    "test": "未执行",
    "todoCheck": "未执行",
    "missingCheck": "未执行"
  },
  "timestamp": "2026-05-14 14:00:00",
  "message": "准入检查通过，准备开始开发"
}
</FEEDBACK>
```

### 任务获取完成
```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "1506090",
  "step": "1",
  "stepName": "获取任务",
  "status": "completed",
  "currentTask": {
    "id": "任务1",
    "name": "新增用户查询接口",
    "status": "开发中"
  },
  "progress": {
    "totalTasks": "5",
    "completedTasks": "0",
    "inProgressTasks": "1",
    "pendingTasks": "4"
  },
  "validation": {
    "compile": "未执行",
    "test": "未执行",
    "todoCheck": "未执行",
    "missingCheck": "未执行"
  },
  "timestamp": "2026-05-14 14:05:00",
  "message": "项目知识库已理解，已获取任务1，开始编码实现"
}
</FEEDBACK>
```

### 验证测试失败
```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "1506090",
  "step": "3",
  "stepName": "验证测试",
  "status": "failed",
  "currentTask": {
    "id": "任务1",
    "name": "新增用户查询接口",
    "status": "开发中"
  },
  "progress": {
    "totalTasks": "5",
    "completedTasks": "0",
    "inProgressTasks": "1",
    "pendingTasks": "4"
  },
  "validation": {
    "compile": "失败",
    "test": "未执行",
    "todoCheck": "有遗留",
    "missingCheck": "无遗漏"
  },
  "timestamp": "2026-05-14 14:30:00",
  "message": "编译失败：3个错误，TODO遗留：2处"
}
</FEEDBACK>
```

### 准出检查通过
```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "1506090",
  "step": "6",
  "stepName": "准出检查",
  "status": "completed",
  "currentTask": null,
  "progress": {
    "totalTasks": "5",
    "completedTasks": "5",
    "inProgressTasks": "0",
    "pendingTasks": "0"
  },
  "validation": {
    "compile": "通过",
    "test": "通过",
    "todoCheck": "无遗留",
    "missingCheck": "无遗漏"
  },
  "timestamp": "2026-05-14 16:00:00",
  "message": "所有任务已完成，准出检查通过，后端开发结束"
}
</FEEDBACK>
```