# 执行步骤详细指南

## Step 0: 准入检查

**目标**: 确认可以进入开发流程

**准入条件**:
1. 任务拆分目录 `DOCS/{需求号}/任务拆分/` 下有待开发的后端任务
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
     "skill": "ai-backend-dev-pro",
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
   - **技术栈**: Spring Boot版本、Java版本、框架组件
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
     "skill": "ai-backend-dev-pro",
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

**目标**: 按任务要求实现代码，遵循知识库规范

### 实现原则（必须遵守）

**核心原则**: 只做必要的改动，不做未经请求的优化

#### 1. 最小改动原则

| 原则 | 说明 | 示例 |
|------|------|------|
| **只改必要的** | 只修改任务明确要求的代码 | 任务要求添加字段 → 只添加字段，不重构整个类 |
| **保持风格一致** | 新代码必须与现有代码风格保持一致 | 现有代码用驼峰命名 → 新代码也用驼峰 |
| **不做额外优化** | 禁止"顺便优化"不相关的代码 | ❌ "顺便优化了旁边的代码" |
| **不添加未请求功能** | 禁止添加任务未要求的功能 | ❌ "顺便加了个日志功能" |
| **不重构无关模块** | 禁止重构不涉及任务的模块 | ❌ "顺便重构了工具类" |

**⚠️ 违反最小改动原则的典型错误**:
```
❌ 错误示例：
任务: 添加 status 字段
实际修改:
  - 添加 status 字段 ✓
  - 重构了整个 Entity 类 ❌
  - 修改了不相关的 Service 方法 ❌
  - 添加了未请求的日志功能 ❌

✅ 正确示例：
任务: 添加 status 字段
实际修改:
  - 添加 status 字段 ✓
  - 仅修改必要的 getter/setter ✓
  - 仅修改任务涉及的 Service 方法 ✓
```

#### 2. 分层架构原则

- **分层清晰**: Controller → Service → Repository → Entity
- **单一职责**: 每个类/方法只做一件事

#### 3. 注释规则

**改动必须注释**: 每次代码修改都必须添加注释说明改动原因和内容

| 改动类型 | 注释要求 | 格式示例 |
|----------|----------|----------|
| **新增类/方法** | 必须添加说明注释 | `/** 功能说明 */` |
| **修改现有代码** | 必须在修改处添加注释 | `// [需求{号}] 修改原因：{原因}` |
| **修复Bug** | 必须添加注释说明问题和修复 | `// [Bug修复] 问题：{问题}，修复：{方案}` |
| **删除代码** | 必须注释删除原因 | `// [需求{号}] 已删除：{原因}` |

**注释格式规范**:
```java
// 正确示例 - 修改现有代码
public void processOrder(Order order) {
    // [需求260514] 新增：增加订单状态校验，防止重复处理
    if (order.getStatus() == OrderStatus.PROCESSED) {
        throw new BusinessException("订单已处理");
    }

    // [需求260514] 修改：调整计算逻辑，优先使用折扣价
    // 原代码: order.setTotalPrice(order.getPrice() * order.getQuantity());
    order.setTotalPrice(order.getDiscountPrice() * order.getQuantity());

    // [需求260514] 删除：移除冗余的库存检查，已在下单时校验
    // 原代码: checkInventory(order);
}
```

**⚠️ 注释禁令**:
- ❌ 不写无意义的注释：`// 设置名称` → `order.setName(name);`
- ❌ 不写过度详细的注释：每行代码都加注释
- ❌ 不删不改原有有效注释：保留有价值的现有注释

**实现顺序**（由内向外）:
1. Entity 层 - 数据库实体修改/新增
2. Repository 层 - 数据访问接口
3. Service 层 - 业务逻辑实现
4. Controller/RPC 层 - 接口暴露
5. DTO/VO 层 - 请求响应对象

**操作流程**:

1. **分析任务涉及的文件和层级**

2. **按分层顺序实现代码**:
   - 先读取现有相关文件，理解现有结构
   - 新增/修改代码，确保与现有代码风格一致
   - 遵循知识库中的命名规范、包结构规范
   - **每次改动必须添加注释说明改动原因**

3. **关键检查点**:
   - [ ] 是否遵循最小改动原则（只改必要的）
   - [ ] 是否保持现有代码风格一致
   - [ ] 是否添加了必要的改动注释
   - [ ] 是否遵循项目知识库编码规范
   - [ ] 是否正确处理多租户（如有要求）
   - [ ] 是否添加了必要的异常处理
   - [ ] 是否遵循接口设计规范
   - [ ] 是否未做未经请求的优化

4. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-backend-dev-pro",
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

**验证项目**:

1. **编译验证**：
   执行知识库中配置的编译命令（默认 `mvn compile`）

2. **测试验证**：
   执行知识库中配置的测试命令（默认 `mvn test`）

