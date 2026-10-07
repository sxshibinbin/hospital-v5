/**
 * 为需求 1626166 更新状态和添加标签
 */
import TFSClient from './tfs-client.mjs';

async function main() {
  const client = new TFSClient('WINNING-6.0');

  const parentId = 1626166;
  const task1Id = 1626432; // T1 已创建并激活
  const task2Id = 1626438; // T2 已创建并激活

  // 更新父需求状态为"活动"（TFS 2018标准状态）
  console.log('\n更新父需求 1626166 状态为"活动"...');
  const parent = await client.updateWorkItemState(parentId, '活动', '需求分析完成，已创建开发任务 T1、T2，开始开发');
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
  console.log(`子任务 T1: ${task1Id} (前端开发)`);
  console.log(`子任务 T2: ${task2Id} (测试验证)`);
  console.log(`父需求状态: 活动`);
}

main().catch(e => {
  console.error('执行失败:', e);
  process.exit(1);
});