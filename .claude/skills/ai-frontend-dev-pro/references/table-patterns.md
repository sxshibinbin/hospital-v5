# 表格高级模式

> 详细说明复杂表格场景的实现方式，包含服务端分页、行选择、可展开行、树形表格等。

## 目录

- [基础表格](#基础表格)
- [服务端分页排序](#服务端分页排序)
- [行选择与批量操作](#行选择与批量操作)
- [可展开行](#可展开行)
- [树形表格](#树形表格)
- [固定列与固定表头](#固定列与固定表头)
- [合并单元格](#合并单元格)
- [表格最佳实践](#表格最佳实践)

---

## 基础表格

### Vue 3 + Spark 实现

```vue
<template>
  <w-table
    :data="tableData"
    :loading="loading"
    stripe
    border
    row-key="id"
  >
    <w-table-column type="index" label="序号" width="60" />
    <w-table-column prop="username" label="用户名" width="120" />
    <w-table-column prop="email" label="邮箱" width="200" />
    <w-table-column prop="status" label="状态" width="100">
      <template #default="{ row }">
        <w-tag :type="row.status === 'active' ? 'success' : 'danger'">
          {{ row.status === 'active' ? '启用' : '禁用' }}
        </w-tag>
      </template>
    </w-table-column>
    <w-table-column prop="createTime" label="创建时间" width="180" />
    <w-table-column label="操作" width="200" fixed="right">
      <template #default="{ row }">
        <w-button size="small" @click="handleEdit(row)">编辑</w-button>
        <w-button size="small" type="danger" @click="handleDelete(row)">删除</w-button>
      </template>
    </w-table-column>
  </w-table>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'spark';

interface User {
  id: string;
  username: string;
  email: string;
  status: string;
  createTime: string;
}

const loading = ref(false);
const tableData = ref<User[]>([]);

const fetchData = async () => {
  loading.value = true;
  try {
    // 调用 API
    const result = await request({ url: '/api/user/list' });
    tableData.value = result.data;
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchData();
});
</script>
```

---

## 服务端分页排序

### 场景：数据量大，需要服务端分页

```vue
<template>
  <w-table
    :data="tableData"
    :loading="loading"
    stripe
    border
    row-key="id"
    @sort-change="handleSortChange"
  >
    <w-table-column type="index" label="序号" width="60" />
    <w-table-column prop="username" label="用户名" sortable="custom" />
    <w-table-column prop="createTime" label="创建时间" sortable="custom" />
    <w-table-column label="操作" width="200" />
  </w-table>

  <w-pagination
    v-model:current-page="currentPage"
    v-model:page-size="pageSize"
    :total="total"
    :page-sizes="[10, 20, 50, 100]"
    layout="total, sizes, prev, pager, next, jumper"
    @size-change="handleSizeChange"
    @current-change="handleCurrentChange"
  />
</template>

<script setup lang="ts">
import { ref, onMounted } from 'spark';
import { request } from 'spark';

interface QueryParams {
  page: number;
  pageSize: number;
  sortField?: string;
  sortOrder?: string;
}

const loading = ref(false);
const tableData = ref([]);
const currentPage = ref(1);
const pageSize = ref(10);
const total = ref(0);
const sortField = ref('');
const sortOrder = ref('');

const fetchData = async () => {
  loading.value = true;
  try {
    const params: QueryParams = {
      page: currentPage.value,
      pageSize: pageSize.value
    };
    if (sortField.value) {
      params.sortField = sortField.value;
      params.sortOrder = sortOrder.value;
    }

    const result = await request({
      url: '/api/user/list',
      data: params
    });
    tableData.value = result.data;
    total.value = result.total;
  } finally {
    loading.value = false;
  }
};

const handleSortChange = ({ prop, order }: any) => {
  sortField.value = prop;
  sortOrder.value = order === 'ascending' ? 'asc' : 'desc';
  fetchData();
};

const handleSizeChange = (val: number) => {
  pageSize.value = val;
  fetchData();
};

const handleCurrentChange = (val: number) => {
  currentPage.value = val;
  fetchData();
};

onMounted(() => {
  fetchData();
});
</script>
```

---

## 行选择与批量操作

### 场景：多选行并批量操作

```vue
<template>
  <!-- 操作按钮 -->
  <div class="toolbar">
    <w-button type="primary" @click="handleBatchEdit" :disabled="!selectedRows.length">
      批量编辑
    </w-button>
    <w-button type="danger" @click="handleBatchDelete" :disabled="!selectedRows.length">
      批量删除
    </w-button>
  </div>

  <!-- 表格 -->
  <w-table
    ref="tableRef"
    :data="tableData"
    :loading="loading"
    @selection-change="handleSelectionChange"
    row-key="id"
  >
    <w-table-column type="selection" width="55" />
    <w-table-column type="index" label="序号" width="60" />
    <w-table-column prop="username" label="用户名" />
    <w-table-column prop="status" label="状态" />
  </w-table>
</template>

<script setup lang="ts">
import { ref } from 'spark';
import type { TableInstance } from 'spark';
import { MessageBox, Message } from 'spark';

interface User {
  id: string;
  username: string;
  status: string;
}

const tableRef = ref<TableInstance>();
const loading = ref(false);
const tableData = ref<User[]>([]);
const selectedRows = ref<User[]>([]);

const handleSelectionChange = (rows: User[]) => {
  selectedRows.value = rows;
};

const handleBatchEdit = () => {
  if (!selectedRows.value.length) {
    Message.warning('请选择要编辑的数据');
    return;
  }
  // 批量编辑逻辑
};

const handleBatchDelete = async () => {
  if (!selectedRows.value.length) {
    Message.warning('请选择要删除的数据');
    return;
  }

  try {
    await MessageBox.confirm(
      `确定要删除选中的 ${selectedRows.value.length} 条数据吗？`,
      '提示',
      { type: 'warning' }
    );

    loading.value = true;
    const ids = selectedRows.value.map(row => row.id);
    await request({
      url: '/api/user/batchDelete',
      data: { ids },
      method: 'POST'
    });

    Message.success('批量删除成功');
    // 刷新列表
    fetchData();
    // 清空选择
    tableRef.value?.clearSelection();
  } catch {
    // 取消删除
  } finally {
    loading.value = false;
  }
};
</script>
```

---

## 可展开行

### 场景：显示详细信息

```vue
<template>
  <w-table
    :data="tableData"
    :loading="loading"
    row-key="id"
  >
    <!-- 展开列 -->
    <w-table-column type="expand">
      <template #default="{ row }">
        <div class="expand-content">
          <w-descriptions :column="3" border>
            <w-descriptions-item label="详细描述">
              {{ row.description }}
            </w-descriptions-item>
            <w-descriptions-item label="创建人">
              {{ row.creator }}
            </w-descriptions-item>
            <w-descriptions-item label="更新时间">
              {{ row.updateTime }}
            </w-descriptions-item>
          </w-descriptions>
        </div>
      </template>
    </w-table-column>

    <w-table-column prop="name" label="名称" />
    <w-table-column prop="status" label="状态" />
  </w-table>
</template>

<style scoped>
.expand-content {
  padding: 20px;
}
</style>
```

---

## 树形表格

### 场景：层级数据展示

```vue
<template>
  <w-table
    :data="tableData"
    :loading="loading"
    row-key="id"
    :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
    default-expand-all
  >
    <w-table-column prop="name" label="名称" />
    <w-table-column prop="type" label="类型" />
    <w-table-column prop="status" label="状态" />
    <w-table-column label="操作" width="200">
      <template #default="{ row }">
        <w-button size="small" @click="handleEdit(row)">编辑</w-button>
        <w-button size="small" type="primary" @click="handleAddChild(row)">添加子节点</w-button>
      </template>
    </w-table-column>
  </w-table>
</template>

<script setup lang="ts">
import { ref } from 'spark';

interface TreeNode {
  id: string;
  name: string;
  type: string;
  status: string;
  children?: TreeNode[];
  hasChildren?: boolean;
}

const tableData = ref<TreeNode[]>([
  {
    id: '1',
    name: '组织1',
    type: '组织',
    status: 'active',
    children: [
      {
        id: '1-1',
        name: '部门1',
        type: '部门',
        status: 'active'
      },
      {
        id: '1-2',
        name: '部门2',
        type: '部门',
        status: 'inactive'
      }
    ]
  }
]);
</script>
```

---

## 固定列与固定表头

### 场景：表格列多，需要固定关键列

```vue
<template>
  <w-table
    :data="tableData"
    :loading="loading"
    height="400"
    border
    row-key="id"
  >
    <!-- 固定左侧列 -->
    <w-table-column prop="username" label="用户名" width="120" fixed="left" />

    <!-- 滚动区域列 -->
    <w-table-column prop="field1" label="字段1" width="150" />
    <w-table-column prop="field2" label="字段2" width="150" />
    <w-table-column prop="field3" label="字段3" width="150" />
    <w-table-column prop="field4" label="字段4" width="150" />
    <w-table-column prop="field5" label="字段5" width="150" />

    <!-- 固定右侧列（操作列） -->
    <w-table-column label="操作" width="200" fixed="right">
      <template #default="{ row }">
        <w-button size="small" @click="handleEdit(row)">编辑</w-button>
        <w-button size="small" type="danger" @click="handleDelete(row)">删除</w-button>
      </template>
    </w-table-column>
  </w-table>
</template>
```

---

## 合并单元格

### 场景：按字段值合并行

```vue
<template>
  <w-table
    :data="tableData"
    :span-method="objectSpanMethod"
    border
  >
    <w-table-column prop="region" label="区域" />
    <w-table-column prop="city" label="城市" />
    <w-table-column prop="name" label="名称" />
    <w-table-column prop="value" label="数值" />
  </w-table>
</template>

<script setup lang="ts">
import { ref } from 'spark';

interface RowData {
  region: string;
  city: string;
  name: string;
  value: number;
}

const tableData = ref<RowData[]>([
  { region: '华东', city: '上海', name: '项目1', value: 100 },
  { region: '华东', city: '上海', name: '项目2', value: 200 },
  { region: '华东', city: '杭州', name: '项目3', value: 150 },
  { region: '华北', city: '北京', name: '项目4', value: 300 },
  { region: '华北', city: '北京', name: '项目5', value: 250 }
]);

// 计算合并信息
const getSpanArr = (data: RowData[], prop: string) => {
  const spanArr: number[] = [];
  let pos = 0;

  data.forEach((item, index) => {
    if (index === 0) {
      spanArr.push(1);
      pos = 0;
    } else {
      if (item[prop] === data[index - 1][prop]) {
        spanArr[pos] += 1;
        spanArr.push(0);
      } else {
        spanArr.push(1);
        pos = index;
      }
    }
  });

  return spanArr;
};

const regionSpan = getSpanArr(tableData.value, 'region');

const objectSpanMethod = ({ row, column, rowIndex, columnIndex }: any) => {
  // 合并区域列
  if (columnIndex === 0) {
    const span = regionSpan[rowIndex];
    return {
      rowspan: span,
      colspan: span > 0 ? 1 : 0
    };
  }
};
</script>
```

---

## 表格最佳实践

### 1. 使用组合式函数封装表格逻辑

```typescript
// composables/useTable.ts
import { ref, reactive } from 'spark';
import { request } from 'spark';

interface TableOptions {
  url: string;
  pageSize?: number;
}

export function useTable<T>(options: TableOptions) {
  const loading = ref(false);
  const data = ref<T[]>([]);
  const total = ref(0);
  const currentPage = ref(1);
  const pageSize = ref(options.pageSize || 10);
  const queryParams = reactive({});

  const fetchData = async () => {
    loading.value = true;
    try {
      const result = await request({
        url: options.url,
        data: {
          page: currentPage.value,
          pageSize: pageSize.value,
          ...queryParams
        }
      });
      data.value = result.data;
      total.value = result.total;
    } finally {
      loading.value = false;
    }
  };

  const handleSizeChange = (val: number) => {
    pageSize.value = val;
    fetchData();
  };

  const handleCurrentChange = (val: number) => {
    currentPage.value = val;
    fetchData();
  };

  const setQueryParams = (params: object) => {
    Object.assign(queryParams, params);
    currentPage.value = 1;
    fetchData();
  };

  const refresh = () => {
    fetchData();
  };

  return {
    loading,
    data,
    total,
    currentPage,
    pageSize,
    fetchData,
    handleSizeChange,
    handleCurrentChange,
    setQueryParams,
    refresh
  };
}
```

### 2. 表格列配置缓存

```vue
<template>
  <w-table :data="tableData" :columns="columns">
    <!-- 使用 columns 配置 -->
  </w-table>
</template>

<script setup lang="ts">
import { computed, ref } from 'spark';

// 将 columns 定义为 computed，避免每次渲染重新创建
const columns = computed(() => [
  { type: 'index', label: '序号', width: 60 },
  { prop: 'username', label: '用户名', width: 120 },
  { prop: 'email', label: '邮箱', width: 200 },
  { prop: 'status', label: '状态', width: 100 },
  { label: '操作', width: 200, fixed: 'right' }
]);
</script>
```

### 3. 表格性能优化

```vue
<template>
  <!-- 大数据量时使用虚拟滚动 -->
  <w-table-v2
    :columns="columns"
    :data="tableData"
    :width="800"
    :height="400"
    :row-height="50"
    fixed
  />
</template>
```

### 4. 表格空状态处理

```vue
<template>
  <w-table :data="tableData" :loading="loading">
    <!-- 空状态插槽 -->
    <template #empty>
      <w-empty description="暂无数据">
        <w-button type="primary" @click="handleAdd">添加数据</w-button>
      </w-empty>
    </template>
  </w-table>
</template>
```