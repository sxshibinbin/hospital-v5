#!/usr/bin/env node
/**
 * 获取并缓存仓库映射表
 * 将仓库ID和名称映射保存到 JSON 文件中
 */
import TFSClient, { PROJECT_TO_COLLECTION } from './tfs-client.mjs';
import fs from 'fs';
import path, { dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function getReposCache() {
  // 先尝试读取缓存
  const cacheFile = path.join(__dirname, '../config/repos-cache.json');
  const configDir = path.dirname(cacheFile);

  if (fs.existsSync(cacheFile)) {
    const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    const cacheAge = Date.now() - new Date(cache.lastUpdate).getTime();
    const cacheMaxAge = 24 * 60 * 60 * 1000; // 24小时

    if (cacheAge < cacheMaxAge) {
      console.log(`使用缓存的仓库数据 (更新时间: ${cache.lastUpdate})`);
      return cache;
    }
  }

  // 缓存不存在或过期，重新获取
  console.log('获取最新仓库数据...');

  // 获取所有集合的仓库
  const collections = ['WINNING-6.0', 'WN_PH-Platform', 'WN_TECH', 'wn_his'];
  const allRepos = {};

  for (const collectionName of collections) {
    // 获取该集合下的所有项目
    const client = new TFSClient(collectionName);
    const allProjects = client.getProjects();

    // 过滤出属于当前集合的项目
    const projects = {};
    for (const [projectName, projectId] of Object.entries(allProjects)) {
      const projectCollection = PROJECT_TO_COLLECTION[projectName];
      if (projectCollection === collectionName) {
        projects[projectName] = projectId;
      }
    }

    for (const [projectName, projectId] of Object.entries(projects)) {
      try {
        const repos = await client.getRepositories(projectName);
        console.log(`项目 ${projectName}: ${repos.length} 个仓库`);

        for (const repo of repos) {
          allRepos[repo.id] = {
            id: repo.id,
            name: repo.name,
            project: projectName,
            projectId: projectId,
            collection: collectionName,
            url: repo.url,
            defaultBranch: repo.defaultBranch || 'main',
          };
        }
      } catch (e) {
        // 某些项目可能无法访问，跳过
        continue;
      }
    }
  }

  const cache = {
    lastUpdate: new Date().toISOString(),
    totalCount: Object.keys(allRepos).length,
    repositories: allRepos,
  };

  // 保存缓存
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }
  fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 2));

  console.log(`\n仓库缓存已保存: ${cache.totalCount} 个仓库\n`);

  return cache;
}

// 执行并输出
const cache = await getReposCache();

console.log('========== 仓库映射统计 ==========');
console.log(`总计: ${cache.totalCount} 个仓库`);
console.log(`更新时间: ${cache.lastUpdate}`);
console.log('');

// 按项目分组统计
const byProject = {};
for (const repo of Object.values(cache.repositories)) {
  if (!byProject[repo.project]) {
    byProject[repo.project] = [];
  }
  byProject[repo.project].push(repo.name);
}

console.log('按项目统计（仓库数量 > 5）:');
for (const [project, repos] of Object.entries(byProject)) {
  if (repos.length > 5) {
    console.log(`  ${project}: ${repos.length} 个仓库`);
  }
}
