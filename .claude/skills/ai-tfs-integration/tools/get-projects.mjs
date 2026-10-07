#!/usr/bin/env node
/**
 * 获取指定集合的所有项目列表
 */
import TFSClient from './tfs-client.mjs';
import azureDevOps from 'azure-devops-node-api';

async function getProjectsInCollection(collectionName) {
  const config = JSON.parse(
    await import('fs').then((fs) => fs.readFileSync('./config/tfs-config.json', 'utf8'))
  );
  const collectionUrl =
    Object.values({
      'WINNING-6.0': 'http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0',
      'WN_PH-Platform': 'http://tfs2018-web.winning.com.cn:8080/tfs/WN_PH-Platform',
      WN_TECH: 'http://tfs2018-web.winning.com.cn:8080/tfs/WN_TECH',
    }).find((url) => url.includes(collectionName)) ||
    `http://tfs2018-web.winning.com.cn:8080/tfs/${collectionName}`;

  const authHandler = azureDevOps.getPersonalAccessTokenHandler(config.pat);
  const connection = new azureDevOps.WebApi(collectionUrl, authHandler);
  const coreApi = await connection.getCoreApi();

  const projects = await coreApi.getProjects();

  console.log(`\n集合 "${collectionName}" 中的项目:\n`);
  for (const project of projects) {
    console.log(`  ${project.name.padEnd(40)} ${project.id}`);
  }
  console.log(`\n共 ${projects.length} 个项目\n`);

  // 输出代码格式，方便复制到 tfs-client.mjs
  console.log('========== 代码格式 ==========');
  console.log('// 添加到 tfs-client.mjs 的 PROJECTS 对象:');
  for (const project of projects) {
    console.log(`  '${project.name}': '${project.id}',`);
  }
  console.log('\n// 添加到 WN_TECH_PROJECTS 数组:');
  console.log('const WN_TECH_PROJECTS = [');
  for (const project of projects) {
    console.log(`  '${project.name}',`);
  }
  console.log('];');
}

const collectionName = process.argv[2] || 'WN_TECH';
getProjectsInCollection(collectionName);
