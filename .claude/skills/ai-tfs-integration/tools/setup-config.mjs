#!/usr/bin/env node
/**
 * TFS Config Setup Tool
 * 卫宁健康 WINNING-6.0 团队
 *
 * 首次使用时运行此脚本配置 TFS 认证信息
 */

import { saveConfig } from './tfs-client.mjs';

const DEFAULT_SERVER_URL = 'YOUR_TFS_SERVER_URL';

// 从命令行参数获取 PAT Token
const pat = process.argv[2];

if (!pat) {
  console.error(`
错误: 请提供 PAT Token

用法: node setup-config.mjs <your-pat-token>

获取 PAT Token:
1. 登录 TFS: YOUR_TFS_BASE_URL
2. 点击右上角用户头像 → 安全 → +添加 → 个人访问令牌
3. 设置令牌名称（如 "Claude Code"）和有效期
4. 选择权限:
   - 工作项: 读取、管理
   - 代码: 读取
5. 点击创建，然后复制生成的令牌

示例:
  node setup-config.mjs yz3d4b7k2q2h...
`);
  process.exit(1);
}

// 保存配置
try {
  saveConfig(DEFAULT_SERVER_URL, pat);
  console.log('\n✓ 配置已保存!');
  console.log('\n现在可以使用 TFS 查询工具了:');
  console.log('  node tfs-query.mjs my-tasks');
  console.log('  node tfs-query.mjs projects');
} catch (error) {
  console.error('保存配置失败:', error.message);
  process.exit(1);
}
