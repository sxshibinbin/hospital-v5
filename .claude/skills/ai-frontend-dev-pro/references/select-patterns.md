# 选择器高级模式

> 详细说明复杂选择器场景的实现方式，包含远程搜索、分组选项、多选全选、树形选择等。

## 目录

- [基础选择器](#基础选择器)
- [远程搜索选择器](#远程搜索选择器)
- [分组选项选择器](#分组选项选择器)
- [多选与全选](#多选与全选)
- [树形选择器](#树形选择器)
- [级联选择器](#级联选择器)
- [自定义选项模板](#自定义选项模板)
- [创建新选项](#创建新选项)
- [选择器最佳实践](#选择器最佳实践)

---

## 基础选择器

### Vue 3 + Spark 实现

```vue
<template>
  <w-select v-model="value" placeholder="请选择" clearable>
    <w-option label="选项一" value="1" />
    <w-option label="选项二" value="2" />
    <w-option label="选项三" value="3" />
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';

const value = ref('');
</script>
```

---

## 远程搜索选择器

### 场景：数据量大或需要从服务器搜索

```vue
<template>
  <w-select
    v-model="value"
    filterable
    remote
    :remote-method="remoteMethod"
    :loading="loading"
    placeholder="请输入关键词搜索"
    clearable
  >
    <w-option
      v-for="item in options"
      :key="item.value"
      :label="item.label"
      :value="item.value"
    />
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';
import { request } from 'spark';

interface Option {
  value: string;
  label: string;
}

const value = ref('');
const loading = ref(false);
const options = ref<Option[]>([]);

const remoteMethod = async (query: string) => {
  if (!query) {
    options.value = [];
    return;
  }

  loading.value = true;
  try {
    const result = await request({
      url: '/api/search',
      data: { keyword: query }
    });
    options.value = result.data.map(item => ({
      value: item.id,
      label: item.name
    }));
  } finally {
    loading.value = false;
  }
};
</script>
```

---

## 分组选项选择器

### 场景：选项按类别分组展示

```vue
<template>
  <w-select v-model="value" placeholder="请选择城市">
    <w-option-group label="热门城市">
      <w-option label="北京" value="beijing" />
      <w-option label="上海" value="shanghai" />
      <w-option label="广州" value="guangzhou" />
      <w-option label="深圳" value="shenzhen" />
    </w-option-group>
    <w-option-group label="其他城市">
      <w-option label="杭州" value="hangzhou" />
      <w-option label="南京" value="nanjing" />
      <w-option label="成都" value="chengdu" />
    </w-option-group>
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';

const value = ref('');
</script>
```

---

## 多选与全选

### 场景：支持多选和全选功能

```vue
<template>
  <w-select
    v-model="values"
    multiple
    collapse-tags
    collapse-tags-tooltip
    placeholder="请选择"
    :max-collapse-tags="3"
  >
    <w-option label="选项一" value="1" />
    <w-option label="选项二" value="2" />
    <w-option label="选项三" value="3" />
    <w-option label="选项四" value="4" />
    <w-option label="选项五" value="5" />
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';

const values = ref<string[]>([]);
</script>
```

### 全选功能实现

```vue
<template>
  <div>
    <!-- 全选复选框 -->
    <w-checkbox
      v-model="checkAll"
      :indeterminate="isIndeterminate"
      @change="handleCheckAllChange"
    >
      全选
    </w-checkbox>

    <!-- 多选下拉框 -->
    <w-select
      v-model="values"
      multiple
      placeholder="请选择"
      @change="handleCheckedChange"
    >
      <w-option
        v-for="item in allOptions"
        :key="item.value"
        :label="item.label"
        :value="item.value"
      />
    </w-select>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'spark';

interface Option {
  value: string;
  label: string;
}

const allOptions = ref<Option[]>([
  { value: '1', label: '选项一' },
  { value: '2', label: '选项二' },
  { value: '3', label: '选项三' },
  { value: '4', label: '选项四' }
]);

const values = ref<string[]>([]);
const checkAll = ref(false);
const isIndeterminate = ref(false);

const allValues = computed(() => allOptions.value.map(item => item.value));

const handleCheckAllChange = (val: boolean) => {
  values.value = val ? allValues.value : [];
  isIndeterminate.value = false;
};

const handleCheckedChange = (val: string[]) => {
  const checkedCount = val.length;
  checkAll.value = checkedCount === allOptions.value.length;
  isIndeterminate.value = checkedCount > 0 && checkedCount < allOptions.value.length;
};
</script>
```

---

## 树形选择器

### 场景：选择层级结构数据

```vue
<template>
  <w-tree-select
    v-model="value"
    :data="treeData"
    :props="defaultProps"
    check-strictly
    filterable
    placeholder="请选择组织"
    clearable
  />
</template>

<script setup lang="ts">
import { ref } from 'spark';

interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
}

const value = ref('');
const defaultProps = {
  children: 'children',
  label: 'label',
  value: 'id'
};

const treeData = ref<TreeNode[]>([
  {
    id: '1',
    label: '组织1',
    children: [
      { id: '1-1', label: '部门1' },
      { id: '1-2', label: '部门2' }
    ]
  },
  {
    id: '2',
    label: '组织2',
    children: [
      { id: '2-1', label: '部门3' },
      { id: '2-2', label: '部门4' }
    ]
  }
]);
</script>
```

---

## 级联选择器

### 场景：多级联动选择

```vue
<template>
  <w-cascader
    v-model="value"
    :options="options"
    :props="cascaderProps"
    placeholder="请选择地区"
    clearable
    filterable
  />
</template>

<script setup lang="ts">
import { ref } from 'spark';

interface CascaderOption {
  value: string;
  label: string;
  children?: CascaderOption[];
}

const value = ref<string[]>([]);
const cascaderProps = {
  expandTrigger: 'hover',
  emitPath: false // 只返回最后一级的值
};

const options = ref<CascaderOption[]>([
  {
    value: 'beijing',
    label: '北京',
    children: [
      { value: 'haidian', label: '海淀区' },
      { value: 'chaoyang', label: '朝阳区' }
    ]
  },
  {
    value: 'shanghai',
    label: '上海',
    children: [
      { value: 'pudong', label: '浦东新区' },
      { value: 'jingan', label: '静安区' }
    ]
  }
]);
</script>
```

---

## 自定义选项模板

### 场景：选项显示额外信息

```vue
<template>
  <w-select v-model="value" placeholder="请选择用户" filterable>
    <w-option
      v-for="item in users"
      :key="item.id"
      :label="item.name"
      :value="item.id"
    >
      <!-- 自定义选项模板 -->
      <div class="custom-option">
        <span class="name">{{ item.name }}</span>
        <span class="email">{{ item.email }}</span>
      </div>
    </w-option>
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';

interface User {
  id: string;
  name: string;
  email: string;
}

const value = ref('');
const users = ref<User[]>([
  { id: '1', name: '张三', email: 'zhangsan@example.com' },
  { id: '2', name: '李四', email: 'lisi@example.com' },
  { id: '3', name: '王五', email: 'wangwu@example.com' }
]);
</script>

<style scoped>
.custom-option {
  display: flex;
  justify-content: space-between;
}
.name {
  font-weight: bold;
}
.email {
  color: #999;
  font-size: 12px;
}
</style>
```

---

## 创建新选项

### 场景：允许用户创建不存在的新选项

```vue
<template>
  <w-select
    v-model="value"
    filterable
    allow-create
    default-first-option
    placeholder="请选择或输入新标签"
  >
    <w-option
      v-for="item in options"
      :key="item.value"
      :label="item.label"
      :value="item.value"
    />
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';

const value = ref('');
const options = ref([
  { value: 'tag1', label: '标签1' },
  { value: 'tag2', label: '标签2' }
]);
</script>
```

---

## 选择器最佳实践

### 1. 远程搜索防抖

```vue
<template>
  <w-select
    v-model="value"
    filterable
    remote
    :remote-method="debouncedRemoteMethod"
    :loading="loading"
    placeholder="请输入关键词搜索"
  >
    <w-option v-for="item in options" :key="item.value" :label="item.label" :value="item.value" />
  </w-select>
</template>

<script setup lang="ts">
import { ref } from 'spark';
import { utils } from 'spark';

const value = ref('');
const loading = ref(false);
const options = ref([]);

// 使用 dayjs 或 lodash 进行防抖
const debouncedRemoteMethod = utils.debounce(async (query: string) => {
  if (!query) return;
  loading.value = true;
  try {
    // 搜索逻辑
  } finally {
    loading.value = false;
  }
}, 300);
</script>
```

### 2. 选择器联动

```vue
<template>
  <w-form :model="formData">
    <!-- 省份选择 -->
    <w-form-item label="省份">
      <w-select v-model="formData.province" @change="handleProvinceChange" placeholder="请选择省份">
        <w-option v-for="item in provinces" :key="item.value" :label="item.label" :value="item.value" />
      </w-select>
    </w-form-item>

    <!-- 城市选择（联动） -->
    <w-form-item label="城市">
      <w-select v-model="formData.city" :disabled="!formData.province" placeholder="请选择城市">
        <w-option v-for="item in cities" :key="item.value" :label="item.label" :value="item.value" />
      </w-select>
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'spark';

const formData = reactive({
  province: '',
  city: ''
});

const provinces = ref([{ value: 'beijing', label: '北京' }, { value: 'shanghai', label: '上海' }]);
const cities = ref([]);

const handleProvinceChange = async (province: string) => {
  formData.city = ''; // 清空城市
  // 根据省份获取城市列表
  const result = await request({ url: `/api/cities/${province}` });
  cities.value = result.data;
};
</script>
```

### 3. 大数据量选择器

```vue
<template>
  <!-- 数据量大于 1000 时使用虚拟滚动 -->
  <w-select-v2
    v-model="value"
    :options="options"
    :height="200"
    placeholder="请选择"
    filterable
  />
</template>

<script setup lang="ts">
import { ref } from 'spark';

const value = ref('');
const options = ref(Array.from({ length: 10000 }, (_, i) => ({
  value: String(i),
  label: `选项 ${i + 1}`
})));
</script>
```

### 4. 选择器下拉表格

```vue
<template>
  <w-table-select
    v-model="value"
    :columns="columns"
    :data="tableData"
    placeholder="请选择"
    :table-width="500"
    row-key="id"
  />
</template>

<script setup lang="ts">
import { ref } from 'spark';

const value = ref('');
const columns = [
  { prop: 'name', label: '名称' },
  { prop: 'code', label: '编码' },
  { prop: 'status', label: '状态' }
];
const tableData = ref([
  { id: '1', name: '项目1', code: 'P001', status: '启用' },
  { id: '2', name: '项目2', code: 'P002', status: '启用' }
]);
</script>
```