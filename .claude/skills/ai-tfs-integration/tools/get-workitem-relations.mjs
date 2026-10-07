#!/usr/bin/env node
/**
 * 获取工作项的关联关系（父项或子项）
 * 用法: node get-workitem-relations.mjs <工作项ID> [parent|children] [集合名]
 */
import TFSClient, { getCollections } from './tfs-client.mjs';

const workItemId = parseInt(process.argv[2]);
const relationType = process.argv[3]; // 'parent' 或 'children'
const collectionArg = process.argv[4]; // 可选：指定集合

if (!workItemId) {
  console.error('请提供工作项 ID');
  console.log('用法: node get-workitem-relations.mjs <工作项ID> [parent|children] [集合名]');
  process.exit(1);
}

/**
 * 在所有集合中查找工作项
 */
async function findWorkItemInCollections(id) {
  const collections = getCollections();

  for (const [name] of Object.entries(collections)) {
    try {
      const client = new TFSClient(name);
      const workItem = await client.getWorkItem(id);
      if (workItem && workItem.id) {
        return { workItem, collectionName: name, client };
      }
    } catch (error) {
      // 继续查找下一个集合
      continue;
    }
  }
  return null;
}

async function getWorkItemRelations(id, type, specificCollection = null) {
  let workItem, client, collectionName;

  if (specificCollection) {
    // 指定集合查询
    client = new TFSClient(specificCollection);
    try {
      workItem = await client.getWorkItem(id);
      collectionName = specificCollection;
    } catch (error) {
      console.error(`工作项 ${id} 在集合 "${specificCollection}" 中未找到`);
      return [];
    }
  } else {
    // 在所有集合中查找
    console.log(`正在查找工作项 ${id}...`);
    const result = await findWorkItemInCollections(id);
    if (!result) {
      console.error(`工作项 ${id} 在所有集合中都未找到`);
      return [];
    }
    workItem = result.workItem;
    client = result.client;
    collectionName = result.collectionName;
  }

  console.log(`\n========== 工作项 ${id} 的关联关系 ==========\n`);
  console.log(`标题: ${workItem.fields['System.Title']}`);
  console.log(`类型: ${workItem.fields['System.WorkItemType']}`);
  console.log(`状态: ${workItem.fields['System.State']}`);
  console.log(`项目: ${workItem.fields['System.TeamProject']}`);
  console.log(`集合: ${collectionName}`);

  if (!workItem.relations || workItem.relations.length === 0) {
    console.log('\n无关联工作项');
    return [];
  }

  const relatedIds = [];

  // 筛选指定类型的关联
  workItem.relations.forEach((rel) => {
    const relType = rel.rel;
    const url = rel.url;

    // 父工作项 (System.LinkTypes.Hierarchy-Reverse)
    if (type === 'parent' && relType === 'System.LinkTypes.Hierarchy-Reverse') {
      const parentId = parseInt(url.substring(url.lastIndexOf('/') + 1));
      relatedIds.push({ id: parentId, type: 'parent' });
    }

    // 子工作项 (System.LinkTypes.Hierarchy-Forward)
    if (type === 'children' && relType === 'System.LinkTypes.Hierarchy-Forward') {
      const childId = parseInt(url.substring(url.lastIndexOf('/') + 1));
      relatedIds.push({ id: childId, type: 'child' });
    }

    // 如果没有指定类型，返回所有子项
    if (!type && relType === 'System.LinkTypes.Hierarchy-Forward') {
      const childId = parseInt(url.substring(url.lastIndexOf('/') + 1));
      relatedIds.push({ id: childId, type: 'child' });
    }
  });

  if (relatedIds.length === 0) {
    console.log(`\n未找到${type ? (type === 'parent' ? '父' : '子') : '子'}工作项`);
    return [];
  }

  // 获取关联工作项的详情
  console.log(`\n找到 ${relatedIds.length} 个关联工作项:\n`);

  const ids = relatedIds.map((r) => r.id);
  const relatedWorkItems = await client.getWorkItems(ids);

  relatedWorkItems.forEach((wi) => {
    const relation = relatedIds.find((r) => r.id === wi.id);
    const relationLabel = relation?.type === 'parent' ? '父需求' : '子项';
    console.log(`[${wi.id}] ${relationLabel}: ${wi.fields['System.Title']}`);
    console.log(
      `    类型: ${wi.fields['System.WorkItemType']} | 状态: ${wi.fields['System.State']}`
    );
    console.log();
  });

  return relatedWorkItems;
}

// 执行查询
const result = await getWorkItemRelations(workItemId, relationType, collectionArg);

// 如果找到了子项，输出它们的ID供后续使用
if (result.length > 0) {
  console.log('========== 子项ID列表 ==========');
  console.log(result.map((wi) => wi.id).join(', '));
  console.log('');
}
