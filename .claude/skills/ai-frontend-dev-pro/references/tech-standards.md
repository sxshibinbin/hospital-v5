# 技术栈规范

> 详细说明各前端技术栈的技术规范、代码风格、最佳实践。

## 目录

- [Vue 3 + Spark 框架](#vue-3--spark-框架)
- [Vue 2 + Spark 框架](#vue-2--spark-框架)
- [快开框架 RDF](#快开框架-rdf)
- [HTML 静态原型](#html-静态原型)
- [TypeScript 规范](#typescript-规范)
- [技术栈识别规则](#技术栈识别规则)

---

## Vue 3 + Spark 框架

### 技术栈特征

| 维度 | 规范 |
|------|------|
| **框架版本** | Vue 3.3+ |
| **API 风格** | Composition API + `<script setup lang="ts">` |
| **组件库** | win-design-next（w- 前缀） |
| **状态管理** | Pinia（从 spark 导入） |
| **HTTP 请求** | request（从 spark 导入） |
| **国际化** | i18n（从 spark 导入） |
| **构建工具** | Vite |
| **测试框架** | Vitest |

### 导入规范（强制）

```typescript
// ✅ 正确：从 spark 导入
import { ref, computed, onMounted } from 'spark';
import { request, t, useI18n } from 'spark';
import { defineStore, storeToRefs } from 'spark';
import { useRouter, useRoute } from 'spark';

// ❌ 错误：从原生库导入
import { ref } from 'vue';
import { useRouter } from 'vue-router';
```

### 组件模板

```vue
<template>
  <div class="component-name">
    <!-- 使用 win-design 组件 -->
    <w-button type="primary">{{ $t('common.save') }}</w-button>
  </div>
</template>

<script setup lang="ts">
// 1. 从 spark 导入
import { ref, computed, onMounted } from 'spark';

// 2. Props 定义（TypeScript 接口）
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

// 5. 计算属性
const displayTitle = computed(() => props.title.toUpperCase());

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

### 目录结构

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

---

## Vue 2 + Spark 框架

### 技术栈特征

| 维度 | 规范 |
|------|------|
| **框架版本** | Vue 2.6+ |
| **API 风格** | Options API |
| **组件库** | win-design@2.x（w- 前缀） |
| **状态管理** | Vuex（或 Pinia 兼容模式） |
| **HTTP 请求** | request（从 spark 导入） |
| **国际化** | i18n（从 spark 导入） |
| **构建工具** | Vite / Webpack |

### 组件模板

```vue
<template>
  <div class="component-name">
    <w-button type="primary">{{ $t('common.save') }}</w-button>
  </div>
</template>

<script>
export default {
  name: 'ComponentName',

  props: {
    title: {
      type: String,
      required: true
    },
    count: {
      type: Number,
      default: 0
    }
  },

  data() {
    return {
      loading: false,
      dataList: []
    };
  },

  computed: {
    displayTitle() {
      return this.title.toUpperCase();
    }
  },

  methods: {
    handleSubmit() {
      this.$emit('change', this.count + 1);
    },

    fetchData() {
      // ...
    }
  },

  mounted() {
    this.fetchData();
  }
};
</script>

<style scoped>
.component-name {
  padding: 16px;
}
</style>
```

---

## 快开框架 RDF

### 技术栈特征

| 维度 | 规范 |
|------|------|
| **框架类型** | 低代码快速开发框架 |
| **配置方式** | XML 配置 + TypeScript 控制类 |
| **组件库** | pango-framework |
| **页面编码** | pageCode（唯一标识） |
| **视图定义** | .view.xml |
| **元数据定义** | .page.meta.xml |
| **布局定义** | .layout.xml（可选） |

### 目录结构

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

### 页面元数据模板（.page.meta.xml）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<page xmlns="http://www.winning.com.cn/rdf/page"
      pageCode="userManage"
      title="用户管理"
      module="UserModule">

  <description>用户管理页面</description>

  <permission>
    <read>user:read</read>
    <write>user:write</write>
  </permission>

  <dataSource>
    <api>/api/user/list</api>
    <method>GET</method>
  </dataSource>

  <events>
    <onLoad>handleLoad</onLoad>
    <onSearch>handleSearch</onSearch>
  </events>
</page>
```

### 视图配置模板（.view.xml）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<view xmlns="http://www.winning.com.cn/rdf/view"
      pageCode="userManage">

  <!-- 查询区域 -->
  <searchArea>
    <field name="username" label="用户名" type="input" />
    <field name="status" label="状态" type="select">
      <options>
        <option value="active" label="启用" />
        <option value="inactive" label="禁用" />
      </options>
    </field>
    <button type="search" label="查询" />
    <button type="reset" label="重置" />
  </searchArea>

  <!-- 操作区域 -->
  <toolbar>
    <button type="add" label="新增" permission="user:write" />
    <button type="delete" label="删除" permission="user:write" />
  </toolbar>

  <!-- 表格区域 -->
  <table>
    <column name="username" label="用户名" width="120" />
    <column name="email" label="邮箱" width="200" />
    <column name="status" label="状态" width="100">
      <template>
        <tag type="success" condition="status === 'active'" label="启用" />
        <tag type="danger" condition="status === 'inactive'" label="禁用" />
      </template>
    </column>
    <column name="createTime" label="创建时间" width="180" />
    <column type="operation" label="操作" width="200">
      <button type="edit" label="编辑" permission="user:write" />
      <button type="delete" label="删除" permission="user:write" />
    </column>
  </table>

  <!-- 分页 -->
  <pagination pageSize="10" pageSizes="10,20,50,100" />
</view>
```

### 控制类模板（.controller.ts）

```typescript
import { BaseController } from 'pango-framework';

export class UserManageController extends BaseController {
  // 页面加载
  async handleLoad(params: any) {
    const data = await this.request('/api/user/list', params);
    return data;
  }

  // 查询
  async handleSearch(params: any) {
    const data = await this.request('/api/user/list', params);
    return data;
  }

  // 新增
  async handleAdd(data: any) {
    await this.request('/api/user/create', data, 'POST');
    this.message.success('新增成功');
  }

  // 编辑
  async handleEdit(data: any) {
    await this.request('/api/user/update', data, 'PUT');
    this.message.success('编辑成功');
  }

  // 删除
  async handleDelete(id: string) {
    await this.confirm('确定要删除吗？');
    await this.request(`/api/user/delete/${id}`, null, 'DELETE');
    this.message.success('删除成功');
  }
}
```

---

## HTML 静态原型

### 技术栈特征

| 维度 | 规范 |
|------|------|
| **页面类型** | 静态 HTML 原型 |
| **样式方案** | WinDesign CSS + 自定义 CSS |
| **脚本语言** | 原生 JavaScript（或 jQuery） |
| **目的** | 需求验证、快速原型、设计评审 |

### 原型输出位置

```
- 存在前端项目 → src/prototype/
- 不存在前端项目 → doc/prototype/
```

### 原型规范（强制）

- 生成**静态 HTML 页面**，不包含动态交互
- **滚动条规范**：禁止水平滚动；内容超出时，内容区域垂直滚动
- **UI 组件**：使用 WinDesign CSS 类名
- **原型完成后必须自动打开浏览器展示**

### HTML 模板

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>用户管理 - 原型</title>
  <!-- WinDesign CSS -->
  <link rel="stylesheet" href="win-design/dist/index.css">
  <style>
    /* 自定义样式 */
    .page-container {
      padding: 16px;
    }
    .search-area {
      margin-bottom: 16px;
    }
  </style>
</head>
<body>
  <div class="page-container">
    <!-- 查询区域 -->
    <div class="search-area w-card">
      <div class="w-card__body">
        <div class="w-row">
          <div class="w-col w-col-6">
            <label class="w-form-item__label">用户名</label>
            <input class="w-input" placeholder="请输入用户名">
          </div>
          <div class="w-col w-col-6">
            <label class="w-form-item__label">状态</label>
            <select class="w-select">
              <option>启用</option>
              <option>禁用</option>
            </select>
          </div>
          <div class="w-col w-col-6">
            <button class="w-button w-button--primary">查询</button>
            <button class="w-button">重置</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 表格区域 -->
    <div class="w-card">
      <div class="w-card__header">
        <span>用户列表</span>
        <button class="w-button w-button--primary">新增</button>
      </div>
      <div class="w-card__body">
        <table class="w-table">
          <thead>
            <tr>
              <th>用户名</th>
              <th>邮箱</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>张三</td>
              <td>zhangsan@example.com</td>
              <td><span class="w-tag w-tag--success">启用</span></td>
              <td>
                <button class="w-button w-button--small">编辑</button>
                <button class="w-button w-button--small w-button--danger">删除</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</body>
</html>
```

---

## TypeScript 规范

### 基本规则

1. **禁止使用 `any` 类型**：除非特殊情况且必须注释说明
2. **使用接口定义 Props**：
```typescript
interface Props {
  title: string;
  count?: number;  // 可选属性
}
```
3. **使用泛型定义响应式数据**：
```typescript
const dataList = ref<User[]>([]);
const formData = reactive<FormState>({
  username: '',
  email: ''
});
```

### 类型定义文件模板

```typescript
// types/user.ts

/** 用户信息 */
export interface User {
  id: string;
  username: string;
  email: string;
  status: 'active' | 'inactive';
  createTime: string;
}

/** 用户查询参数 */
export interface UserQueryParams {
  username?: string;
  status?: string;
  page: number;
  pageSize: number;
}

/** 用户表单数据 */
export interface UserFormData {
  username: string;
  email: string;
  status: string;
}

/** 用户 API 响应 */
export interface UserApiResponse {
  data: User[];
  total: number;
  page: number;
  pageSize: number;
}
```

---

## 技术栈识别规则

### 识别优先级

```
1. 项目 CLAUDE.md（技术栈说明）
   ↓ 如不存在
2. package.json（依赖分析）
   ↓ 如不存在
3. 现有代码结构（目录分析）
   ↓ 如不存在
4. 用户明确指定
```

### 检测特征对照表

| 检测特征 | 技术栈判定 | 组件库 | API 风格 |
|----------|-----------|--------|----------|
| `spark` 导入 + Vue 3 特征 | Vue 3 + Spark | win-design-next | Composition API |
| `spark` 导入 + Vue 2 特征 | Vue 2 + Spark | win-design@2.x | Options API |
| `.page.meta.xml` + `.view.xml` | 快开框架 RDF | pango-framework | XML 配置 |
| 纯 `.html` 文件 | HTML 静态原型 | WinDesign CSS | 静态 |
| `package.json` 含 `vue: "^3"` | Vue 3 | 按其他特征判断 | Composition API |
| `package.json` 含 `vue: "^2"` | Vue 2 | 按其他特征判断 | Options API |

### CLAUDE.md 模板

```markdown
# 项目技术栈

- 框架: Vue 3 + Spark Framework
- UI库: win-design-next (w- 前缀组件)
- 状态管理: Pinia (从 spark 导入)
- API请求: request (从 spark 导入)
- 国际化: i18n (从 spark 导入)
- 构建工具: Vite
- 代码风格: Composition API + <script setup lang="ts">
```

### package.json 分析要点

```json
{
  "dependencies": {
    "vue": "^3.3.0",           // Vue 版本
    "spark": "^1.0.0",         // Spark 框架
    "win-design-next": "^1.0.0", // WinDesign Next
    "pango-framework": "^1.0.0"  // 快开框架
  },
  "devDependencies": {
    "vite": "^4.0.0",          // Vite 构建
    "typescript": "^5.0.0"     // TypeScript
  }
}
```