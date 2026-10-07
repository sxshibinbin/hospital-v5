#!/usr/bin/env node
/**
 * 获取需求的所有子项及其关联的代码提交
 * 用法: node get-all-related-commits.mjs <需求ID> [集合名]
 */
import TFSClient, { getCollections } from './tfs-client.mjs';

const requirementId = parseInt(process.argv[2]);
const collectionArg = process.argv[3]; // 可选：指定集合

if (!requirementId) {
  console.error('请提供需求 ID');
  console.log('用法: node get-all-related-commits.mjs <需求ID> [集合名]');
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

async function getAllRelatedCommits(requirementId, specificCollection = null) {
  console.log(`\n========== 需求 ${requirementId} 的完整代码变更分析 ==========\n`);

  let requirement, client, collectionName;

  if (specificCollection) {
    // 指定集合查询
    client = new TFSClient(specificCollection);
    try {
      requirement = await client.getWorkItem(requirementId);
      collectionName = specificCollection;
    } catch (error) {
      console.error(`需求 ${requirementId} 在集合 "${specificCollection}" 中未找到`);
      return;
    }
  } else {
    // 在所有集合中查找
    console.log(`正在查找需求 ${requirementId}...`);
    const result = await findWorkItemInCollections(requirementId);
    if (!result) {
      console.error(`需求 ${requirementId} 在所有集合中都未找到`);
      return;
    }
    requirement = result.workItem;
    client = result.client;
    collectionName = result.collectionName;
  }

  console.log(`需求标题: ${requirement.fields['System.Title']}`);
  console.log(`状态: ${requirement.fields['System.State']}`);
  console.log(`项目: ${requirement.fields['System.TeamProject']}`);
  console.log(`集合: ${collectionName}`);

  // 获取需求分析
  const demandAnalysis = requirement.fields['Winning.Demand.Analysis'];
  if (demandAnalysis) {
    console.log(`\n========== 需求分析（摘要）==========`);
    const plainText = demandAnalysis
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .trim();
    // 只显示前500字作为摘要
    console.log(plainText.substring(0, 500) + (plainText.length > 500 ? '...' : ''));
  }

  // 2. 获取子工作项
  console.log(`\n========== 获取关联子项 ==========\n`);

  if (!requirement.relations || requirement.relations.length === 0) {
    console.log('该需求没有子工作项');
    return;
  }

  const childIds = [];
  requirement.relations.forEach((rel) => {
    if (rel.rel === 'System.LinkTypes.Hierarchy-Forward') {
      const childId = parseInt(rel.url.substring(rel.url.lastIndexOf('/') + 1));
      childIds.push(childId);
    }
  });

  if (childIds.length === 0) {
    console.log('该需求没有子工作项');
    return;
  }

  console.log(`找到 ${childIds.length} 个子工作项: ${childIds.join(', ')}\n`);

  // 获取子工作项详情
  const childWorkItems = await client.getWorkItems(childIds);

  childWorkItems.forEach((wi) => {
    console.log(`[${wi.id}] ${wi.fields['System.Title']}`);
    console.log(
      `    类型: ${wi.fields['System.WorkItemType']} | 状态: ${wi.fields['System.State']}`
    );
  });

  // 3. 获取项目信息
  const projectName = requirement.fields['System.TeamProject'];

  // 4. 查询每个子工作项的代码提交
  console.log(`\n========== 查询代码变更 ==========\n`);

  try {
    const repos = await client.getRepositories(projectName);

    if (repos.length === 0) {
      console.log(`项目 "${projectName}" 没有 Git 仓库`);
      console.log('可能使用 TFVC（Team Foundation Version Control）');
      return;
    }

    console.log(`项目 "${projectName}" 有 ${repos.length} 个仓库\n`);

    // 获取最近的提交（一年内）
    const allRepoCommits = [];

    for (const repo of repos) {
      const commits = await client.getCommits(repo.id, projectName, 500, 365);

      // 筛选关联到任何子工作项的提交
      const relatedCommits = commits.filter(
        (commit) => commit.workItems && commit.workItems.some((wi) => childIds.includes(wi.id))
      );

      if (relatedCommits.length > 0) {
        console.log(`\n--- 仓库: ${repo.name} (${relatedCommits.length} 个关联提交) ---`);

        for (const commit of relatedCommits) {
          const shortId = commit.commitId.substring(0, 8);
          const author = commit.author?.displayName || commit.author?.name || '未知';
          const date = new Date(commit.author?.date || commit.commitDate).toLocaleString('zh-CN');
          const comment = commit.comment || '<无评论>';

          // 找出关联的工作项
          const linkedWorkItems = commit.workItems
            .filter((wi) => childIds.includes(wi.id))
            .map((wi) => wi.id);

          console.log(`\n提交: ${shortId}`);
          console.log(`关联工作项: ${linkedWorkItems.join(', ')}`);
          console.log(`作者: ${author} | 日期: ${date}`);
          console.log(`说明: ${comment}`);

          // 变更文件
          if (commit.changes && commit.changes.length > 0) {
            console.log(`变更文件: ${commit.changes.length} 个`);
            commit.changes.forEach((change) => {
              const changeType = change.changeType;
              const path = change.item?.path || 'unknown';
              console.log(`  [${changeType}] ${path}`);
            });
          }

          allRepoCommits.push({
            repo: repo.name,
            commitId: shortId,
            author,
            date,
            comment,
            linkedWorkItems,
            changes: commit.changes || [],
          });
        }
      }
    }

    // 5. 汇总分析
    console.log(`\n\n========== 变更汇总分析 ==========\n`);

    if (allRepoCommits.length === 0) {
      console.log('未找到关联的代码提交');
      return;
    }

    console.log(`总计: ${allRepoCommits.length} 个提交\n`);

    // 统计文件变更
    const allChanges = allRepoCommits.flatMap((c) => c.changes);
    const changeStats = {
      add: allChanges.filter((c) => c.changeType === 'add').length,
      edit: allChanges.filter((c) => c.changeType === 'edit').length,
      delete: allChanges.filter((c) => c.changeType === 'delete').length,
    };

    console.log(`文件变更统计:`);
    console.log(`  新增: ${changeStats.add}`);
    console.log(`  修改: ${changeStats.edit}`);
    console.log(`  删除: ${changeStats.delete}`);
    console.log(`  总计: ${allChanges.length}`);

    // 按工作项分组
    console.log(`\n按工作项分组:`);
    const commitsByWorkItem = {};
    allRepoCommits.forEach((commit) => {
      commit.linkedWorkItems.forEach((wiId) => {
        if (!commitsByWorkItem[wiId]) {
          commitsByWorkItem[wiId] = [];
        }
        commitsByWorkItem[wiId].push(commit);
      });
    });

    for (const [wiId, commits] of Object.entries(commitsByWorkItem)) {
      const wi = childWorkItems.find((w) => w.id === parseInt(wiId));
      console.log(`\n  [${wiId}] ${wi.fields['System.Title']}`);
      console.log(`    提交数: ${commits.length}`);
    }
  } catch (error) {
    console.error(`查询代码变更时出错: ${error.message}`);
  }
}

// 执行查询
await getAllRelatedCommits(requirementId, collectionArg);
