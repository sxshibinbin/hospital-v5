# Stage 1: 预处理

## 输入
- work_item_id: TFS工作项ID
- repository_url: 代码仓库地址
- source_branch: 源分支
- target_branch: 目标分支
- scan_mode: 扫描模式（initial/incremental）

## 处理步骤

### Step 1.1: 获取TFS工作项信息
使用 `mcp__tfs-mcp__tfs_get_workitem` 获取工作项详情：
- 工作项标题、描述
- 关联的代码仓库
- 产品线信息

### Step 1.2: 获取代码变更

**增量模式（incremental）**:
使用 `mcp__tfs-mcp__tfs_get_branch_diffs` 获取两个分支之间的差异：
```
tfs_get_branch_diffs(
  repositoryId: repo_id,
  project: project_name,
  baseBranch: target_branch,
  targetBranch: source_branch
)
```
返回变更文件列表。

**全量模式（initial）**:
使用 `Bash` 执行 git clone 和 git ls-files 获取所有代码文件：
```bash
# ⚠️ 重要：必须分开执行，禁止组合命令
git clone --depth 1 --branch {source_branch} {repository_url} temp_repo
git -C temp_repo ls-files
```

### Step 1.3: 识别技术栈
根据文件扩展名自动识别技术栈：

| 扩展名 | 技术栈 |
|--------|--------|
| .java | java |
| .vue, .tsx | vue |
| .ts | ts |
| .rs | rust |
| .cs | csharp |
| .html | html |
| .sql | sql |
| .py | python |

### Step 1.4: 过滤无关文件
排除以下目录和文件：
- **/test/**：测试代码
- **/node_modules/**：依赖目录
- **/target/**：构建产物
- **/*.min.js：压缩文件
- **/dist/**：分发目录

### Step 1.5: 初始化执行进度文档

创建目录和初始化执行进度文档：
```python
def init_exec_progress(work_item_id, task_info):
    """
    初始化执行进度文档

    Args:
        work_item_id: 工作项ID
        task_info: 任务信息
    """
    # 创建目录
    output_dir = f"DOCS/{work_item_id}/代码审查"
    os.makedirs(output_dir, exist_ok=True)

    # 初始化进度文档
    exec_prog_path = f"{output_dir}/exec_prog.md"

    progress_data = {
        "task_id": task_info["task_id"],
        "work_item_id": work_item_id,
        "current_stage": "Stage 1: 预处理",
        "status": "🔄 Running",
        "start_time": datetime.now().isoformat(),
        "elapsed_time": "0分钟",
        "s1_1_status": "🔄 Running",
        # ... 其他字段初始化为 ⏳ Pending
    }

    # 使用模板生成初始进度文档
    template = load_template("exec_prog.md")
    content = template.format(**progress_data)
    write_file(exec_prog_path, content)

    return exec_prog_path
```

**目录结构**：
```
DOCS/
├── config.env                    # 总配置文件（如存在）
├── {work_item_id}/               # 工作项目录
│   └── 代码审查/
│       └── exec_prog.md          # 执行进度文档
```

## 输出
```json
{
  "files": [
    {
      "path": "src/main/java/com/winning/service/UserService.java",
      "tech_stack": "java",
      "change_type": "modified"
    }
  ],
  "tech_stack_tags": ["java", "vue"],
  "total_files": 45,
  "review_round": 1,
  "failed_fix_history": {}
}
```

**说明**：
- `review_round`: 审查轮次计数器，初始值为 1
- `failed_fix_history`: 历史修复失败记录，用于跨轮次传递（初始为空对象）

## 异常处理
- TFS工作项不存在：返回错误 E001
- 代码仓库无法访问：返回错误 E002
- 分支不存在：返回错误 E003
