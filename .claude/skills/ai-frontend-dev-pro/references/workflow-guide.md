# 执行步骤详细指南
## Step 0: 准入检查

**目标**: 确认可以进入开发流程

**准入条件**:
1. 任务拆分目录 `DOCS/{需求号}/任务拆分/` 下有待开发的前端任务
2. Git 分支和 Worktree 配置正确

**操作流程**:

1. **识别需求号**：
   - 从用户输入提取需求号（如 "开发需求 1506090" → 需求号 = 1506090）
   - 或从当前 Worktree/分支推断

2. **检查任务拆分目录**：
   ```bash
   ls DOCS/{需求号}/任务拆分/
   ```
   读取 `任务索引.md`，确认有状态为「待开发」或「开发中」的任务。

3. **检查 Git 分支**：
   ```bash
   git branch --show-current
   git worktree list
   ```

   - 当前分支应为 `feature/{需求号}`，如不正确则创建：
     ```bash
     git checkout -b feature/{需求号}
     ```

   - Worktree 应为 `worktree-{需求号}`，如不正确则创建：
     ```bash
     git worktree add worktree-{需求号} feature/{需求号}
     ```

4. **输出准入确认**：
   ```
   ✅ 准入检查通过:
   - 需求号: {需求号}
   - 分支: feature/{需求号} ✓
   - Worktree: worktree-{需求号} ✓
   - 待开发任务数: {数量}
   ```

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "0",
     "stepName": "准入检查",
     "status": "completed",
     "currentTask": null,
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "未执行",
       "test": "未执行",
       "todoCheck": "未执行",
       "missingCheck": "未执行"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "准入检查通过，准备开始开发"
   }
   </FEEDBACK>
   ```

---

## Step 1: 获取任务

**目标**: 先阅读项目知识库理解项目背景，再获取待开发任务

**重要原则**: 编码前必须先理解项目整体知识，确保代码符合项目规范和架构设计

**操作流程**:

1. **阅读项目知识库**（必须首先执行）：

   **目的**: 深入理解项目整体架构、编码规范、业务领域

   ```bash
   # 列出项目知识库目录
   ls DOCS/项目知识库/

   # 逐一阅读项目知识文档
   cat DOCS/项目知识库/编码规范.md
   cat DOCS/项目知识库/技术栈说明.md
   cat DOCS/项目知识库/架构设计.md
   cat DOCS/项目知识库/业务领域.md
   cat DOCS/项目知识库/测试配置.md
   ```

   **阅读重点**:
   - **编码规范**: 命名规范、包结构规范、注释规范、代码风格
   - **技术栈**: Vue版本、TypeScript版本、框架组件
   - **架构设计**: 分层架构、模块划分、接口设计原则
   - **业务领域**: 核心业务概念、领域模型、业务规则
   - **测试配置**: 测试命令、测试规范、覆盖率要求

   **理解确认**:
   ```
   📚 项目知识已理解:
   - 编码规范: {核心规范要点}
   - 技术栈: {主要技术栈}
   - 架构设计: {分层架构说明}
   - 业务领域: {核心业务概念}
   - 测试配置: {测试命令}
   ```

2. **读取任务索引**：
   ```bash
   cat DOCS/{需求号}/任务拆分/任务索引.md
   ```
   找到下一个待开发任务。

3. **读取具体任务文件**：
   ```bash
   cat DOCS/{需求号}/任务拆分/任务{n}.md
   ```
   提取任务详情：任务名称、描述、涉及文件、接口设计、技术要求。

4. **读取需求知识库**（补充阅读）：
   ```bash
   ls DOCS/{需求号}/知识库/
   cat DOCS/{需求号}/知识库/*.md
   ```

5. **更新任务状态**：
   将任务状态从「待开发」改为「开发中」，同步更新任务索引。

6. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "1",
     "stepName": "获取任务",
     "status": "completed",
     "currentTask": {
       "id": "任务{n}",
       "name": "{任务名称}",
       "status": "开发中"
     },
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "未执行",
       "test": "未执行",
       "todoCheck": "未执行",
       "missingCheck": "未执行"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "项目知识库已理解，已获取任务{n}，开始编码实现"
   }
   </FEEDBACK>
   ```

---

## Step 2: 编码实现

**目标**：按任务要求实现代码，遵循知识库规范

**实现原则**:
- **规范优先**: 严格遵循项目知识库中的编码规范
- **有序执行** - 按计划步骤逐一完成
- **注释适度**: 只在必要时添加注释
- **检查点验证** - 每个任务完成后有验证
- **进度跟踪** - 清晰的完成状态
- **问题处理** - 遇到阻塞时的处理策略

**实现顺序**（由内向外）：
1. **types/** - 类型定义
2. **apis/** - API 接口
3. **composables/** - 组合式函数
4. **components/** - 组件实现
5. **stores/** - 状态管理
6. **index.vue** - 页面集成

**操作流程**:

1. **分析任务涉及的文件和层级**

2. **按分层顺序实现代码**:
   - 先读取现有相关文件，理解现有结构
   - 新增/修改代码，确保与现有代码风格一致
   - 遵循知识库中的命名规范、包结构规范

3. **关键检查点**:
   - [ ] 是否遵循项目知识库编码规范
   - [ ] 是否添加了必要的异常处理
   - [ ] 是否遵循接口设计规范

4. **规范约束**:

### Vue 3 + Spark 组件模板

```vue
<template>
  <div class="component-name">
    <!-- 使用 win-design 组件 -->
    <w-button type="primary">{{ $t('common.save') }}</w-button>
  </div>
</template>

<script setup lang="ts">
// 1. 从 spark 导入（禁止从 vue/vue-router 等原始库导入）
import { ref, computed, onMounted } from 'spark';
import { request, t, useI18n } from 'spark';

// 2. Props 定义（使用 TypeScript 接口）
interface Props {
  title: string;
  count?: number;
}
const props = withDefaults(defineProps<Props>(), {
  count: 0
});

// 3. Emits 定义
const emits = defineEmits<{
  change: [value: number];
}>();

// 4. 响应式状态
const loading = ref(false);
const dataList = ref<DataType[]>([]);

// 5. 计算属性
const filteredList = computed(() => {
  return dataList.value.filter(item => item.active);
});

// 6. 方法
const handleSubmit = () => {
  emits('change', props.count + 1);
};

// 7. 生命周期
onMounted(() => {
  fetchData();
});
</script>

<style scoped>
.component-name {
  padding: 16px;
}
</style>
```

### 强制规则

| 规则 | 说明 |
|------|------|
| ✅ 必须使用 `<script setup lang="ts">` | 禁止 Options API |
| ✅ 必须从 `spark` 导入 | 禁止从 `vue`/`vue-router` 导入 |
| ✅ 必须使用 TypeScript | 禁止 `any` 类型 |
| ✅ 必须使用 win-design | 组件标签: `<w-*>` |
| ✅ 必须使用 i18n | 禁止硬编码文案 |
| ✅ 模块内引用用相对路径 | 禁止 `@/views/` 跨模块 |

### 从 spark 导入的 API

```typescript
// 响应式
import { ref, reactive, computed, watch, watchEffect } from 'spark';

// 路由
import { useRouter, useRoute } from 'spark';

// 状态管理
import { defineStore, storeToRefs } from 'spark';

// HTTP 请求
import { request } from 'spark';

// 工具函数
import { utils } from 'spark';

// 国际化
import { t, useI18n } from 'spark';

// 微前端/事件
import { micro, useEventBus } from 'spark';
```

### win-design 组件使用

```vue
<template>
  <!-- ✅ 正确：使用 win-design 组件 -->
  <w-button type="primary">提交</w-button>
  <w-input v-model="value" placeholder="请输入" />
  <w-table :data="tableData" />
  <w-form :model="formData" />

  <!-- ❌ 错误：使用其他 UI 库 -->
  <el-button>提交</el-button>
  <a-input v-model:value="value" />

  <!-- ❌ 错误：大写标签 -->
  <W-Button>提交</W-Button>
</template>

<script setup lang="ts">
// ✅ 无需导入，开箱即用
// ❌ 禁止手动导入 win-design 组件
</script>
```

### 多语言处理

```vue
<template>
  <!-- ✅ 模板中使用 $t -->
  <div>{{ $t('common.save') }}</div>
  <w-button>{{ $t('user.create') }}</w-button>

  <!-- ❌ 硬编码 -->
  <div>保存</div>
</template>

<script setup lang="ts">
import { t } from 'spark';

// ✅ Script 中使用 t
const message = t('common.success');
const title = t('user.listTitle');

// ❌ 硬编码
const message = '操作成功';
</script>
```

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "2",
     "stepName": "编码实现",
     "status": "completed",
     "currentTask": {
       "id": "任务{n}",
       "name": "{任务名称}",
       "status": "开发中"
     },
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "未执行",
       "test": "未执行",
       "todoCheck": "未执行",
       "missingCheck": "未执行"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "任务{n}编码完成，准备验证测试"
   }
   </FEEDBACK>
   ```

---

## Step 3: 验证测试

**目标**: 确保代码编译通过、测试通过、无遗漏

**操作**:
1. 运行类型检查: `npm run type-check`
2. 运行 lint: `npm run lint`
3. 运行测试（如果有）: `npm run test`
4. 如果失败，分析错误并修复

**验证命令**:

```bash
# 类型检查
npm run type-check

# Lint 检查
npm run lint

# 单元测试
npm run test

# 构建检查
npm run build
```

**硬编码检查**:

```bash
# 检查是否有硬编码文案（中文）
grep -r "[\u4e00-\u9fa5]" --include="*.vue" --include="*.ts" src/views/
```

**验证结果处理**:

| 检查项 | 结果 | 处理 |
|--------|------|------|
| 编译 | 失败 | 进入 Step 4 修复循环 |
| 测试 | 失败 | 进入 Step 4 修复循环 |
| TODO | 存在 | 进入 Step 4 修复循环 |
| 漏改 | 存在 | 进入 Step 4 修复循环 |
| 全部通过 | - | 进入 Step 3.5 启动验证 |

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "3",
     "stepName": "验证测试",
     "status": "{passed/failed}",
     "currentTask": {
       "id": "任务{n}",
       "name": "{任务名称}",
       "status": "开发中"
     },
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "{通过/失败}",
       "test": "{通过/失败}",
       "todoCheck": "{无遗留/有遗留}",
       "missingCheck": "{无遗漏/有遗漏}"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "{验证结果描述}"
   }
   </FEEDBACK>
   ```

---

## Step 3.5: 启动验证（新增）

**目标**: 验证前端页面能够正常启动和渲染，检测白屏问题

**⚠️ 重要说明**: 这是运行时验证，在静态验证通过后执行，确保前端能实际运行。

**验证项目**:

### 1. 启动开发服务器（后台启动）

启动前端开发服务器：

```bash
# 后台启动开发服务器
npm run serve --prefix worktree-{需求号}/icis/icis-ui > worktree-{需求号}/frontend.log 2>&1 &
echo $! > worktree-{需求号}/frontend.pid

# 等待服务启动（最多30秒）
for i in {1..30}; do
  if grep -q "Local:.*http://localhost" worktree-{需求号}/frontend.log 2>/dev/null; then
    echo "前端服务启动成功"
    # 提取端口
    PORT=$(grep "Local:" worktree-{需求号}/frontend.log | grep -oP '\d{4,5}' | head -1)
    break
  fi
  sleep 1
done
```

**验证结果处理**:
| 结果 | 处理 |
|------|------|
| 启动成功（"Local:"地址出现） | 继续 Step 3.5.2 页面响应检查 |
| 启动失败 | 检查 frontend.log，进入 Step 4 修复循环 |
| 启动超时（30秒无响应） | 检查依赖安装、配置错误 |

### 2. 页面响应检查

验证前端页面能正常响应：

```bash
# 提取端口（默认9589）
PORT=${PORT:-9589}

# 检查页面响应
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/

# 或检查首页内容
curl -s http://localhost:$PORT/ | head -50
```

**HTTP状态码处理**:

| HTTP状态码 | 含义 | 验证结果 |
|------------|------|----------|
| **200** | 页面正常响应 | ✅ 验证通过 |
| **404** | 页面不存在 | ❌ 检查路由配置 |
| **500** | 服务内部错误 | ❌ 检查编译/运行时错误 |
| **连接失败** | 服务未启动 | ️ 检查启动日志 |

### 3. 白屏检测

检测页面是否能正常渲染（非空白页）：

```bash
# 获取页面内容
PAGE_CONTENT=$(curl -s http://localhost:$PORT/)

# 检查是否有实质内容（排除空白HTML）
echo "$PAGE_CONTENT" | grep -q "<div id=\"app\">"
if [ $? -eq 0 ]; then
  # 检查 app div 后面是否有内容
  echo "$PAGE_CONTENT" | grep -A 5 "<div id=\"app\">" | grep -q "[^[:space:]]"
  if [ $? -eq 0 ]; then
    echo "页面有内容，非白屏"
  else
    echo "⚠️ app div 后无内容，可能是白屏"
  fi
else
  echo "页面结构异常"
fi
```

**白屏问题处理**:
| 结果 | 可能原因 | 处理 |
|------|----------|------|
| 页面有内容 | 正常 | ✅ 验证通过 |
| 白屏（app div空） | 组件渲染失败 | 检查控制台错误、组件导入 |
| 页面结构异常 | HTML模板错误 | 检查 index.html 配置 |

### 4. 路由检查（针对新增页面）

检查新增的路由是否可访问：

```bash
# 从任务文件中提取新增路由路径
NEW_ROUTE="{新增页面的路由路径}"

# 检查路由是否可访问
curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/#$NEW_ROUTE"
```

**路由检查处理**:
| HTTP状态码 | 验证结果 |
|------------|----------|
| **200** | ✅ 路由正常 |
| **404（前端返回）** | ⚠️ 需检查路由是否注册 |
| **无响应/连接失败** | ❌ 服务问题 |

**注意**: Vue Router 通常返回200，由前端处理路由，所以200表示服务正常。

### 5. 控制台错误检查

检查启动日志中是否有错误：

```bash
# 检查编译/运行错误
grep -i "error\|failed\|exception" worktree-{需求号}/frontend.log | grep -v "warn" | head -20
```

**错误处理**:
| 结果 | 处理 |
|------|------|
| 无 Error/Failed | ✅ 启动日志正常 |
| 有 Error（编译错误） | 进入 Step 4 修复循环 |
| 有 Failed（依赖问题） | 检查 npm install |

### 6. 清理验证进程

验证完成后关闭测试服务：

```bash
# 关闭前端服务
if [ -f worktree-{需求号}/frontend.pid ]; then
  kill $(cat worktree-{需求号}/frontend.pid) 2>/dev/null
  rm worktree-{需求号}/frontend.pid
fi
```

**验证结果汇总**:

| 检查项 | 期望结果 | 实际结果 | 状态 |
|--------|----------|----------|------|
| 启动 | "Local:"地址出现 | - | - |
| 页面响应 | 200 | - | - |
| 白屏检测 | 页面有内容 | - | - |
| 路由检查 | 200（新增页面） | - | - |
| 启动日志 | 无Error | - | - |

**反馈输出**（必须执行）：
```json
<FEEDBACK>
{
  "skill": "ai-frontend-dev-pro",
  "demandId": "{需求号}",
  "step": "3.5",
  "stepName": "启动验证",
  "status": "{passed/failed}",
  "currentTask": {
    "id": "任务{n}",
    "name": "{任务名称}",
    "status": "开发中"
  },
  "progress": {
    "totalTasks": "{总数}",
    "completedTasks": "{已完成数}",
    "inProgressTasks": "{开发中数}",
    "pendingTasks": "{待开发数}"
  },
  "validation": {
    "startup": "{成功/失败}",
    "pageResponse": "{HTTP状态码}",
    "whiteScreen": "{有内容/白屏}",
    "routeCheck": "{正常/异常/跳过}",
    "startupLog": "{正常/有错误}"
  },
  "timestamp": "{yyyy-mm-dd HH:mm:ss}",
  "message": "启动验证{通过/失败}，页面{有内容/白屏}"
}
</FEEDBACK>
```

**验证结果处理**:

| 结果 | 处理 |
|------|------|
| 全部通过 | 进入 Step 4 修复循环（如 Step 3 有问题）或 Step 5 更新状态 |
| 启动失败 | 进入 Step 4 修复循环，检查依赖/配置 |
| 白屏问题 | 进入 Step 4 修复循环，检查组件/路由/API |
| 路由异常 | 检查路由注册配置 |

---

## Step 4: 修复循环

**目标**: 修复验证中发现的问题，直到全部通过

**触发条件**: Step 3 验证中有任一项失败

**修复流程**:

1. **分析失败原因**:
   - 编译失败 → 分析错误日志，定位错误位置
   - 测试失败 → 分析测试报告，定位失败测试
   - TODO 存在 → 列出所有 TODO 位置
   - 漏改存在 → 列出遗漏的文件/字段

2. **逐一修复**:
   - 编译错误：修正语法、导入、类型等问题
   - 测试失败：修正业务逻辑、数据准备等问题
   - TODO：完成或移除 TODO 注释
   - 漏改：补充遗漏的实现

3. **重新验证**:
   回到 Step 3 重新执行验证。

4. **循环直到通过**:
   ```
   ❌ 验证失败 → 🔧 修复 → ✅ 重新验证 → (通过?) → Step 5
                                      │
                                      No → 继续修复循环
   ```

**修复记录**:
每次修复应在 `exec_proc.md` 中记录：失败原因、修复内容、修复时间。

5. **反馈输出**（每次修复后必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "4",
     "stepName": "修复循环",
     "status": "{repairing/completed}",
     "currentTask": {
       "id": "任务{n}",
       "name": "{任务名称}",
       "status": "开发中"
     },
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "{通过/失败}",
       "test": "{通过/失败}",
       "todoCheck": "{无遗留/有遗留}",
       "missingCheck": "{无遗漏/有遗漏}"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "修复第{m}次：{修复内容描述}"
   }
   </FEEDBACK>
   ```

---

## Step 5: 更新状态

**目标**: 记录任务完成，更新过程文档

**操作流程**:

1. **更新任务文件状态**:
   在 `DOCS/{需求号}/任务拆分/任务{n}.md` 中：
   - 状态改为「已完成」
   - 记录完成时间、修改的文件列表

2. **更新任务索引**:
   在 `DOCS/{需求号}/任务拆分/任务索引.md` 中：
   - 更新对应任务的状态为「已完成」
   - 更新整体进度统计

3. **更新 exec_proc.md**:
   在 `DOCS/{需求号}/前端编码/exec_proc.md` 中追加任务完成记录。

4. **检查是否有下一个任务**:
   - 有 → 回到 Step 1 继续开发
   - 无 → 进入 Step 6 准出检查

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "5",
     "stepName": "更新状态",
     "status": "completed",
     "currentTask": {
       "id": "任务{n}",
       "name": "{任务名称}",
       "status": "已完成"
     },
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{已完成数}",
       "inProgressTasks": "{开发中数}",
       "pendingTasks": "{待开发数}"
     },
     "validation": {
       "compile": "通过",
       "test": "通过",
       "todoCheck": "无遗留",
       "missingCheck": "无遗漏"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "任务{n}已完成，进度: {已完成数}/{总数}"
   }
   </FEEDBACK>
   ```

---

## Step 6: 准出检查

**目标**: 确认所有开发任务已完成，满足准出标准

**准出标准**:
1. ✅ 所有任务都已完成
2. ✅ 无 TODO 注释遗留
3. ✅ 无漏改
4. ✅ 编译通过
5. ✅ 测试通过

**操作流程**:

1. **最终验证**:

```bash
# 类型检查
npm run type-check

# Lint 检查
npm run lint

# 单元测试
npm run test

# 构建检查
npm run build
```

2. **检查任务索引**:
   确认所有任务状态为「已完成」。

3. **输出准出确认**:
   ```
   ✅ 准出检查通过:
   - 所有任务: 已完成 ({总数}/{总数})
   - 编译: 通过 ✓
   - 测试: 通过 ✓
   - TODO: 无遗留 ✓
   - 漏改: 无遗漏 ✓
   ```

4. **完成提示**:
   ```
   ✅ 前端开发任务已完成！

   💡 后续建议:
   - 如需提交代码，可使用 git-merge 技能
   - 如发现 Bug，请新开对话处理
   ```

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-frontend-dev-pro",
     "demandId": "{需求号}",
     "step": "6",
     "stepName": "准出检查",
     "status": "completed",
     "currentTask": null,
     "progress": {
       "totalTasks": "{总数}",
       "completedTasks": "{总数}",
       "inProgressTasks": "0",
       "pendingTasks": "0"
     },
     "validation": {
       "compile": "通过",
       "test": "通过",
       "todoCheck": "无遗留",
       "missingCheck": "无遗漏"
     },
     "timestamp": "{yyyy-mm-dd HH:mm:ss}",
     "message": "所有任务已完成，准出检查通过，前端开发结束"
   }
   </FEEDBACK>
   ```


6. **进入 Step 5.5**：
   - 执行 Step 5.5 更新 TFS 任务标签逻辑
   - 完成后检查是否有下一个任务：
     - 有 → 回到 Step 1 继续开发
     - 无 → 进入 Step 6 准出检查

---

## Step 5.5: 更新TFS任务标签（新增）

**目标**: 给完成的所有前端任务在 TFS 上添加 'AI-CODING' 标签，标记该任务由 AI 自动编码完成

**⚠️ 重要说明**: 此步骤在 Step 5 更新状态后执行，只处理前端相关任务。

**前端任务判定规则**:

通过任务名称判断任务是否为前端任务，以下关键词判定为前端任务：

| 关键词 | 说明 |
|--------|------|
| 前端、页面、UI、界面 | 明确的前端关键词 |
| Vue、组件、Component、Element | 前端框架/库关键词 |
| CSS、样式、布局、响应式 | 样式层关键词 |
| JavaScript、JS、TypeScript、TS | 前端语言关键词 |
| **排除关键词**：后端、接口、API、服务 | 非前端任务，跳过 |

**判定逻辑**:
```
任务名称包含 "后端/接口/API/服务/Service"
  → 判定为非前端任务，跳过此步骤
任务名称包含 "前端/页面/UI/Vue/组件/Element/CSS/样式/布局/JavaScript/TypeScript"
  → 判定为前端任务，执行标签更新
```

**操作流程**:

### 1. 判断任务类型

```bash
# 从任务名称判断是否为前端任务
任务名称 = "{任务{n}.md 中的标题}"

# 前端任务关键词（包含即判定为前端）
前端关键词 = ["前端", "页面", "UI", "界面", "Vue", "组件", "Component", "Element", "CSS", "样式", "布局", "响应式", "JavaScript", "JS","TypeScript", "TS"]

# 后端任务关键词（包含即判定为非前端，跳过）
后端关键词 = ["后端", "接口", "API", "服务", "Service", "Controller", "Dao", "Mapper", "Entity", "数据库", "SQL", "存储", "持久化", "RPC", "微服务", "Spring Boot"]

# 判断逻辑
if 任务名称 contains 任意后端关键词:
    判定结果 = "非前端任务"
    跳过此步骤，继续检查下一个任务或进入 Step 6
elif 任务名称 contains 任意前端关键词:
    判定结果 = "前端任务"
    执行标签更新
else:
    # 默认判断：任务拆分目录在"前端编码"下，默认为前端任务
    判定结果 = "前端任务（默认）"
    执行标签更新
```

### 2. 获取任务对应的 TFS 工作项 ID

从任务文件中提取 TFS 工作项 ID：

```bash
# 读取任务文件
cat DOCS/{需求号}/任务拆分/任务{n}.md

# 提取 TFS ID（从任务基本信息中获取）
TFS_ID = 任务文件中的 "需求号" 或 "TFS工作项ID" 字段
```

**⚠️ 说明**：
- 如果任务文件中没有 TFS ID，则跳过此任务
- 如果需求号即为 TFS 父需求 ID，则查找对应的子任务 TFS ID

### 3. 查询子任务 TFS ID

如果任务对应的是 TFS 子任务（而非父需求），需要查询对应的子任务 ID：

```bash
# 获取父需求下的子任务列表
node .claude/skills/ai-tfs-integration/tools/get-workitem-relations.mjs {父需求ID} children

# 根据任务名称匹配对应的子任务 TFS ID
子任务列表中标题包含 "{任务名称}" 的工作项 ID
```

### 4. 添加 'AI-CODING' 标签

调用 ai-tfs-integration 技能为工作项添加标签：

```bash
# 添加标签命令（使用 tfs-query.mjs 命令行工具）
node .claude/skills/ai-tfs-integration/tools/tfs-query.mjs add-tag {TFS_ID} "AI-CODING"
```

**注意**：`tfs-client.mjs` 是类库模块，不能直接执行；`tfs-query.mjs` 才是命令行工具。
```

**或使用 Skill 工具调用**：

```markdown
Skill: ai-tfs-integration
指令: 为工作项 {TFS_ID} 添加标签 "AI-CODING"
```

### 5. 验证标签添加结果

```bash
# 查询工作项确认标签已添加
node .claude/skills/ai-tfs-integration/tools/tfs-query.mjs get {TFS_ID}

# 检查返回结果中的 tags 字段是否包含 "AI-CODING"
```

### 6. 更新 exec_proc.md 记录

在 `DOCS/{需求号}/前端编码/exec_proc.md` 中追加标签更新记录：


```markdown
### Step 5.5: 更新TFS任务标签

**任务**: 任务{n} - {任务名称}
**判定结果**: 前端任务
**TFS工作项ID**: {TFS_ID}
**标签添加**: AI-CODING
**添加时间**: {yyyy-mm-dd HH:mm}
**添加结果**: ✅ 成功 / ❌ 失败（{失败原因}）
```

### 7. 处理异常情况

| 异常情况 | 处理方式 |
|----------|----------|
| 任务文件无 TFS ID | 记录 WARN，跳过此任务，继续下一个 |
| TFS 查询失败 | 记录 ERROR，继续流程（不阻塞） |
| 标签添加失败 | 记录 ERROR，继续流程（不阻塞） |
| 已有 AI-CODING 标签 | 记录 INFO，跳过添加，继续流程 |
| 任务判定为非后端 | 记录 INFO，跳过此步骤 |

**日志记录格式**：

```
[INFO] Step 5.5-更新TFS标签：任务{n} - {任务名称}
       - 任务类型判定：前端任务 / 非前端任务（跳过）
       - TFS工作项ID：{ID}
       - 标签添加：✅ 成功 / ❌ 失败 / ⏭ 已存在

[WARN] Step 5.5-更新TFS标签：任务{n} 无TFS ID，跳过

[ERROR] Step 5.5-更新TFS标签：TFS查询失败，{错误信息}
```

### 8. 反馈输出（必须执行）

```json
<FEEDBACK>
{
  "skill": "ai-frontend-dev-pro",
  "demandId": "{需求号}",
  "step": "5.5",
  "stepName": "更新TFS任务标签",
  "status": "completed",
  "currentTask": {
    "id": "任务{n}",
    "name": "{任务名称}",
    "status": "已完成",
    "taskType": "前端任务 / 非前端任务",
    "tfsId": "{TFS_ID 或 null}"
  },
  "progress": {
    "totalTasks": "{总数}",
    "completedTasks": "{已完成数}",
    "inProgressTasks": "{开发中数}",
    "pendingTasks": "{待开发数}"
  },
  "tagUpdate": {
    "taskType": "前端任务 / 非前端任务（跳过）",
    "tfsId": "{TFS_ID}",
    "tagName": "AI-CODING",
    "result": "成功 / 失败 / 已存在 / 跳过"
  },
  "timestamp": "{yyyy-mm-dd HH:mm:ss}",
  "message": "TFS标签更新完成，{结果描述}"
}
</FEEDBACK>
```

### 9. 完成后流程

- 有下一个待开发任务 → 回到 Step 1 继续开发
- 所有任务已完成 → 进入 Step 6 准出检查

---

---

## Vue2 到 Vue3 迁移规则

当用户要求迁移 Vue2 组件时，遵循以下规则：

### 核心原则

1. **行为等价原则**: 重构前后代码的运行时行为必须完全一致
2. **最小改动原则**: 只修改与迁移目标直接相关的代码
3. **全量迁移原则**: 允许修改组件内所有部分以达到纯 Vue3 Composition API

### 迁移映射

| Vue2 Options API | Vue3 Composition API |
|------------------|---------------------|
| `data()` | `ref()` / `reactive()` |
| `props` | `defineProps<T>()` |
| `emits` | `defineEmits<{}>()` |
| `computed` | `computed()` |
| `watch` | `watch()` / `watchEffect()` |
| `methods` | 普通顶层函数 |
| `mounted` | `onMounted()` |
| `beforeUnmount` | `onBeforeUnmount()` |
| `unmounted` | `onUnmounted()` |

### 迁移后必须输出审计报告

```markdown
## 🔍 Refactor Audit Block

### 基本信息
- 迁移文件路径: src/views/User/List.vue
- 迁移阶段: Vue2 to Vue3 Composition API Migration

### 行为等价性验证
- 行为是否等价: ✅ Yes
- 等价性说明: [具体说明]

### 副作用管理
- 副作用变更: [说明]
- 副作用详细列表: [列表]

### 代码质量检查
- Lint 检查: ✅ 通过
- TypeScript 类型: ✅ 完整

### 回滚能力
- 是否可回滚: ✅ Yes
- 回滚方式: `git revert <commit-hash>`
```

---

## AI 重构行为约束

### 四大核心原则（强制）

1. **禁止自由发挥**: AI 只能在明确授权范围内修改代码
2. **行为等价**: 重构前后运行时行为必须完全一致
3. **最小 Diff**: 只修改与目标直接相关的代码
4. **可回滚**: 所有修改必须支持 `git revert`

### 禁止的操作

```
❌ "顺手"优化代码结构
❌ 自动调整代码格式
❌ 修改变量/函数命名（除非是目标）
❌ 添加"可能有用"的功能
❌ 删除"看起来没用"的代码
❌ 修改代码风格
❌ 新增/删除依赖
❌ 修改框架配置文件
```

### 强制中止条件

检测到以下情况必须立即停止：
- 行为等价性无法保证
- 涉及模板或样式修改（除非是迁移要求）
- Props/Emits 类型变化
- 跨模块结构变更
- 超出授权范围

---

## 目录结构规范

### Vue 3 + Spark 项目结构

```
src/views/
├── [ViewName]/              # 业务模块目录（PascalCase）
│   ├── apis/               # 接口定义
│   │   └── user.ts
│   ├── components/         # 模块组件
│   │   └── UserForm.vue
│   ├── composables/        # 组合式函数
│   │   └── useUserList.ts
│   ├── stores/             # 状态管理
│   │   └── user.ts
│   ├── types/              # 类型定义
│   │   └── user.ts
│   └── index.vue           # 模块入口（必需）
```

### 快开框架 RDF 项目结构

```
src/modules/
├── [ModuleName]/           # 功能模块
│   ├── views/
│   │   └── [PageCode].view.xml    # 视图配置
│   ├── [PageCode].page.meta.xml   # 页面元数据
│   ├── [PageCode].layout.xml      # 布局配置（可选）
│   └── controller/
│       └── [PageCode].controller.ts # 控制类
```

---

## 常见问题处理

### Q1: 组件库类型缺失

```bash
# 检查是否安装了类型包
npm install -D @types/xxx
```

### Q2: API 接口未定义

使用 Mock 数据开发：
```typescript
// TODO: 后端接口就绪后替换为真实 API
const mockUsers: User[] = [
  { id: 1, name: '张三' }
];

export const getUserList = async () => {
  // return userApi.getList()
  return { data: mockUsers };
};
```

### Q3: 样式深度选择器

```vue
<style scoped>
/* Vue 3 使用 :deep() */
:deep(.w-table .cell) {
  padding: 0;
}

/* 或使用 :global() */
:global(.custom-class) {
  color: red;
}
</style>
```

### Q4: 命名冲突避免

```typescript
// ❌ 错误：解构赋值时产生冲突
const hintStatus = ref('');
const { hintStatus } = res.data;  // 冲突！

// ✅ 正确：重命名避免冲突
const hintStatus = ref('');
const { hintStatus: hintStatusData } = res.data;
hintStatus.value = hintStatusData;
```
