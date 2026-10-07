# 快开框架 RDF 开发指南

> 详细说明快开框架（RDF）的开发规范、配置文件、控制类代码模板。

## 目录

- [框架概述](#框架概述)
- [核心概念](#核心概念)
- [文件结构](#文件结构)
- [页面元数据配置](#页面元数据配置)
- [视图配置](#视图配置)
- [布局配置](#布局配置)
- [控制类开发](#控制类开发)
- [组件规范](#组件规范)
- [最佳实践](#最佳实践)

---

## 框架概述

快开框架（RDF，Rapid Development Framework）是卫宁健康的低代码快速开发框架，通过 XML 配置 + TypeScript 控制类的方式，快速生成医疗后台系统页面。

### 核心优势

- **配置驱动**：通过 XML 配置定义页面结构，减少编码工作量
- **标准化输出**：统一页面布局、组件样式、交互模式
- **快速迭代**：修改配置即可调整页面，无需重构代码
- **医疗场景适配**：预置医疗业务组件和交互模式

### 适用场景

- 医疗后台管理页面（用户管理、权限配置、数据字典等）
- 标准 CRUD 操作页面
- 数据查询与展示页面
- 配置类页面

---

## 核心概念

| 概念 | 说明 | 文件类型 |
|------|------|----------|
| **pageCode** | 页面唯一标识，用于路由和权限控制 | - |
| **Page Meta** | 页面元数据，定义基本信息、权限、数据源 | `.page.meta.xml` |
| **View** | 视图配置，定义页面 UI 结构（查询区、表格、操作按钮） | `.view.xml` |
| **Layout** | 布局配置，定义页面整体布局（可选） | `.layout.xml` |
| **Controller** | 控制类，处理业务逻辑、API 调用、事件响应 | `.controller.ts` |

---

## 文件结构

### 标准目录结构

```
src/modules/
├── UserModule/                    # 用户管理模块
│   ├── views/
│   │   ├── userManage.view.xml       # 用户管理视图
│   │   ├── userDetail.view.xml       # 用户详情视图（可选）
│   │   └── userManage.layout.xml     # 用户管理布局（可选）
│   ├── userManage.page.meta.xml      # 用户管理元数据
│   └── controller/
│       └── userManage.controller.ts  # 用户管理控制类
├── SystemModule/                  # 系统管理模块
│   ├── views/
│   │   └── dictManage.view.xml       # 字典管理视图
│   ├── dictManage.page.meta.xml      # 字典管理元数据
│   └── controller/
│       └── dictManage.controller.ts  # 字典管理控制类
```

### 文件命名规范

| 文件类型 | 命名规则 | 示例 |
|----------|----------|------|
| pageCode | 小驼峰，业务含义 | `userManage`、`dictManage` |
| 元数据文件 | `{pageCode}.page.meta.xml` | `userManage.page.meta.xml` |
| 视图文件 | `{pageCode}.view.xml` | `userManage.view.xml` |
| 布局文件 | `{pageCode}.layout.xml` | `userManage.layout.xml` |
| 控制类文件 | `{pageCode}.controller.ts` | `userManage.controller.ts` |

---

## 页面元数据配置

### 基本结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<page xmlns="http://www.winning.com.cn/rdf/page"
      pageCode="userManage"
      title="用户管理"
      module="UserModule">

  <!-- 页面描述 -->
  <description>用户管理页面，支持用户查询、新增、编辑、删除</description>

  <!-- 权限配置 -->
  <permission>
    <read>user:read</read>
    <write>user:write</write>
    <delete>user:delete</delete>
  </permission>

  <!-- 数据源配置 -->
  <dataSource>
    <api>/api/user/list</api>
    <method>GET</method>
    <params>
      <param name="username" type="string" />
      <param name="status" type="string" />
    </params>
  </dataSource>

  <!-- 事件配置 -->
  <events>
    <onLoad>handleLoad</onLoad>
    <onSearch>handleSearch</onSearch>
    <onAdd>handleAdd</onAdd>
    <onEdit>handleEdit</onEdit>
    <onDelete>handleDelete</onDelete>
  </events>

  <!-- 国际化配置 -->
  <i18n>
    <locale>zh-CN</locale>
    <fallbackLocale>en-US</fallbackLocale>
  </i18n>
</page>
```

### 配置项说明

| 配置项 | 必填 | 说明 |
|--------|------|------|
| `pageCode` | ✅ | 页面唯一标识，用于路由 |
| `title` | ✅ | 页面标题，显示在面包屑和标签页 |
| `module` | ✅ | 所属模块，用于模块化管理 |
| `description` | ❌ | 页面描述，用于文档生成 |
| `permission` | ✅ | 权限配置，控制按钮和操作显示 |
| `dataSource` | ✅ | 数据源配置，定义 API 地址和参数 |
| `events` | ✅ | 事件配置，关联控制类方法 |
| `i18n` | ❌ | 国际化配置 |

---

## 视图配置

### 基本结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<view xmlns="http://www.winning.com.cn/rdf/view"
      pageCode="userManage">

  <!-- 查询区域 -->
  <searchArea label="查询条件" collapsible="true">
    <field name="username" label="用户名" type="input"
           placeholder="请输入用户名" width="200px" />
    <field name="status" label="状态" type="select" width="150px">
      <options>
        <option value="" label="全部" />
        <option value="active" label="启用" />
        <option value="inactive" label="禁用" />
      </options>
    </field>
    <field name="createTime" label="创建时间" type="dateRange"
           startPlaceholder="开始时间" endPlaceholder="结束时间" />
    <button type="search" label="查询" icon="search" />
    <button type="reset" label="重置" icon="refresh" />
  </searchArea>

  <!-- 操作区域 -->
  <toolbar>
    <button type="add" label="新增" icon="plus" permission="user:write" />
    <button type="batchDelete" label="批量删除" icon="delete"
            permission="user:delete" confirm="确定要批量删除吗？" />
    <button type="export" label="导出" icon="download" />
    <button type="import" label="导入" icon="upload" />
  </toolbar>

  <!-- 表格区域 -->
  <table rowKey="id" stripe border>
    <!-- 选择列 -->
    <column type="selection" width="55" />

    <!-- 序号列 -->
    <column type="index" label="序号" width="60" />

    <!-- 数据列 -->
    <column name="username" label="用户名" width="120" sortable />
    <column name="email" label="邮箱" width="200" />
    <column name="phone" label="手机号" width="150" />

    <!-- 状态列（带模板） -->
    <column name="status" label="状态" width="100">
      <template>
        <tag type="success" condition="status === 'active'" label="启用" />
        <tag type="danger" condition="status === 'inactive'" label="禁用" />
      </template>
    </column>

    <!-- 时间列 -->
    <column name="createTime" label="创建时间" width="180"
            format="YYYY-MM-DD HH:mm:ss" />

    <!-- 操作列 -->
    <column type="operation" label="操作" width="200" fixed="right">
      <button type="edit" label="编辑" icon="edit" permission="user:write" />
      <button type="delete" label="删除" icon="delete"
              permission="user:delete" confirm="确定要删除吗？" />
      <button type="detail" label="详情" icon="view" />
    </column>
  </table>

  <!-- 分页配置 -->
  <pagination pageSize="10" pageSizes="10,20,50,100"
              layout="total, sizes, prev, pager, next, jumper" />

  <!-- 弹窗配置 -->
  <dialog name="editDialog" title="编辑用户" width="640px">
    <form labelWidth="100px">
      <field name="username" label="用户名" type="input" required />
      <field name="email" label="邮箱" type="input" required
             rules="email" />
      <field name="phone" label="手机号" type="input"
             rules="phone" />
      <field name="status" label="状态" type="select" required>
        <options>
          <option value="active" label="启用" />
          <option value="inactive" label="禁用" />
        </options>
      </field>
    </form>
    <footer>
      <button type="submit" label="提交" />
      <button type="cancel" label="取消" />
    </footer>
  </dialog>
</view>
```

### 字段类型说明

| 字段类型 | 说明 | 适用场景 |
|----------|------|----------|
| `input` | 文本输入框 | 用户名、邮箱、备注等 |
| `select` | 下拉选择框 | 状态、类型、分类等 |
| `date` | 日期选择器 | 单个日期 |
| `dateRange` | 日期范围选择器 | 开始-结束时间 |
| `number` | 数字输入框 | 年龄、数量、金额等 |
| `textarea` | 多行文本框 | 详细描述、备注 |
| `checkbox` | 复选框 | 多选项 |
| `radio` | 单选框 | 单选项 |
| `treeSelect` | 树形选择器 | 组织机构、分类树 |

### 按钮类型说明

| 按钮类型 | 说明 | 自动行为 |
|----------|------|----------|
| `search` | 查询按钮 | 自动调用 handleSearch |
| `reset` | 重置按钮 | 自动清空查询条件 |
| `add` | 新增按钮 | 自动打开新增弹窗 |
| `edit` | 编辑按钮 | 自动打开编辑弹窗 |
| `delete` | 删除按钮 | 自动确认并调用 handleDelete |
| `batchDelete` | 批量删除按钮 | 自动确认并调用批量删除 |
| `export` | 导出按钮 | 自动调用导出方法 |
| `import` | 导入按钮 | 自动打开导入弹窗 |
| `submit` | 提交按钮 | 自动验证表单并提交 |
| `cancel` | 取消按钮 | 自动关闭弹窗 |

---

## 布局配置

### 基本结构（可选）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<layout xmlns="http://www.winning.com.cn/rdf/layout"
        pageCode="userManage">

  <!-- 页面整体布局 -->
  <structure type="standard">
    <!-- 头部区域 -->
    <header height="60px">
      <breadcrumb />
      <toolbar position="right" />
    </header>

    <!-- 内容区域 -->
    <content>
      <!-- 左侧树（可选） -->
      <aside width="200px" collapsible="true">
        <tree name="orgTree" title="组织机构" />
      </aside>

      <!-- 主内容 -->
      <main>
        <searchArea />
        <toolbar />
        <table />
        <pagination />
      </main>
    </content>
  </structure>
</layout>
```

### 布局类型

| 布局类型 | 说明 | 适用场景 |
|----------|------|----------|
| `standard` | 标准布局（头部+内容） | 大多数列表页面 |
| `leftTree` | 左树右表布局 | 组织机构、分类管理 |
| `masterDetail` | 主从布局 | 主表+明细表 |
| `tabs` | 标签页布局 | 多功能模块 |

---

## 控制类开发

### 基类继承

```typescript
import { BaseController, Message, Confirm } from 'pango-framework';

export class UserManageController extends BaseController {
  // 基类提供的方法：
  // - request(url, params, method) - HTTP 请求
  // - message - 消息提示
  // - confirm - 确认框
  // - loading - 加载状态
  // - router - 路由跳转
  // - store - 状态管理
}
```

### 标准控制类模板

```typescript
import { BaseController } from 'pango-framework';
import type { User, UserQueryParams, UserFormData } from '../types/user';

export class UserManageController extends BaseController {

  /** 页面加载 */
  async handleLoad(params: UserQueryParams): Promise<{ data: User[]; total: number }> {
    this.loading.show('加载中...');
    try {
      const result = await this.request<{ data: User[]; total: number }>(
        '/api/user/list',
        params,
        'GET'
      );
      return result;
    } finally {
      this.loading.hide();
    }
  }

  /** 查询 */
  async handleSearch(params: UserQueryParams): Promise<{ data: User[]; total: number }> {
    return this.handleLoad(params);
  }

  /** 新增 */
  async handleAdd(data: UserFormData): Promise<void> {
    this.loading.show('保存中...');
    try {
      await this.request('/api/user/create', data, 'POST');
      this.message.success('新增成功');
      // 刷新列表
      this.refreshList();
    } finally {
      this.loading.hide();
    }
  }

  /** 编辑 */
  async handleEdit(data: UserFormData): Promise<void> {
    this.loading.show('保存中...');
    try {
      await this.request('/api/user/update', data, 'PUT');
      this.message.success('编辑成功');
      this.refreshList();
    } finally {
      this.loading.hide();
    }
  }

  /** 删除 */
  async handleDelete(id: string): Promise<void> {
    const confirmed = await this.confirm('确定要删除该用户吗？', '提示', {
      type: 'warning'
    });
    if (!confirmed) return;

    this.loading.show('删除中...');
    try {
      await this.request(`/api/user/delete/${id}`, null, 'DELETE');
      this.message.success('删除成功');
      this.refreshList();
    } finally {
      this.loading.hide();
    }
  }

  /** 批量删除 */
  async handleBatchDelete(ids: string[]): Promise<void> {
    const confirmed = await this.confirm(
      `确定要删除选中的 ${ids.length} 个用户吗？`,
      '提示',
      { type: 'warning' }
    );
    if (!confirmed) return;

    this.loading.show('删除中...');
    try {
      await this.request('/api/user/batchDelete', { ids }, 'POST');
      this.message.success('批量删除成功');
      this.refreshList();
    } finally {
      this.loading.hide();
    }
  }

  /** 导出 */
  async handleExport(params: UserQueryParams): Promise<void> {
    this.loading.show('导出中...');
    try {
      const result = await this.request('/api/user/export', params, 'GET');
      // 处理导出文件下载
      this.downloadFile(result.url);
    } finally {
      this.loading.hide();
    }
  }

  /** 刷新列表 */
  private refreshList(): void {
    // 触发页面重新加载
    this.emit('refresh');
  }
}
```

### 常用基类方法

| 方法 | 说明 | 示例 |
|------|------|------|
| `request(url, params, method)` | HTTP 请求 | `this.request('/api/user/list', params, 'GET')` |
| `message.success(text)` | 成功提示 | `this.message.success('操作成功')` |
| `message.error(text)` | 错误提示 | `this.message.error('操作失败')` |
| `message.warning(text)` | 警告提示 | `this.message.warning('请注意')` |
| `confirm(text, title, options)` | 确认框 | `await this.confirm('确定删除吗？')` |
| `loading.show(text)` | 显示加载 | `this.loading.show('加载中...')` |
| `loading.hide()` | 隐藏加载 | `this.loading.hide()` |
| `router.push(path)` | 路由跳转 | `this.router.push('/user/detail')` |
| `emit(event, data)` | 触发事件 | `this.emit('refresh', data)` |
| `downloadFile(url)` | 下载文件 | `this.downloadFile(result.url)` |

---

## 组件规范

### 弹窗尺寸规范

| 尺寸 | 宽度 | 适用场景 |
|------|------|----------|
| 小 | 480px | 简单表单、确认提示 |
| 中 | 640px | 标准表单、详情展示 |
| 大 | 1000px | 复杂表单、多 Tab |
| 百分比中 | 50% | 大屏表单 |
| 百分比大 | 85% | 全屏编辑 |

### 表格列宽度规范

| 列类型 | 建议宽度 |
|--------|----------|
| 选择列 | 55px |
| 序号列 | 60px |
| 状态列 | 100px |
| 操作列 | 150-200px |
| 时间列 | 180px |
| 文本列 | 根据内容动态 |

---

## 最佳实践

### 1. 权限控制

```xml
<!-- 按钮显示权限 -->
<button type="add" permission="user:write" />

<!-- 操作列按钮权限 -->
<column type="operation">
  <button type="edit" permission="user:write" />
  <button type="delete" permission="user:delete" />
</column>
```

### 2. 确认提示

```xml
<!-- 删除确认 -->
<button type="delete" confirm="确定要删除吗？" />

<!-- 批量操作确认 -->
<button type="batchDelete" confirm="确定要批量删除选中的记录吗？" />
```

### 3. 表单验证

```xml
<!-- 必填验证 -->
<field name="username" label="用户名" type="input" required />

<!-- 格式验证 -->
<field name="email" label="邮箱" type="input" rules="email" />
<field name="phone" label="手机号" type="input" rules="phone" />

<!-- 自定义验证（控制类实现） -->
<field name="age" label="年龄" type="number" validator="validateAge" />
```

```typescript
// 控制类中实现自定义验证
validateAge(value: number): boolean {
  return value >= 0 && value <= 150;
}
```

### 4. 国际化

```xml
<!-- 使用 i18n key -->
<field name="username" label="$t('user.username')" />
<button type="search" label="$t('common.search')" />
```

### 5. 联动查询

```xml
<!-- 左树右表联动 -->
<aside>
  <tree name="orgTree" onSelect="handleOrgSelect" />
</aside>
<main>
  <table dataSource="/api/user/list?orgId={orgTree.selected}" />
</main>
```

```typescript
// 控制类中处理联动
handleOrgSelect(orgId: string): void {
  this.setQueryParam('orgId', orgId);
  this.refreshList();
}
```