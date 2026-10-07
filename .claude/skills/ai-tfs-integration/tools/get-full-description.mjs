#!/usr/bin/env node
import TFSClient from './tfs-client.mjs';

const client = new TFSClient('WINNING-6.0');
const workItem = await client.getWorkItem(1317727);

console.log('\n========== 需求完整描述 ==========\n');
console.log(workItem.fields['System.Description']);
console.log('\n====================================\n');
