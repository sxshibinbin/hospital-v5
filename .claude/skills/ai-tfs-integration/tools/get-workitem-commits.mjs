#!/usr/bin/env node
/**
 * 获取工作项关联的代码提交（通过工作项 Relations 中的 ArtifactLink 反向查找）
 *
 * 用法: node get-workitem-commits.mjs <工作项ID> [项目名称]
 *
 * 改进说明：
 *   v1.0: 从 repo 获取最近提交 → 过滤 commit.workItems（不可靠，TFS 2018 getCommits 不返回 workItems）
 *   v2.0: 从工作项 Relations 中解析 ArtifactLink → 提取 commit hash → 逐个查询 commit 详情
 */
import TFSClient from './tfs-client.mjs';
import fs from 'fs';
import path, { dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * 从 vstfs ArtifactLink URL 中解析 commit 信息
 * URL 格式: vstfs:///Git/Commit/{projectId}%2f{repoId}%2f{commitHash}
 *
 * @param {string} url - ArtifactLink URL
 * @returns {{projectId: string, repoId: string, commitHash: string}|null}
 */
function parseCommitArtifactUrl(url) {
  if (!url || !url.startsWith('vstfs:///Git/Commit/')) {
    return null;
  }
  try {
    // 去掉 vstfs:///Git/Commit/ 前缀
    const parts = url.replace('vstfs:///Git/Commit/', '').split('%2f');
    if (parts.length !== 3) {
      return null;
    }
    const [projectId, repoId, commitHash] = parts;
    return { projectId, repoId, commitHash };
  } catch (e) {
    return null;
  }
}

/**
 * 获取仓库缓存（repoId → {name, project} 映射）
 */
function getReposCache() {
  const cacheFile = path.join(__dirname, '../config/repos-cache.json');
  if (!fs.existsSync(cacheFile)) {
    console.error('仓库缓存不存在，请先运行: node tools/get-repos-cache.mjs');
    process.exit(1);
  }
  const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
  return cache.repositories || {};
}

async function getCommitsForWorkItem(workItemId, projectName) {
  const client = new TFSClient();

  // 1. 获取工作项（含 Relations）
  console.log(`\n正在获取工作项 ${workItemId} 的详细信息...`);
  let workItem;
  try {
    workItem = await client.getWorkItem(workItemId, projectName);
  } catch (e) {
    console.error(`获取工作项失败: ${e.message}`);
    return [];
  }

  if (!workItem) {
    console.error('未找到工作项');
    return [];
  }

  projectName = projectName || workItem.fields?.['System.TeamProject'];
  console.log(`工作项: [${workItemId}] ${workItem.fields?.['System.Title']}`);
  console.log(`状态: ${workItem.fields?.['System.State']} | 项目: ${projectName}`);

  // 2. 从 Relations 中提取 Git Commit ArtifactLink
  const relations = workItem.relations || [];
  const commitLinks = [];

  for (const rel of relations) {
    const parsed = parseCommitArtifactUrl(rel.url);
    if (parsed) {
      commitLinks.push({
        ...parsed,
        authorizedDate: rel.attributes?.authorizedDate,
        name: rel.attributes?.name,
        linkId: rel.attributes?.id,
      });
    }
  }

  if (commitLinks.length === 0) {
    console.log('\n========== 结果 ==========');
    console.log(`未找到工作项 ${workItemId} 关联的代码提交`);
    console.log('可能原因:');
    console.log('  1. 该工作项确实没有关联代码提交');
    console.log('  2. 关联类型不是 Git Commit（可能是其他类型的链接）');
    return [];
  }

  console.log(`\n找到 ${commitLinks.length} 个关联的 Git Commit 链接\n`);

  // 3. 加载仓库缓存（用于显示仓库名称）
  let reposCache = {};
  try {
    reposCache = getReposCache();
  } catch (e) {
    console.warn('仓库缓存加载失败，将只显示仓库 ID');
  }

  // 查找仓库名称
  function findRepoName(repoId) {
    for (const [id, info] of Object.entries(reposCache)) {
      if (id === repoId) {
        return info.name || id;
      }
    }
    return repoId;
  }

  // 4. 逐个查询 commit 详情
  const commits = [];
  const gitApi = await client.getGitApi();

  for (let i = 0; i < commitLinks.length; i++) {
    const link = commitLinks[i];
    const shortHash = link.commitHash.substring(0, 8);
    const repoName = findRepoName(link.repoId);

    try {
      const commit = await gitApi.getCommit(link.commitHash, link.repoId, link.projectId);

      const author = commit.author?.displayName || commit.author?.name || '未知';
      const date = new Date(commit.author?.date || commit.committer?.date).toLocaleString('zh-CN');
      const comment = commit.comment || '<无评论>';

      console.log(`========== 提交 ${i + 1}/${commitLinks.length} ==========`);
      console.log(`Commit: ${link.commitHash}`);
      console.log(`仓库: ${repoName} (${link.repoId.substring(0, 8)}...)`);
      console.log(`作者: ${author} | 日期: ${date}`);
      console.log(`链接时间: ${link.authorizedDate ? new Date(link.authorizedDate).toLocaleString('zh-CN') : '未知'}`);
      console.log(`说明: ${comment}`);

      // 变更文件
      if (commit.changes && commit.changes.length > 0) {
        console.log(`\n变更文件 (${commit.changes.length} 个):`);
        commit.changes.forEach((change) => {
          const changeType = change.changeType || 'unknown';
          const filePath = change.item?.path || 'unknown';
          console.log(`  [${changeType}] ${filePath}`);
        });
      }
      console.log('');

      commits.push({
        commitId: link.commitHash,
        shortId: shortHash,
        repoId: link.repoId,
        repoName: repoName,
        author: author,
        date: date,
        comment: comment,
        changes: commit.changes || [],
        linkDate: link.authorizedDate,
      });

    } catch (e) {
      console.log(`========== 提交 ${i + 1}/${commitLinks.length} ==========`);
      console.log(`Commit: ${link.commitHash} (${shortHash})`);
      console.log(`仓库: ${repoName}`);
      console.log(`⚠️ 获取提交详情失败: ${e.message}`);
      console.log('');

      commits.push({
        commitId: link.commitHash,
        shortId: shortHash,
        repoId: link.repoId,
        repoName: repoName,
        author: '未知',
        date: link.authorizedDate || '未知',
        comment: '<获取失败>',
        changes: [],
        linkDate: link.authorizedDate,
        error: e.message,
      });
    }
  }

  // 5. 汇总
  console.log('========== 汇总 ==========');

  // 按仓库分组
  const repoGroups = {};
  const typeStats = {};
  for (const c of commits) {
    const repoKey = c.repoName || c.repoId;
    if (!repoGroups[repoKey]) {
      repoGroups[repoKey] = [];
    }
    repoGroups[repoKey].push(c);
  }

  for (const [repo, repoCommits] of Object.entries(repoGroups)) {
    console.log(`仓库 "${repo}": ${repoCommits.length} 个提交`);
  }
  console.log(`总计: ${commits.length} 个提交\n`);

  // 变更文件汇总
  const allFiles = new Set();
  for (const c of commits) {
    for (const change of (c.changes || [])) {
      const filePath = change.item?.path || 'unknown';
      allFiles.add(filePath);
    }
  }
  if (allFiles.size > 0) {
    console.log(`涉及文件 (${allFiles.size} 个):`);
    for (const f of [...allFiles].sort()) {
      console.log(`  - ${f}`);
    }
    console.log('');
  }

  return commits;
}

// 执行查询
const workItemId = parseInt(process.argv[2]);
const projectName = process.argv[3];

if (!workItemId) {
  console.error('请提供工作项 ID');
  console.log('用法: node get-workitem-commits.mjs <工作项ID> [项目名称]');
  process.exit(1);
}

await getCommitsForWorkItem(workItemId, projectName);
