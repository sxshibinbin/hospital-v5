/**
 * 为需求 1626166 创建子任务的临时脚本
 */
import TFSClient from './tfs-client.mjs';

async function main() {
  // 使用正确的集合参数初始化客户端
  const client = new TFSClient('WINNING-6.0');

  const parentId = 1626166;
  const project = 'WiNEX-Agent';

  // 任务1: 日志列表增加 Client IP 列
  const task1Fields = {
    title: 'AI Gateway: 日志列表增加 Client IP 列',
    description: `
<h3>任务描述</h3>
<p>在 AI Gateway 模型日志列表页面表格中增加"调用方 Client IP"列展示。</p>

<h3>功能要求</h3>
<ul>
<li>列标题：调用方 IP</li>
<li>IPv4/IPv6 地址完整展示</li>
<li>空值显示 "-" 占位符</li>
<li>使用等宽字体展示 IP</li>
</ul>

<h3>技术说明</h3>
<p>后端 API 已返回 client_ip 字段，仅需前端 UI 调整。</p>

<h3>验收标准</h3>
<ul>
<li>Client IP 列存在且数据正确</li>
<li>IP 格式展示正确</li>
<li>空值处理正确</li>
</ul>
    `,
    parentId: parentId,
    priority: 1,
    originalEstimate: 2.0,
    finishDate: '2026-06-04',
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
    if (task1.success) {
      console.log('\n建立任务依赖: T2 -> T1...');
      // TFS 2018 可能不支持前置依赖链接，尝试添加
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
  console.log(`子任务 T1: ${task1.success ? task1.id : '创建失败'}`);
  console.log(`子任务 T2: ${task2.success ? task2.id : '创建失败'}`);
}

main().catch(e => {
  console.error('执行失败:', e);
  process.exit(1);
});