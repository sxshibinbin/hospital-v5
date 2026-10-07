# 表单高级模式

> 详细说明复杂表单场景的实现方式，包含动态表单、跨字段校验、分步表单、异步校验等。

## 目录

- [基础表单](#基础表单)
- [动态表单](#动态表单)
- [跨字段联动校验](#跨字段联动校验)
- [异步校验](#异步校验)
- [分步表单](#分步表单)
- [表单弹窗](#表单弹窗)
- [表单最佳实践](#表单最佳实践)

---

## 基础表单

### Vue 3 + Spark 实现

```vue
<template>
  <w-form
    ref="formRef"
    :model="formData"
    :rules="rules"
    label-width="100px"
  >
    <w-form-item label="用户名" prop="username">
      <w-input v-model="formData.username" placeholder="请输入用户名" />
    </w-form-item>

    <w-form-item label="邮箱" prop="email">
      <w-input v-model="formData.email" placeholder="请输入邮箱" />
    </w-form-item>

    <w-form-item label="手机号" prop="phone">
      <w-input v-model="formData.phone" placeholder="请输入手机号" />
    </w-form-item>

    <w-form-item>
      <w-button type="primary" @click="handleSubmit">提交</w-button>
      <w-button @click="handleReset">重置</w-button>
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { ref, reactive } from 'spark';
import type { FormInstance, FormRules } from 'spark';

const formRef = ref<FormInstance>();

const formData = reactive({
  username: '',
  email: '',
  phone: ''
});

const rules = reactive<FormRules>({
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '长度在 3 到 20 个字符', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '请输入正确的邮箱地址', trigger: 'blur' }
  ],
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }
  ]
});

const handleSubmit = async () => {
  if (!formRef.value) return;
  await formRef.value.validate();
  // 提交逻辑
};

const handleReset = () => {
  formRef.value?.resetFields();
};
</script>
```

---

## 动态表单

### 场景：动态增删表单项

```vue
<template>
  <w-form ref="formRef" :model="formData" label-width="100px">
    <!-- 固定字段 -->
    <w-form-item label="活动名称" prop="name">
      <w-input v-model="formData.name" />
    </w-form-item>

    <!-- 动态字段列表 -->
    <w-form-item label="参与人员">
      <div v-for="(person, index) in formData.persons" :key="index" class="dynamic-item">
        <w-form-item
          :prop="`persons.${index}.name`"
          :rules="personRules"
          label-width="0"
        >
          <w-input v-model="person.name" placeholder="姓名" />
        </w-form-item>
        <w-form-item
          :prop="`persons.${index}.phone`"
          :rules="phoneRules"
          label-width="0"
        >
          <w-input v-model="person.phone" placeholder="手机号" />
        </w-form-item>
        <w-button type="danger" @click="removePerson(index)">删除</w-button>
      </div>
      <w-button type="primary" @click="addPerson">添加人员</w-button>
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { reactive } from 'spark';

interface Person {
  name: string;
  phone: string;
}

const formData = reactive({
  name: '',
  persons: [{ name: '', phone: '' }] as Person[]
});

const personRules = [
  { required: true, message: '请输入姓名', trigger: 'blur' }
];

const phoneRules = [
  { required: true, message: '请输入手机号', trigger: 'blur' },
  { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' }
];

const addPerson = () => {
  formData.persons.push({ name: '', phone: '' });
};

const removePerson = (index: number) => {
  if (formData.persons.length > 1) {
    formData.persons.splice(index, 1);
  }
};
</script>

<style scoped>
.dynamic-item {
  display: flex;
  gap: 8px;
  margin-bottom: 8px;
}
</style>
```

---

## 跨字段联动校验

### 场景：密码确认校验

```vue
<template>
  <w-form ref="formRef" :model="formData" :rules="rules" label-width="100px">
    <w-form-item label="密码" prop="password">
      <w-input v-model="formData.password" type="password" show-password />
    </w-form-item>

    <w-form-item label="确认密码" prop="confirmPassword">
      <w-input v-model="formData.confirmPassword" type="password" show-password />
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { reactive } from 'spark';
import type { FormRules } from 'spark';

const formData = reactive({
  password: '',
  confirmPassword: ''
});

const validateConfirmPassword = (rule: any, value: string, callback: any) => {
  if (value !== formData.password) {
    callback(new Error('两次输入的密码不一致'));
  } else {
    callback();
  }
};

const rules = reactive<FormRules>({
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 20, message: '密码长度 6-20 个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    { validator: validateConfirmPassword, trigger: 'blur' }
  ]
});
</script>
```

### 场景：开始时间必须早于结束时间

```vue
<template>
  <w-form ref="formRef" :model="formData" :rules="rules" label-width="100px">
    <w-form-item label="开始时间" prop="startTime">
      <w-date-picker v-model="formData.startTime" type="datetime" />
    </w-form-item>

    <w-form-item label="结束时间" prop="endTime">
      <w-date-picker v-model="formData.endTime" type="datetime" />
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { reactive } from 'spark';
import type { FormRules } from 'spark';
import { utils } from 'spark';

const formData = reactive({
  startTime: '',
  endTime: ''
});

const validateEndTime = (rule: any, value: string, callback: any) => {
  if (formData.startTime && value) {
    const start = utils.date.dayjs(formData.startTime);
    const end = utils.date.dayjs(value);
    if (end.isBefore(start)) {
      callback(new Error('结束时间必须晚于开始时间'));
    } else {
      callback();
    }
  } else {
    callback();
  }
};

const rules = reactive<FormRules>({
  startTime: [
    { required: true, message: '请选择开始时间', trigger: 'change' }
  ],
  endTime: [
    { required: true, message: '请选择结束时间', trigger: 'change' },
    { validator: validateEndTime, trigger: 'change' }
  ]
});
</script>
```

---

## 异步校验

### 场景：用户名唯一性校验

```vue
<template>
  <w-form ref="formRef" :model="formData" :rules="rules" label-width="100px">
    <w-form-item label="用户名" prop="username">
      <w-input v-model="formData.username" placeholder="请输入用户名" />
    </w-form-item>
  </w-form>
</template>

<script setup lang="ts">
import { reactive } from 'spark';
import type { FormRules } from 'spark';
import { request } from 'spark';

const formData = reactive({
  username: ''
});

const validateUsernameUnique = async (rule: any, value: string, callback: any) => {
  if (!value) {
    callback();
    return;
  }
  try {
    const result = await request({ url: '/api/user/checkUsername', data: { username: value } });
    if (result.exists) {
      callback(new Error('用户名已存在'));
    } else {
      callback();
    }
  } catch (error) {
    callback(new Error('校验失败，请重试'));
  }
};

const rules = reactive<FormRules>({
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { validator: validateUsernameUnique, trigger: 'blur' }
  ]
});
</script>
```

---

## 分步表单

### 场景：多步骤表单

```vue
<template>
  <div class="step-form">
    <!-- 步骤条 -->
    <w-steps :active="currentStep" finish-status="success">
      <w-step title="基本信息" />
      <w-step title="联系方式" />
      <w-step title="完成" />
    </w-steps>

    <!-- 步骤内容 -->
    <div class="step-content">
      <!-- Step 1: 基本信息 -->
      <w-form v-show="currentStep === 0" ref="formRef1" :model="formData" :rules="rules1" label-width="100px">
        <w-form-item label="用户名" prop="username">
          <w-input v-model="formData.username" />
        </w-form-item>
        <w-form-item label="真实姓名" prop="realName">
          <w-input v-model="formData.realName" />
        </w-form-item>
      </w-form>

      <!-- Step 2: 联系方式 -->
      <w-form v-show="currentStep === 1" ref="formRef2" :model="formData" :rules="rules2" label-width="100px">
        <w-form-item label="邮箱" prop="email">
          <w-input v-model="formData.email" />
        </w-form-item>
        <w-form-item label="手机号" prop="phone">
          <w-input v-model="formData.phone" />
        </w-form-item>
      </w-form>

      <!-- Step 3: 完成 -->
      <div v-show="currentStep === 2" class="step-complete">
        <w-result icon="success" title="提交成功" sub-title="请等待审核" />
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="step-actions">
      <w-button v-if="currentStep > 0" @click="prevStep">上一步</w-button>
      <w-button v-if="currentStep < 2" type="primary" @click="nextStep">下一步</w-button>
      <w-button v-if="currentStep === 2" type="primary" @click="handleSubmit">提交</w-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'spark';
import type { FormInstance, FormRules } from 'spark';

const currentStep = ref(0);
const formRef1 = ref<FormInstance>();
const formRef2 = ref<FormInstance>();

const formData = reactive({
  username: '',
  realName: '',
  email: '',
  phone: ''
});

const rules1 = reactive<FormRules>({
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  realName: [{ required: true, message: '请输入真实姓名', trigger: 'blur' }]
});

const rules2 = reactive<FormRules>({
  email: [{ required: true, type: 'email', message: '请输入正确的邮箱', trigger: 'blur' }],
  phone: [{ required: true, pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }]
});

const prevStep = () => {
  currentStep.value--;
};

const nextStep = async () => {
  const formRef = currentStep.value === 0 ? formRef1.value : formRef2.value;
  if (formRef) {
    await formRef.validate();
    currentStep.value++;
  }
};

const handleSubmit = () => {
  // 最终提交
};
</script>

<style scoped>
.step-form {
  padding: 20px;
}
.step-content {
  margin: 20px 0;
}
.step-actions {
  display: flex;
  justify-content: center;
  gap: 10px;
}
</style>
```

---

## 表单弹窗

### 场景：弹窗内表单

```vue
<template>
  <!-- 操作按钮 -->
  <w-button type="primary" @click="handleAdd">新增</w-button>

  <!-- 弹窗表单 -->
  <w-dialog
    v-model="dialogVisible"
    :title="dialogTitle"
    width="640px"
    :before-close="handleClose"
  >
    <w-form
      ref="formRef"
      :model="formData"
      :rules="rules"
      label-width="100px"
    >
      <w-form-item label="用户名" prop="username">
        <w-input v-model="formData.username" />
      </w-form-item>
      <w-form-item label="邮箱" prop="email">
        <w-input v-model="formData.email" />
      </w-form-item>
      <w-form-item label="状态" prop="status">
        <w-select v-model="formData.status">
          <w-option label="启用" value="active" />
          <w-option label="禁用" value="inactive" />
        </w-select>
      </w-form-item>
    </w-form>

    <template #footer>
      <w-button @click="handleCancel">取消</w-button>
      <w-button type="primary" :loading="submitting" @click="handleConfirm">
        确定
      </w-button>
    </template>
  </w-dialog>
</template>

<script setup lang="ts">
import { ref, reactive } from 'spark';
import type { FormInstance, FormRules } from 'spark';
import { MessageBox } from 'spark';

const dialogVisible = ref(false);
const dialogTitle = ref('新增用户');
const formRef = ref<FormInstance>();
const submitting = ref(false);

const formData = reactive({
  username: '',
  email: '',
  status: 'active'
});

const rules = reactive<FormRules>({
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  email: [{ required: true, type: 'email', message: '请输入正确的邮箱', trigger: 'blur' }]
});

const handleAdd = () => {
  dialogTitle.value = '新增用户';
  resetForm();
  dialogVisible.value = true;
};

const handleEdit = (row: any) => {
  dialogTitle.value = '编辑用户';
  Object.assign(formData, row);
  dialogVisible.value = true;
};

const handleClose = (done: () => void) => {
  MessageBox.confirm('确定要关闭吗？未保存的数据将丢失')
    .then(() => done())
    .catch(() => {});
};

const handleCancel = () => {
  dialogVisible.value = false;
};

const handleConfirm = async () => {
  if (!formRef.value) return;
  await formRef.value.validate();

  submitting.value = true;
  try {
    // 提交逻辑
    dialogVisible.value = false;
  } finally {
    submitting.value = false;
  }
};

const resetForm = () => {
  formData.username = '';
  formData.email = '';
  formData.status = 'active';
};
</script>
```

---

## 表单最佳实践

### 1. 使用组合式函数封装表单逻辑

```typescript
// composables/useForm.ts
import { ref, reactive } from 'spark';
import type { FormInstance } from 'spark';

export function useForm<T extends object>(initialData: T) {
  const formRef = ref<FormInstance>();
  const formData = reactive<T>(initialData);
  const loading = ref(false);

  const validate = async () => {
    if (!formRef.value) return false;
    try {
      await formRef.value.validate();
      return true;
    } catch {
      return false;
    }
  };

  const reset = () => {
    formRef.value?.resetFields();
    Object.assign(formData, initialData);
  };

  const submit = async (submitFn: (data: T) => Promise<void>) => {
    const valid = await validate();
    if (!valid) return;

    loading.value = true;
    try {
      await submitFn(formData);
    } finally {
      loading.value = false;
    }
  };

  return {
    formRef,
    formData,
    loading,
    validate,
    reset,
    submit
  };
}
```

### 2. 表单字段分组

```vue
<template>
  <w-form :model="formData" label-width="100px">
    <!-- 基本信息 -->
    <w-divider content-position="left">基本信息</w-divider>
    <w-row :gutter="20">
      <w-col :span="12">
        <w-form-item label="用户名" prop="username">
          <w-input v-model="formData.username" />
        </w-form-item>
      </w-col>
      <w-col :span="12">
        <w-form-item label="真实姓名" prop="realName">
          <w-input v-model="formData.realName" />
        </w-form-item>
      </w-col>
    </w-row>

    <!-- 联系方式 -->
    <w-divider content-position="left">联系方式</w-divider>
    <w-row :gutter="20">
      <w-col :span="12">
        <w-form-item label="邮箱" prop="email">
          <w-input v-model="formData.email" />
        </w-form-item>
      </w-col>
      <w-col :span="12">
        <w-form-item label="手机号" prop="phone">
          <w-input v-model="formData.phone" />
        </w-form-item>
      </w-col>
    </w-row>
  </w-form>
</template>
```

### 3. 表单布局响应式

```vue
<template>
  <w-form :model="formData" label-width="100px">
    <w-row :gutter="20">
      <w-col :xs="24" :sm="12" :md="8" :lg="6">
        <w-form-item label="字段1" prop="field1">
          <w-input v-model="formData.field1" />
        </w-form-item>
      </w-col>
      <w-col :xs="24" :sm="12" :md="8" :lg="6">
        <w-form-item label="字段2" prop="field2">
          <w-input v-model="formData.field2" />
        </w-form-item>
      </w-col>
    </w-row>
  </w-form>
</template>
```