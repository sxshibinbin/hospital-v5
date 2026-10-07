# 页面模式索引

> 各类医疗后台系统页面的标准结构与代码模板。

## 目录

- [登录页](#登录页)
- [表格列表页](#表格列表页)
- [表单录入页](#表单录入页)
- [详情页](#详情页)
- [Dashboard 看板](#dashboard-看板)
- [弹窗表单](#弹窗表单)

---

## 登录页

### 标准结构

```
登录页组件结构：
├── 背景图（可选）
├── 登录表单区域
│   ├── Logo
│   ├── 系统名称
│   ├── 用户名输入框
│   ├── 密码输入框
│   ├── 记住密码复选框（可选）
│   ├── 登录按钮
│   └── 忘记密码链接（可选）
└── 底部版权信息（可选）
```

### 核心代码片段

```vue
<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <img src="@/assets/logo.png" class="logo" alt="Logo" />
        <h1>{{ $t('login.title') }}</h1>
      </div>

      <w-form ref="formRef" :model="formData" :rules="rules" class="login-form">
        <w-form-item prop="username">
          <w-input
            v-model="formData.username"
            :prefix-icon="User"
            placeholder="{{ $t('login.usernamePlaceholder') }}"
          />
        </w-form-item>

        <w-form-item prop="password">
          <w-input
            v-model="formData.password"
            type="password"
            :prefix-icon="Lock"
            show-password
            placeholder="{{ $t('login.passwordPlaceholder') }}"
          />
        </w-form-item>

        <w-form-item>
          <w-checkbox v-model="formData.remember">{{ $t('login.rememberMe') }}</w-checkbox>
        </w-form-item>

        <w-form-item>
          <w-button
            type="primary"
            :loading="loading"
            class="login-button"
            @click="handleLogin"
          >
            {{ $t('login.submit') }}
          </w-button>
        </w-form-item>
      </w-form>
    </div>

    <div class="login-footer">
      Copyright © {{ new Date().getFullYear() }} Winning Health
    </div>
  </div>
</template>
```

### 设计规范

- 登录框居中显示
- Logo 尺寸：120px × 40px（推荐）
- 登录按钮宽度：100%
- 输入框高度：40px（推荐）
- 支持多语言切换
- 支持主题切换

---

## 表格列表页

### 标准结构

```
表格列表页组件结构：
├── 查询区域（w-card）
│   ├── 查询表单（w-form）
│   ├── 查询按钮
│   └── 重置按钮
├── 操作区域（toolbar）
│   ├── 新增按钮
│   ├── 批量操作按钮（可选）
│   └── 导入导出按钮（可选）
├── 数据表格（w-table）
│   ├── 选择列（可选）
│   ├── 序号列
│   ├── 数据列
│   └── 操作列
└── 分页组件（w-pagination）
```

### 核心代码片段

```vue
<template>
  <div class="list-page">
    <!-- 查询区域 -->
    <w-card class="search-card">
      <w-form :model="queryParams" inline>
        <w-form-item label="{{ $t('common.keyword') }}">
          <w-input v-model="queryParams.keyword" placeholder="请输入" clearable />
        </w-form-item>
        <w-form-item label="{{ $t('common.status') }}">
          <w-select v-model="queryParams.status" placeholder="请选择" clearable>
            <w-option label="启用" value="active" />
            <w-option label="禁用" value="inactive" />
          </w-select>
        </w-form-item>
        <w-form-item>
          <w-button type="primary" @click="handleSearch">{{ $t('common.search') }}</w-button>
          <w-button @click="handleReset">{{ $t('common.reset') }}</w-button>
        </w-form-item>
      </w-form>
    </w-card>

    <!-- 操作区域 -->
    <div class="toolbar">
      <w-button type="primary" @click="handleAdd">{{ $t('common.add') }}</w-button>
      <w-button type="danger" :disabled="!selectedRows.length" @click="handleBatchDelete">
        {{ $t('common.batchDelete') }}
      </w-button>
    </div>

    <!-- 数据表格 -->
    <w-card class="table-card">
      <w-table
        ref="tableRef"
        :data="tableData"
        :loading="loading"
        row-key="id"
        @selection-change="handleSelectionChange"
      >
        <w-table-column type="selection" width="55" />
        <w-table-column type="index" label="{{ $t('common.index') }}" width="60" />
        <w-table-column prop="name" label="{{ $t('common.name') }}" />
        <w-table-column prop="status" label="{{ $t('common.status') }}">
          <template #default="{ row }">
            <w-tag :type="row.status === 'active' ? 'success' : 'danger'">
              {{ row.status === 'active' ? $t('common.active') : $t('common.inactive') }}
            </w-tag>
          </template>
        </w-table-column>
        <w-table-column label="{{ $t('common.operation') }}" width="200" fixed="right">
          <template #default="{ row }">
            <w-button size="small" @click="handleEdit(row)">{{ $t('common.edit') }}</w-button>
            <w-button size="small" type="danger" @click="handleDelete(row)">{{ $t('common.delete') }}</w-button>
          </template>
        </w-table-column>
      </w-table>

      <!-- 分页 -->
      <w-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :total="total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
      />
    </w-card>
  </div>
</template>
```

### 设计规范

- 查询区域卡片样式
- 查询表单 inline 布局
- 表格行高：48px（推荐）
- 操作按钮固定在右侧
- 分页显示在表格下方

---

## 表单录入页

### 标准结构

```
表单录入页组件结构：
├── 页面标题
├── 表单区域（w-form）
│   ├── 字段分组（w-divider）
│   ├── 表单项（w-form-item）
│   └── 提交/重置按钮
└── 返回按钮（可选）
```

### 核心代码片段

```vue
<template>
  <div class="form-page">
    <w-card>
      <template #header>
        <div class="card-header">
          <span>{{ isEdit ? $t('common.edit') : $t('common.add') }}{{ $t('user.title') }}</span>
          <w-button @click="handleBack">{{ $t('common.back') }}</w-button>
        </div>
      </template>

      <w-form ref="formRef" :model="formData" :rules="rules" label-width="100px">
        <!-- 基本信息 -->
        <w-divider content-position="left">{{ $t('user.basicInfo') }}</w-divider>
        <w-row :gutter="20">
          <w-col :span="12">
            <w-form-item label="{{ $t('user.username') }}" prop="username">
              <w-input v-model="formData.username" />
            </w-form-item>
          </w-col>
          <w-col :span="12">
            <w-form-item label="{{ $t('user.realName') }}" prop="realName">
              <w-input v-model="formData.realName" />
            </w-form-item>
          </w-col>
        </w-row>

        <!-- 联系方式 -->
        <w-divider content-position="left">{{ $t('user.contactInfo') }}</w-divider>
        <w-row :gutter="20">
          <w-col :span="12">
            <w-form-item label="{{ $t('user.email') }}" prop="email">
              <w-input v-model="formData.email" />
            </w-form-item>
          </w-col>
          <w-col :span="12">
            <w-form-item label="{{ $t('user.phone') }}" prop="phone">
              <w-input v-model="formData.phone" />
            </w-form-item>
          </w-col>
        </w-row>

        <w-form-item>
          <w-button type="primary" :loading="submitting" @click="handleSubmit">
            {{ $t('common.submit') }}
          </w-button>
          <w-button @click="handleReset">{{ $t('common.reset') }}</w-button>
        </w-form-item>
      </w-form>
    </w-card>
  </div>
</template>
```

---

## 详情页

### 标准结构

```
详情页组件结构：
├── 页面标题
├── 信息描述区域（w-descriptions）
│   ├── 基本信息组
│   ├── 其他信息组
├── 操作按钮区域
└── 关联数据列表（可选）
```

### 核心代码片段

```vue
<template>
  <div class="detail-page">
    <w-card>
      <template #header>
        <div class="card-header">
          <span>{{ $t('user.detail') }}</span>
          <div>
            <w-button type="primary" @click="handleEdit">{{ $t('common.edit') }}</w-button>
            <w-button @click="handleBack">{{ $t('common.back') }}</w-button>
          </div>
        </div>
      </template>

      <!-- 基本信息 -->
      <w-divider content-position="left">{{ $t('user.basicInfo') }}</w-divider>
      <w-descriptions :column="3" border>
        <w-descriptions-item label="{{ $t('user.username') }}">{{ detail.username }}</w-descriptions-item>
        <w-descriptions-item label="{{ $t('user.realName') }}">{{ detail.realName }}</w-descriptions-item>
        <w-descriptions-item label="{{ $t('common.status') }}">
          <w-tag :type="detail.status === 'active' ? 'success' : 'danger'">
            {{ detail.status === 'active' ? $t('common.active') : $t('common.inactive') }}
          </w-tag>
        </w-descriptions-item>
      </w-descriptions>

      <!-- 联系方式 -->
      <w-divider content-position="left">{{ $t('user.contactInfo') }}</w-divider>
      <w-descriptions :column="2" border>
        <w-descriptions-item label="{{ $t('user.email') }}">{{ detail.email }}</w-descriptions-item>
        <w-descriptions-item label="{{ $t('user.phone') }}">{{ detail.phone }}</w-descriptions-item>
      </w-descriptions>

      <!-- 时间信息 -->
      <w-divider content-position="left">{{ $t('common.timeInfo') }}</w-divider>
      <w-descriptions :column="2" border>
        <w-descriptions-item label="{{ $t('common.createTime') }}">{{ detail.createTime }}</w-descriptions-item>
        <w-descriptions-item label="{{ $t('common.updateTime') }}">{{ detail.updateTime }}</w-descriptions-item>
      </w-descriptions>
    </w-card>
  </div>
</template>
```

---

## Dashboard 看板

### 标准结构

```
Dashboard 组件结构：
├── 统计卡片区（w-row + w-col）
│   ├── 统计卡片1
│   ├── 统计卡片2
│   ├── 统计卡片3
│   └── 统计卡片4
├── 图表区域
│   ├── 柱状图/折线图
│   ├── 饼图/环形图
└── 数据列表区域（可选）
```

### 核心代码片段

```vue
<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <w-row :gutter="20">
      <w-col :span="6">
        <w-card class="stat-card">
          <div class="stat-value">{{ stats.totalUsers }}</div>
          <div class="stat-label">{{ $t('dashboard.totalUsers') }}</div>
        </w-card>
      </w-col>
      <w-col :span="6">
        <w-card class="stat-card">
          <div class="stat-value">{{ stats.activeUsers }}</div>
          <div class="stat-label">{{ $t('dashboard.activeUsers') }}</div>
        </w-card>
      </w-col>
      <w-col :span="6">
        <w-card class="stat-card">
          <div class="stat-value">{{ stats.todayVisits }}</div>
          <div class="stat-label">{{ $t('dashboard.todayVisits') }}</div>
        </w-card>
      </w-col>
      <w-col :span="6">
        <w-card class="stat-card">
          <div class="stat-value">{{ stats.pendingTasks }}</div>
          <div class="stat-label">{{ $t('dashboard.pendingTasks') }}</div>
        </w-card>
      </w-col>
    </w-row>

    <!-- 图表区域 -->
    <w-row :gutter="20" class="chart-row">
      <w-col :span="8">
        <w-card>
          <template #header>{{ $t('dashboard.userDistribution') }}</template>
          <div ref="pieChartRef" class="chart-container"></div>
        </w-card>
      </w-col>
      <w-col :span="16">
        <w-card>
          <template #header>{{ $t('dashboard.visitTrend') }}</template>
          <div ref="lineChartRef" class="chart-container"></div>
        </w-card>
      </w-col>
    </w-row>
  </div>
</template>

<style scoped>
.stat-card {
  text-align: center;
}
.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #2D5AFA;
}
.stat-label {
  font-size: 14px;
  color: #666;
}
.chart-container {
  height: 300px;
}
</style>
```

---

## 弹窗表单

### 标准结构

```
弹窗表单组件结构：
├── 触发按钮
└── 弹窗（w-dialog）
    ├── 弹窗标题
    ├── 表单区域（w-form）
    └── 底部按钮（footer）
```

### 核心代码片段

```vue
<template>
  <div>
    <w-button type="primary" @click="handleAdd">{{ $t('common.add') }}</w-button>

    <w-dialog v-model="dialogVisible" :title="dialogTitle" width="640px">
      <w-form ref="formRef" :model="formData" :rules="rules" label-width="100px">
        <w-form-item label="{{ $t('user.username') }}" prop="username">
          <w-input v-model="formData.username" />
        </w-form-item>
        <w-form-item label="{{ $t('user.email') }}" prop="email">
          <w-input v-model="formData.email" />
        </w-form-item>
        <w-form-item label="{{ $t('common.status') }}" prop="status">
          <w-select v-model="formData.status">
            <w-option label="{{ $t('common.active') }}" value="active" />
            <w-option label="{{ $t('common.inactive') }}" value="inactive" />
          </w-select>
        </w-form-item>
      </w-form>

      <template #footer>
        <w-button @click="handleCancel">{{ $t('common.cancel') }}</w-button>
        <w-button type="primary" :loading="submitting" @click="handleConfirm">
          {{ $t('common.confirm') }}
        </w-button>
      </template>
    </w-dialog>
  </div>
</template>
```

### 弹窗尺寸规范

| 尺寸 | 宽度 | 适用场景 |
|------|------|----------|
| 小 | 480px | 简单表单、确认提示 |
| 中 | 640px | 标准表单 |
| 大 | 1000px | 复杂表单、多 Tab |
| 百分比中 | 50% | 大屏表单 |
| 百分比大 | 85% | 全屏编辑 |

---

## 组合式函数封装

### useDialog 弹窗管理

```typescript
// composables/useDialog.ts
import { ref } from 'spark';

interface DialogOptions {
  mode?: 'add' | 'edit';
  data?: any;
}

export function useDialog() {
  const visible = ref(false);
  const mode = ref<'add' | 'edit'>('add');
  const data = ref<any>(null);

  const open = (options: DialogOptions = {}) => {
    mode.value = options.mode || 'add';
    data.value = options.data ? { ...options.data } : null;
    visible.value = true;
  };

  const close = () => {
    visible.value = false;
    data.value = null;
  };

  const title = computed(() => {
    return mode.value === 'add' ? t('common.add') : t('common.edit');
  });

  return { visible, mode, data, open, close, title };
}
```

### useListPage 列表页管理

```typescript
// composables/useListPage.ts
import { ref, reactive } from 'spark';
import { request } from 'spark';

export function useListPage<T>(url: string) {
  const loading = ref(false);
  const tableData = ref<T[]>([]);
  const total = ref(0);
  const currentPage = ref(1);
  const pageSize = ref(10);
  const queryParams = reactive({});
  const selectedRows = ref<T[]>([]);

  const fetchData = async () => {
    loading.value = true;
    try {
      const result = await request({
        url,
        data: {
          page: currentPage.value,
          pageSize: pageSize.value,
          ...queryParams
        }
      });
      tableData.value = result.data;
      total.value = result.total;
    } finally {
      loading.value = false;
    }
  };

  const handleSearch = () => {
    currentPage.value = 1;
    fetchData();
  };

  const handleReset = () => {
    Object.keys(queryParams).forEach(key => queryParams[key] = '');
    handleSearch();
  };

  const handleSelectionChange = (rows: T[]) => {
    selectedRows.value = rows;
  };

  return {
    loading,
    tableData,
    total,
    currentPage,
    pageSize,
    queryParams,
    selectedRows,
    fetchData,
    handleSearch,
    handleReset,
    handleSelectionChange
  };
}
```