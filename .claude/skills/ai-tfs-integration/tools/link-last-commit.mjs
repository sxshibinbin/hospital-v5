/**
 * 关联最后一次Git提交到TFS工作项
 */
import TFSClient from './tfs-client.mjs';

const client = new TFSClient();

// 最后一次提交信息
const commitId = '4ee24ee69ca075ad11a93216b2cdb7beafdaf9b1';
const commitMessage = 'Update .gitignore: 排除dist目录下的exe文件';

// 需要关联的工作项
const workItemIds = [
  1679968, // 需求：跨平台消息弹窗客户端
  1680926, // 需求：托盘程序设置功能增强
  // 1679968的子任务
  1679991, 1679993, 1679994, 1679998, 1679999, 1680000, 1680001, 1680002, 1680004, 1680006, 1680007,
  // 1680926的子任务
  1680932, 1680934, 1680935, 1680936, 1680937
];

async function linkCommitToWorkItems() {
  try {
    console.log('开始关联最后一次Git提交到工作项...\n');
    console.log(`提交ID: ${commitId}`);
    console.log(`提交信息: ${commitMessage}\n`);

    // 获取仓库信息
    const repos = await client.getRepositories('WiNEX-Agent');
    const repo = repos.find(r => r.name === 'winning-bot-push');

    if (!repo) {
      console.error('未找到仓库 winning-bot-push');
      return;
    }

    console.log(`仓库: ${repo.name} (ID: ${repo.id})\n`);

    // 构建Artifact Link URL
    const artifactUrl = `vstfs:///Git/Commit/${repo.id}/${commitId}`;

    console.log(`Artifact URL: ${artifactUrl}\n`);

    // 对每个工作项添加评论，包含提交信息
    for (const workItemId of workItemIds) {
      const comment = `关联代码提交: ${commitId.substring(0, 7)}\n\n提交信息: ${commitMessage}\n\nArtifact: ${artifactUrl}`;
      await client.addComment(workItemId, comment);
      console.log(`✓ 工作项 ${workItemId} 已关联`);
    }

    console.log('\n所有工作项已成功关联！');

  } catch (error) {
    console.error('错误:', error.message);
  }
}

linkCommitToWorkItems();