3. **TODO 检查**：
   ```bash
   grep -r "TODO" --include="*.java" .
   ```

4. **漏改检查**：
   - 对照任务要求，确认所有涉及文件都已处理
   - 对照接口设计，确认所有字段都已实现

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
     "skill": "ai-backend-dev-pro",
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

**目标**: 验证后端服务能够正常启动并响应请求

**⚠️ 重要说明**: 这是运行时验证，在静态验证通过后执行，确保服务能实际运行。

**验证项目**:

### 1. 打包验证

确保项目能够打包成可执行 jar：

```bash
# 执行打包（跳过测试，因为已在 Step 3 验证）
mvn package -DskipTests -f worktree-{需求号}/icis/pom.xml
```

**验证结果处理**:
| 结果 | 处理 |
|------|------|
| 打包成功 | 继续 Step 3.5.2 启动验证 |
| 打包失败 | 进入 Step 4 修复循环 |

### 2. 启动验证（后台启动）

启动后端服务并等待就绪：

```bash
# 后台启动服务
java -jar worktree-{需求号}/icis/icis-boot/target/icis-boot-*.jar > worktree-{需求号}/startup.log 2>&1 &
echo $! > worktree-{需求号}/backend.pid

# 等待服务启动（最多60秒）
for i in {1..60}; do
  if grep -q "Started.*Application" worktree-{需求号}/startup.log 2>/dev/null; then
    echo "服务启动成功"
    break
  fi
  sleep 1
done
```

**验证结果处理**:
| 结果 | 处理 |
|------|------|
| 启动成功（"Started"日志出现） | 继续 Step 3.5.3 API响应检查 |
| 启动失败 | 检查 startup.log，进入 Step 4 修复循环 |
| 启动超时（60秒无响应） | 检查数据库连接、端口配置 |

### 3. API响应检查

验证 API 接口可访问：

```bash
# 检查 API 文档页面（Swagger/Knife4j）
curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/doc.html

# 或检查健康检查接口（如有）
curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/actuator/health
```

**⚠️ 鉴权处理策略**:

| HTTP状态码 | 含义 | 验证结果 |
|------------|------|----------|
| **200** | 服务正常，无鉴权 | ✅ 验证通过 |
| **401** | 服务正常，需要认证 | ✅ 验证通过（服务已启动，接口存在） |
| **403** | 服务正常，权限不足 | ✅ 验证通过（服务已启动，接口存在） |
| **404** | 接口不存在 | ⚠️ 需要检查接口路径配置 |
| **500** | 服务内部错误 | ❌ 验证失败，进入修复循环 |
| **连接失败** | 服务未启动或端口错误 | ❌ 验证失败，检查启动日志 |

**说明**: 401/403 表示服务已启动且接口存在，只是需要认证。这说明后端代码运行正常，属于验证通过。

### 4. 启动日志检查

检查启动过程中是否有错误：

```bash
# 检查是否有 Error/Exception（排除预期的警告）
grep -i "Error\|Exception" worktree-{需求号}/startup.log | grep -v "WARN" | head -20
```

**验证结果处理**:
| 结果 | 处理 |
|------|------|
| 无 Error/Exception | ✅ 启动日志正常 |
| 有 Error（非WARN） | 检查错误详情，判断是否影响功能 |

### 5. 清理验证进程

验证完成后关闭测试服务：

```bash
# 关闭后端服务
if [ -f worktree-{需求号}/backend.pid ]; then
  kill $(cat worktree-{需求号}/backend.pid) 2>/dev/null
  rm worktree-{需求号}/backend.pid
fi
```

**验证结果汇总**:

| 检查项 | 期望结果 | 实际结果 | 状态 |
|--------|----------|----------|------|
| 打包 | 成功 | - | - |
| 启动 | "Started"日志 | - | - |
| API响应 | 200/401/403 | - | - |
| 启动日志 | 无Error | - | - |

**反馈输出**（必须执行）：
```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
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
    "package": "{成功/失败}",
    "startup": "{成功/失败}",
    "apiResponse": "{HTTP状态码}",
    "startupLog": "{正常/有错误}"
  },
  "timestamp": "{yyyy-mm-dd HH:mm:ss}",
  "message": "启动验证{通过/失败}，API响应{状态码}"
}
</FEEDBACK>
```

**验证结果处理**:

| 结果 | 处理 |
|------|------|
| 全部通过 | 进入 Step 4 修复循环（如 Step 3 有问题）或 Step 5 更新状态 |
| 打包/启动失败 | 进入 Step 4 修复循环 |
| API 500错误 | 进入 Step 4 修复循环，检查运行时错误 |
| API 404错误 | 检查接口路径配置，可能需要修复 |
| API 401/403 | ✅ 视为通过（服务已启动，需要认证） |

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
     "skill": "ai-backend-dev-pro",
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
   在 `DOCS/{需求号}/后端编码/exec_proc.md` 中追加任务完成记录。

4. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-backend-dev-pro",
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
     "message": "任务{n}已完成，进度: {已完成数}/{总数}，进入Step 5.5更新TFS标签"
   }
   </FEEDBACK>
   ```

5. **进入 Step 5.5**：
   - 执行 Step 5.5 更新 TFS 任务标签逻辑
   - 完成后检查是否有下一个任务：
     - 有 → 回到 Step 1 继续开发
     - 无 → 进入 Step 6 准出检查

---

## Step 5.5: 更新TFS任务标签（新增）

**目标**: 给完成的后端任务在 TFS 上添加 'AI-CODING' 标签，标记该任务由 AI 自动编码完成

**⚠️ 重要说明**: 此步骤在 Step 5 更新状态后执行，只处理后端相关任务。

**后端任务判定规则**:

通过任务名称判断任务是否为后端任务，以下关键词判定为后端任务：

| 关键词 | 说明 |
|--------|------|
| 后端、接口、API、服务、Service | 明确的后端关键词 |
| Controller、Dao、Mapper、Entity | Java 分层架构关键词 |
| 数据库、SQL、存储、持久化 | 数据层关键词 |
| RPC、微服务、Spring Boot | 技术栈关键词 |
| **排除关键词**：前端、页面、UI、Vue、组件 | 非后端任务 |

**判定逻辑**:
```
任务名称包含 "后端/接口/API/服务/Service/Controller/Dao/Mapper/Entity/数据库/SQL"
  → 判定为后端任务
任务名称包含 "前端/页面/UI/Vue/组件"
  → 判定为非后端任务，跳过此步骤
```

**操作流程**:

### 1. 判断任务类型

```bash
# 从任务名称判断是否为后端任务
任务名称 = "{任务{n}.md 中的标题}"

# 后端任务关键词（包含即判定为后端）
后端关键词 = ["后端", "接口", "API", "服务", "Service", "Controller", "Dao", "Mapper", "Entity", "数据库", "SQL", "存储", "持久化", "RPC", "微服务", "Spring Boot"]

# 前端任务关键词（包含即判定为非后端，跳过）
前端关键词 = ["前端", "页面", "UI", "Vue", "组件", "Element"]

# 判断逻辑
if 任务名称 contains 任意前端关键词:
    判定结果 = "非后端任务"
    跳过此步骤，继续检查下一个任务或进入 Step 6
elif 任务名称 contains 任意后端关键词:
    判定结果 = "后端任务"
    执行标签更新
else:
    # 默认判断：任务拆分目录在"后端编码"下，默认为后端任务
    判定结果 = "后端任务（默认）"
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

在 `DOCS/{需求号}/后端编码/exec_proc.md` 中追加标签更新记录：

```markdown
### Step 5.5: 更新TFS任务标签

**任务**: 任务{n} - {任务名称}
**判定结果**: 后端任务
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
       - 任务类型判定：后端任务 / 非后端任务（跳过）
       - TFS工作项ID：{ID}
       - 标签添加：✅ 成功 / ❌ 失败 / ⏭ 已存在

[WARN] Step 5.5-更新TFS标签：任务{n} 无TFS ID，跳过

[ERROR] Step 5.5-更新TFS标签：TFS查询失败，{错误信息}
```

### 8. 反馈输出（必须执行）

```json
<FEEDBACK>
{
  "skill": "ai-backend-dev-pro",
  "demandId": "{需求号}",
  "step": "5.5",
  "stepName": "更新TFS任务标签",
  "status": "completed",
  "currentTask": {
    "id": "任务{n}",
    "name": "{任务名称}",
    "status": "已完成",
    "taskType": "后端任务 / 非后端任务",
    "tfsId": "{TFS_ID 或 null}"
  },
  "progress": {
    "totalTasks": "{总数}",
    "completedTasks": "{已完成数}",
    "inProgressTasks": "{开发中数}",
    "pendingTasks": "{待开发数}"
  },
  "tagUpdate": {
    "taskType": "后端任务 / 非后端任务（跳过）",
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
   mvn compile
   mvn test
   grep -r "TODO" --include="*.java" .
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
   ✅ 后端开发任务已完成！

   💡 后续建议:
   - 如需提交代码，可使用 ai-git-merge 技能
   - 如发现 Bug，请新开对话处理
   ```

5. **反馈输出**（必须执行）：
   ```json
   <FEEDBACK>
   {
     "skill": "ai-backend-dev-pro",
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
     "message": "所有任务已完成，准出检查通过，后端开发结束"
   }
   </FEEDBACK>
   ```

6. **最终更新任务索引**：
   - 所有任务状态更新为「已完成」
   - 进度统计：已完成 = 总数
   - 标记整体状态为「开发完成」
