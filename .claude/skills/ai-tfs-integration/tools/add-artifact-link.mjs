/**
 * 添加代码提交链接到工作项（通过Artifact Link）
 */
import TFSClient from './tfs-client.mjs';
import http from 'http';

class ArtifactLinkClient extends TFSClient {
  /**
   * 添加Artifact Link到工作项
   * @param {number} workItemId - 工作项ID
   * @param {string} artifactUrl - Artifact URL (vstfs:///Git/Commit/...)
   * @param {string} comment - 链接备注
   */
  async addArtifactLink(workItemId, artifactUrl, comment = '关联代码提交') {
    const auth = Buffer.from(`:${this.pat}`).toString('base64');
    const updateUrl = `${this.serverUrl}/_apis/wit/workitems/${workItemId}?api-version=4.1`;

    const document = [{
      op: 'add',
      path: '/relations/-',
      value: {
        rel: 'ArtifactLink',
        url: artifactUrl,
        attributes: {
          comment: comment,
          name: 'Git Commit'
        }
      }
    }];

    const body = JSON.stringify(document);

    return new Promise((resolve, reject) => {
      const urlObj = new URL(updateUrl);
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port,
        path: urlObj.pathname + urlObj.search,
        method: 'PATCH',
        headers: {
          'Authorization': `Basic ${auth}`,
          'Content-Type': 'application/json-patch+json; charset=utf-8',
          'Content-Length': Buffer.byteLength(body),
        },
      };

      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ success: true, workItemId, artifactUrl });
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(body);
      req.end();
    });
  }
}

const client = new ArtifactLinkClient();

// 最后一次提交信息
const commitId = '4ee24ee69ca075ad11a93216b2cdb7beafdaf9b1';
const repoId = '735d95a9-66bf-41ce-9884-85f5a64945e1';

// 构建Artifact URL
const artifactUrl = `vstfs:///Git/Commit/${repoId}/${commitId}`;

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
    console.log('开始添加Artifact Link到工作项...\n');
    console.log(`提交ID: ${commitId.substring(0, 7)}`);
    console.log(`Artifact URL: ${artifactUrl}\n`);

    for (const workItemId of workItemIds) {
      await client.addArtifactLink(workItemId, artifactUrl, '关联代码提交: 4ee24ee');
      console.log(`✓ 工作项 ${workItemId} 已添加链接`);
    }

    console.log('\n所有工作项已成功添加Artifact Link！');

  } catch (error) {
    console.error('错误:', error.message);
  }
}

linkCommitToWorkItems();
