/**
 * 为需求 1626166 创建子任务 - 续（T1已创建）
 */
import TFSClient from './tfs-client.mjs';

async function main() {
  const client = new TFSClient('WINNING-6.0');

  const parentId = 1626166;
  const project = 'WiNEX-Agent';
  const task1Id = 1626432; // T1 已创建

  // 任务2: 测试验证
  const task2Fields = {
    title: 'AI Gateway: Client IP 展示测试验证',
    description: `
<h3>任务描述</h3>
<p>验证 Client IP 展示功能符合需求规范。</p>

<h3>测试用例</h3>
<ul>
<li>TC-001: 日志列表 Client IP 列展示正确</li>
<li>TC-002: IPv4 地址格式正确</li>
<li>TC-003: IPv6 地址格式正确</li>
<li>TC-004: 空值显示 "-"</li>
</ul>

<h3>依赖任务</h3>
<p>依赖 T1（日志列表增加 Client IP 列）完成后执行。</p>
    `,
    parentId: parentId,
    priority: 1,
    originalEstimate: 1.0,
    finishDate: '2026-06-05',
    tags: '测试'
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
    console.log('\n建立任务依赖: T2 -> T1...');
    try {
      await client.addWorkItemRelation(task2.id, task1Id, 'System.LinkTypes.Dependency');
      console.log('✓ 任务依赖已建立');
    } catch (e) {
      console.log('⚠ 依赖链接添加失败（TFS 2018 可能不支持）');
    }
  } else {
    console.log(`✗ T2 创建失败: ${task2.message}`);
  }

  // 更新父需求状态为"已分析"
  console.log('\n更新父需求 1626166 状态为"已分析"...');
  const parent = await client.updateWorkItemState(parentId, '已分析', '需求分析完成，已创建开发任务');
  console.log(`✓ 父需求状态已更新为: ${parent.fields['System.State']}`);

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
  console.log(`子任务 T1: ${task1Id}`);
  console.log(`子任务 T2: ${task2.success ? task2.id : '创建失败'}`);
}

main().catch(e => {
  console.error('执行失败:', e);
  process.exit(1);
});