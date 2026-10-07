/**
 * 关联代码提交到工作项
 */
import TFSClient from './tfs-client.mjs';

const client = new TFSClient();

// 代码提交信息
const commits = [
  { id: 'd745671', message: 'Initial commit: 初始化消息推送机器人项目' },
  { id: '4ee24ee', message: 'Update .gitignore: 排除dist目录下的exe文件' }
];

// 工作项ID
const workItemIds = [1679968, 1680926];

async function linkCommitsToWorkItems() {
  try {
    console.log('开始关联代码提交到工作项...\n');

    // 获取仓库信息
    const repos = await client.getRepositories('WiNEX-Agent');
    const repo = repos.find(r => r.name === 'winning-bot-push');

    if (!repo) {
      console.error('未找到仓库 winning-bot-push');
      return;
    }

    console.log(`找到仓库: ${repo.name} (ID: ${repo.id})\n`);

    // 对每个工作项添加代码提交链接
    for (const workItemId of workItemIds) {
      console.log(`处理工作项 ${workItemId}...`);

      // 添加评论，包含提交信息
      let comment = '关联的代码提交：\n\n';
      for (const commit of commits) {
        comment += `- ${commit.id}: ${commit.message}\n`;
      }

      await client.addComment(workItemId, comment);
      console.log(`✓ 已添加评论到工作项 ${workItemId}\n`);
    }

    console.log('所有代码提交已关联到工作项');

  } catch (error) {
    console.error('错误:', error.message);
  }
}

linkCommitsToWorkItems();
