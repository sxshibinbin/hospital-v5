/**
 * 为需求 1626549 创建子任务的临时脚本
 */
import TFSClient from './tfs-client.mjs';

async function main() {
  // 使用 WINNING-6.0 集合初始化客户端
  const client = new TFSClient('WINNING-6.0');

  const parentId = 1626549;
  const project = 'WiNEX-Agent';

  // 任务1: FallbackChainEditor.vue CSS 变量修正
  const task1Fields = {
    title: 'AI Gateway: FallbackChainEditor.vue CSS 变量修正',
    description: `
<h3>任务描述</h3>
<p>修复 FallbackChainEditor.vue 组件中 CSS 变量引用问题，将使用未定义变量 --bg-main 的样式替换为已定义的 --bg-card。</p>

<h3>问题定位</h3>
<ul>
<li>文件：dashboard/src/components/routing/FallbackChainEditor.vue</li>
<li>行号：293行 .chain-item 样式</li>
<li>行号：369行 .add-input 样式</li>
<li>问题：使用 var(--bg-main, #1a1a2e)，--bg-main 未定义</li>
</ul>

<h3>修改内容</h3>
<ul>
<li>将 background: var(--bg-main, #1a1a2e) 替换为 background: var(--bg-card)</li>
<li>移除硬编码 fallback 值</li>
</ul>

<h3>验收标准</h3>
<ul>
<li>light 主题下 Fallback 链条目背景色为浅色</li>
<li>dark 主题下 Fallback 链条目背景色为深色</li>
<li>主题切换时背景色实时响应</li>
<li>前端 lint 通过</li>
</ul>
    `,
    parentId: parentId,
    priority: 1,
    originalEstimate: 2.0,
    finishDate: '2026-05-30',
    tags: '前端开发'
  };

  console.log('\n创建任务 T1...');
  const task1 = await client.createWorkItem(project, 'Task', task1Fields);

  if (task1.success) {
    console.log(`✓ T1 创建成功: ID=${task1.id}`);

    // 激活任务
    console.log('激活任务 T1...');
    const activated1 = await client.updateWorkItemState(task1.id, '活动', '任务创建，开始开发');
    console.log(`✓ T1 状态已更新为: ${activated1.fields['System.State']}`);
  } else {
    console.log(`✗ T1 创建失败: ${task1.message}`);
  }

  // 任务2: 全局检查其他组件 CSS 变量使用
  const task2Fields = {
    title: 'AI Gateway: 全局检查其他组件 CSS 变量使用',
    description: `
<h3>任务描述</h3>
<p>全局搜索项目中所有使用未定义 CSS 变量 --bg-main 的组件，排查是否存在类似问题。</p>

<h3>搜索范围</h3>
<ul>
<li>目录：dashboard/src</li>
<li>文件类型：.vue, .css</li>
<li>关键词：--bg-main, #1a1a2e</li>
</ul>

<h3>输出要求</h3>
<ul>
<li>生成排查报告：DOCS/1626549/任务拆分/css变量排查报告.md</li>
<li>记录所有匹配文件及行号</li>
<li>评估是否需要修复（仅记录，不修复）</li>
</ul>

<h3>依赖任务</h3>
<p>依赖 T1 完成后执行。</p>
    `,
    parentId: parentId,
    priority: 2,
    originalEstimate: 1.0,
    finishDate: '2026-05-31',
    tags: '前端开发'
  };

  console.log('\n创建任务 T2...');
  const task2 = await client.createWorkItem(project, 'Task', task2Fields);

  if (task2.success) {
    console.log(`✓ T2 创建成功: ID=${task2.id}`);

    // 激活任务
    console.log('激活任务 T2...');
    const activated2 = await client.updateWorkItemState(task2.id, '活动', '任务创建，等待 T1 完成后执行');
    console.log(`✓ T2 状态已更新为: ${activated2.fields['System.State']}`);

    // 添加任务依赖（T2 依赖 T1）
    if (task1.success) {
      console.log('\n建立任务依赖: T2 -> T1...');
      try {
        await client.addWorkItemRelation(task2.id, task1.id, 'System.LinkTypes.Dependency');
        console.log('✓ 任务依赖已建立');
      } catch (e) {
        console.log('⚠ 依赖链接添加失败（TFS 2018 可能不支持）');
      }
    }
  } else {
    console.log(`✗ T2 创建失败: ${task2.message}`);
  }

  // 更新父需求状态为"已分析"
  console.log('\n更新父需求 1626549 状态为"已分析"...');
  try {
    // 先从"已建议"改为"活动"
    console.log('步骤1: 状态 "已建议" -> "活动"...');
    await client.updateWorkItemState(parentId, '活动', '需求分析完成，准备进入开发');

    // 再从"活动"改为"已分析"
    console.log('步骤2: 状态 "活动" -> "已分析"...');
    const parent = await client.updateWorkItemState(parentId, '已分析', '需求分析完成，已创建开发任务');
    console.log(`✓ 父需求状态已更新为: ${parent.fields['System.State']}`);
  } catch (e) {
    console.log('⚠ 状态更新失败:', e.message);
  }

  // 添加标签
  console.log('\n为父需求添加标签 "AI-ANALYSIS"...');
  try {
    await client.addWorkItemTag(parentId, 'AI-ANALYSIS');
    console.log('✓ 标签已添加');
  } catch (e) {
    console.log('⚠ 标签添加失败:', e.message);
  }

  console.log('\n========== TFS 下发完成 ==========');
  console.log(`父需求: ${parentId}`);
  console.log(`子任务 T1: ${task1.success ? task1.id : '创建失败'}`);
  console.log(`子任务 T2: ${task2.success ? task2.id : '创建失败'}`);
}

main().catch(e => {
  console.error('执行失败:', e);
  process.exit(1);
});