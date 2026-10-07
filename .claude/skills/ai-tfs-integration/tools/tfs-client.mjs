#!/usr/bin/env node
/**
 * TFS 2018 Client Wrapper
 * 卫宁健康 WINNING-6.0 团队
 *
 * 用于与 TFS 2018 服务器交互的客户端封装
 * 配置文件: ./config/tfs-config.json
 */

import fs from 'fs';
import path from 'path';
import http from 'http';
import https from 'https';
import { fileURLToPath } from 'url';
import azureDevOps from 'azure-devops-node-api';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 服务器配置（内置）
const DEFAULT_SERVER_URL = 'http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0';

// 内置项目列表
const PROJECTS = {
  // WINNING-6.0 集合
  'OA4.0': '4150312b-3a53-4da7-a8a7-e2bfe7fd970f',
  'win-cloud': 'b46e3a4d-0b96-4d7b-aa4a-216121a1ef73',
  'WiNEX-Copilot': 'a3f67cbb-d375-4a58-a6c8-da448150c495',
  售前演示: 'ddbd09b1-59ea-420d-843d-2f70ef9aa8e8',
  'WiNEX-DCP': 'f4e79b7d-13e6-4e47-9a17-570d72d4f6ef',
  'W.in-DEMO': 'fa4a1591-32d3-4e3f-82c2-761005d119a2',
  'WiNEX-PatientInterests': '6a84d2a9-b5ce-44e5-bce0-171ad6cd96e1',
  'W.in-MVP': '8c3c22dc-6d35-49b5-8589-3375adb60a84',
  'WiNEX-MDM': 'aa8c3418-9ec5-4c9e-8209-e229aeda3cfa',
  HUMANITY: '595b77d4-6f9a-46cf-9aeb-ea2afdef59d6',
  'WiNEX-Cloud': 'd4361d76-6ff9-4fc3-851c-536d9305c40c',
  'WiNEX-MiddlePlatform': '8ef8a81d-59bd-455e-a86c-2687ba9b6e03',
  'WiNEX-Inpatient-2': 'fa2bf9fc-fdc9-4167-ae72-feef8525e1f5',
  'WiNEX-Outpatient': 'e17bb6a1-2677-4695-8202-c3c296bbd05c',
  'WiNEX-General': '250f7599-5c8c-4e93-892c-71157224ae73',
  'WiNEX-Integration': '7c4d1061-6885-4c24-8096-1e1fc9795432',
  MiddlePlatform: '5c6e7482-f12f-418d-8994-bc5aeaea75a8',
  'WiNEX-CaseHistory': '739645d0-5770-4efc-98d3-33c98e749837',
  'Public Query': 'bad35cc1-f0d6-4f80-8ba0-6f166b3ef6be',
  WiNEX_WXP: '89f17307-4986-4251-a04f-e534f9a1b99d',
  UED: '58e8e9b0-5975-48d2-af2d-2719222c7ff0',
  'WiNEX-Inpatient': '9e4a971d-4027-4c9a-b55b-f0b74487afb5',
  'WiNEX-Triage': 'af9ab1c7-72ef-42cf-91a3-ef771be43f5a',
  'WiNEX-Emergency': '5f498025-58dd-4ba0-8137-3fc962e1acaf',
  'WiNEX-Management': 'e92e726a-8dbe-4385-998f-58182a4ddb1c',
  'WiNEX-Taikang': 'af798a82-646e-467a-8f90-8f3b2c9c39a4',
  'WiNEX-BasicInfoService': '7dfa9b49-818c-4765-8aae-aec1304af4e9',
  'WiNEX-Specialized': '8f70e3be-75e3-4969-a3fb-93481dc2c589',
  'WINEX-ConfigManage': '18eb3c40-2667-435f-80df-51ce43b24935',
  'WiNEX-HospitalAdministration': '6dcd7f28-99b5-4f43-8877-82230e999906',
  'WiNEX-MY': '6cdb1969-bbbc-4ea2-818a-ae29389df42e',
  'WiNEX-Agent': 'a3f67cbb-d375-4a58-a6c8-da448150c495',

  // WN_TECH 集合
  BIS60: '1d989ffb-59c3-487c-9d09-c0b6362d3a40',
  UED_TECH: 'f286da57-ca5d-4525-b66d-bf21ff2ed66d',
  LIS60: '95ce4d88-d5cf-43dd-8c19-cfe57e51cc10',
  MIIS: 'f596a6ab-558f-491c-8ce5-36f3d908c77f',
  PACSPLUS_PEM_CLoudView: 'ddd08d7f-71c4-4578-80f5-3440891440a5',
  TechBookCenter: '748161b2-80d5-48a3-94f3-576b8bc7ea8d',
  HDIS: 'c7dabbab-5a27-4f8d-b7f3-241116ccb4fc',
  MIIS_APPLYSHEET: '36b0ae9d-3d92-482c-b99a-c4b5ec5fe0b2',
  PACS_Viewer: '6cc17d90-ab03-4223-82f3-17563f858bff',
  COMMON_WJZ: '222b5054-73b7-42f8-bca0-836645c65489',
  MIIS_BL: 'a48f079b-d20f-4268-a274-a3c1fdcff424',
  PACSPLUS_Platform: '24291c93-f7e3-4354-bff4-3186a3afab34',
  HLE: 'aa17466a-99d3-4a4e-a210-d4711b6ecd0d',
  LIS60_KS: '3dff956f-3f7f-439b-b619-fc121fd6ad38',
  MIIS_RMC: '7d5e640d-4168-4274-bf3a-344b0f1d70f2',
  LIS60_WSW: 'd0053b6d-a8ce-4a85-acf9-68b6e065b8d0',
  PACS_DICOMServer: 'e6101d04-72af-4dd0-855a-89b41b485be1',
  LIS60_ZK: '20f22ad0-de5c-4904-911c-cb5e64a2efe1',
  LIS60_LJ: 'c1f6b664-8684-4a87-aa92-7ef982854e5f',
  LIS60_CG: 'a31c733c-0b73-48d4-9d77-ef5836a26925',
  CLOUD_RIS: '7e334cd2-6cda-4d53-aaf5-5a68e09ab507',
  LIS50: '400a0e87-6fab-430b-b488-7f101c994d70',
  BIS60_SQD: 'c9482856-4442-44f3-8f4c-dfe4ea3e5f91',
  WiNEX_PACS: '08817ae4-e290-482b-9271-9a20d003409e',
  COMMON_FRAME: 'ff925c08-2aa3-4a41-aae3-a52ac3dfe0c9',
  COMMON_WEBREPORT: '8c7489ef-8b3d-4c29-b013-791d793fa6b7',

  // wn_his 集合
  EAHis: '202b20c2-d536-491f-80cb-75fee0acc1ba',
  WinningReport: '72a40fda-43c2-40fe-9408-b32aa31419b1',
  Framework_His: 'c63e4f11-006c-4f13-906d-4311d872138e',
  DMS: '9154bc39-d8f8-45f4-abe6-c16289a39ea1',
  传染病疫情监测: 'a9d19e50-f8a3-4f22-80d3-d878d53430ff',
  'WiNEX-HOCC': '97f8d3d0-c949-4ad4-8aef-d0b1de7322b0',
  ACIS: '2969d9de-1d7a-410f-8d5c-bb39610f6a9d',
  移动医生站: '7a3c28f2-861f-4046-b79e-6dede52a4d8f',
  Framework: '76afaec7-fac6-404e-a758-1de96e5c7f72',
  MDM_HIS: '0ada6b32-9023-4a07-aeb8-0ef0e2c6f021',
  ConfigTest: '5ef9025e-fa6e-4166-83ce-33611a1d340e',
  Manage: '5aff193f-ca33-483a-9d62-0a385bbd5e07',
  CIS: '6330259e-25fe-40a8-949f-e75043742644',
  体检管理: '995ee813-a3a2-4a87-a998-9dbd55c1bf50',
  DRG: 'ebb866c7-b321-4e98-adaa-f48965a566d2',
  ONDS: '5aa95afb-5cbb-4f96-b436-a8e82f3c6b8f',
  智能导医机器人: 'edb39a45-4c76-4aa9-a5db-0ff197691e15',
  EC: '65bfb1c1-c22f-442b-96e9-15ce474f475d',
  NIS: '77acde39-5acb-473d-8cfb-96c6ee4a555d',
  PublicTech: '5185b220-eb7a-415c-933c-7d140069f370',
  QA: 'afd04791-e5e9-4719-8666-80b333beda83',
  '4.0产品后台': '7a9b4296-d6e6-40d6-860f-630b3bab4a62',
  移动护理: 'd0458819-d170-4968-b41e-d15dc29bb3df',
  智能预问诊: '7a8fd1c5-a84d-4aeb-b9f4-07b3c33f5b36',
  EDIS: '7d239b65-9108-40b8-bd5e-3b8503d2d75c',
  自助机HSS: '74656d37-4852-47ae-ad3d-e5add5afb95b',
  '863计划': '7a57edef-290a-4183-8aae-8cde94c83623',
  TestDept: '0ae9b5b8-2e82-41bf-9d2b-fb350d5c1436',
  一站式住院服务: '93ac68c2-3468-4b38-a16a-46cdb5e9140e',
  CHD: 'feba9583-3e53-497f-aa5d-22809dbe9189',
  控费管理: '79bd010e-d0c7-41a0-841d-4a3a02b8be46',
  EMPI: '7cf73c28-ce7d-4bf8-a9ec-592a405823d2',
  院感产品: '382aaaa0-feec-4df6-9988-36364b77a7d2',
  'ET-INTERNET': '8b959d05-77f1-44d6-90e5-0d2dba1bec75',
  EMNIS: 'a74fe9b7-8a17-4d22-8b4e-d6d998823e2a',
  Cost: 'b9f34327-4229-4a29-8dc9-05ab5fa58613',
  数据底座: '415eb214-b908-4587-a740-fbfbcd7821dc',
  His_Service: '2985ed32-c6ea-42f3-997d-ec1ff56626c6',
  ICIS: 'dc772203-102b-419e-ae52-caf345098648',
  口腔门诊: '8184611b-ec8b-49a3-a39f-655139cf89ac',
  HPEMS: '7cc218c0-32e1-434e-9974-44a399257830',
  Other: 'cc6571ec-11fe-4c44-9d74-d6ed3fd70577',
  治疗管理系统: 'ce8262de-b89e-45d8-9e30-7b93c81c45b1',
  医院集成平台ESB: 'f575155c-e507-4f0a-a614-0039bb2d65f5',
  移动业务研发中心: 'dba20954-c6af-4ccf-b9f6-0fa71ad39247',
  MIMIICSP: '897984fa-fa67-453c-b509-6b3018829dcd',
  医疗质量管理: '2572ff82-ce68-48c5-9eaa-cddc4c2a1ac2',
  SSO: 'da151662-da3c-4cf0-a7d1-32de20222586',
  家床系统: '4e0c24e8-ab80-48c7-9b6e-d62ab194aef4',
  HDevManage: 'da249f86-23fd-4cba-9cc7-ca997eb68583',
  智慧病区: 'b906ddc1-3db6-4cfc-aed6-b06df70cff8d',
  COVIDTest: 'bafdf2d3-643a-415c-a4b5-eb9f5553ad2a',
  院内互联网服务: 'a9f23fa2-c1fa-434d-b334-5fbbe997ca72',
  ASMC: '3a5d40d6-5f30-4afa-bb87-5a2710b23ba8',
  康复产品: '36b731de-e625-4f1a-907f-96b94912134b',
  CTMS: '7aa44a50-0e2f-4079-8dae-334a6b6b3762',
  UED_HIS: '1d9e6213-d799-408e-aa0f-81c242dbf2c4',
  人力资源管理: '3f0c4117-5fe5-47b6-9dd5-309018315585',
  护士站分诊: '2bbd8c7d-7a53-41e8-9b9d-0338e75b9b47',
  WITECH: '7d4ece89-7600-41e0-9818-5f50c6f9ceb5',
  DataHealth: 'ae2351a3-18e8-4f77-90b7-e8d41da11cfd',
  手术管理: 'ecd3e07c-6dc3-4c41-94b7-e0b68202cec6',
  基础HIS: 'f8c6bb4c-a233-4236-ab2f-3ba50ab507bf',
  IntegrationTest: 'a409c9b0-8b50-4f13-8933-4cd16b7503c3',
  TADHIS: 'a74ba90e-12b1-4c45-9dc7-d67c022f416f',
  'THIS5.0解耦': '494f4d98-7a5c-42fe-a8ef-56186f1dfe4e',
  集成平台框架: '5c74b08c-5c17-4eec-9618-6b8fc609429b',
  门诊输液: '621e10e9-cf47-4b2f-8272-db6b52776b60',
  IOT: '20f1b62f-94fd-4c58-bed3-ced4fcfb4ed7',
  CDSS: 'fc3b14a2-400c-47a0-9135-c7c8b47e6832',

  // WN_PH-Platform 集合
  PerformanceAppraisal: 'b173ae90-c623-4573-9365-fee7fa0d6cef',
  'NETHIS5.5': '0cdc2e36-9e43-46d1-bd33-07d5f0e9bb51',
  REPC: 'f306bba8-fae2-4ed6-91e0-a0d26713aed6',
  VTE: 'b3d28916-ddc0-49a6-a2bd-c5dd0e3d46d0',
  RegionalHealth: '63288f13-4c4c-47b1-8d4d-eef71161018c',
  RCIS: '6ba0cd93-729f-42cc-a3fa-d5610c5fd3b6',
  RFDS: 'c304239f-158d-4ac5-ad53-035b888da0e4',
  'M-360': '88ae4488-02e5-49e4-a527-5cce9e5ac0dd',
  'CDC-Software': '77a3e392-b5de-49bd-bb93-21cf8c01b5c4',
  GCP: '47813526-b35b-489f-b6a4-1f59e6b9c99b',
  RPES: '449cd3b0-d7d1-477a-98d9-6e1a7132bbcc',
  健康医养: '9c1e3237-e3e8-46ab-9af7-770c3a7ceb8d',
  RMCHS: '5d01544b-3365-4970-ba64-75acc131eca0',
  区域院感: '628905fd-df70-43ef-a98f-dbf268c66661',
  RPHIS: '2d76773b-ace4-4861-aea5-ebe03119a5a0',
  'WiNEX-PublicHealth': 'd5a8550c-3ced-4742-83ae-9dd4c7a548aa',
  家庭医生: '5d84c707-3f96-4c3f-94f9-1bcc2304c77c',
  基本医疗: 'f68e2fb9-c732-45cc-a102-4b9f3c38b57f',
  Cloud_His60: '10640cd1-567d-4586-aa7c-3942e1627010',
};

// 集合定义
const COLLECTIONS = {
  'WINNING-6.0': {
    name: 'WINNING-6.0',
    url: 'http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0',
    description: '主集合',
  },
  'WN_PH-Platform': {
    name: 'WN_PH-Platform',
    url: 'http://tfs2018-web.winning.com.cn:8080/tfs/WN_PH-Platform',
    description: '公共卫生平台集合',
  },
  WN_TECH: {
    name: 'WN_TECH',
    url: 'http://tfs2018-web.winning.com.cn:8080/tfs/WN_TECH',
    description: '技术平台集合',
  },
  wn_his: {
    name: 'wn_his',
    url: 'http://tfs2018-web.winning.com.cn:8080/tfs/wn_his',
    description: 'HIS产品集合',
  },
};

// 项目到集合的映射
const WINNING_6_0_PROJECTS = [
  'OA4.0',
  'win-cloud',
  'WiNEX-Copilot',
  '售前演示',
  'WiNEX-DCP',
  'W.in-DEMO',
  'WiNEX-PatientInterests',
  'W.in-MVP',
  'WiNEX-MDM',
  'HUMANITY',
  'WiNEX-Cloud',
  'WiNEX-MiddlePlatform',
  'WiNEX-Inpatient-2',
  'WiNEX-Outpatient',
  'WiNEX-General',
  'WiNEX-Integration',
  'MiddlePlatform',
  'WiNEX-CaseHistory',
  'Public Query',
  'WiNEX_WXP',
  'UED',
  'WiNEX-Inpatient',
  'WiNEX-Triage',
  'WiNEX-Emergency',
  'WiNEX-Management',
  'WiNEX-Taikang',
  'WiNEX-BasicInfoService',
  'WiNEX-Specialized',
  'WINEX-ConfigManage',
  'WiNEX-HospitalAdministration',
  'WiNEX-MY',
  'WiNEX-Agent',
];

const WN_PH_PLATFORM_PROJECTS = [
  'PerformanceAppraisal',
  'NETHIS5.5',
  'REPC',
  'VTE',
  'RegionalHealth',
  'RCIS',
  'RFDS',
  'M-360',
  'CDC-Software',
  'GCP',
  'RPES',
  '健康医养',
  'RMCHS',
  '区域院感',
  'RPHIS',
  'WiNEX-PublicHealth',
  '家庭医生',
  '基本医疗',
  'Cloud_His60',
];

const WN_TECH_PROJECTS = [
  'BIS60',
  'UED_TECH',
  'LIS60',
  'MIIS',
  'PACSPLUS_PEM_CLoudView',
  'TechBookCenter',
  'HDIS',
  'MIIS_APPLYSHEET',
  'PACS_Viewer',
  'COMMON_WJZ',
  'MIIS_BL',
  'PACSPLUS_Platform',
  'HLE',
  'LIS60_KS',
  'MIIS_RMC',
  'LIS60_WSW',
  'PACS_DICOMServer',
  'LIS60_ZK',
  'LIS60_LJ',
  'LIS60_CG',
  'CLOUD_RIS',
  'LIS50',
  'BIS60_SQD',
  'WiNEX_PACS',
  'COMMON_FRAME',
  'COMMON_WEBREPORT',
];

const WN_HIS_PROJECTS = [
  'EAHis',
  'WinningReport',
  'Framework_His',
  'DMS',
  '传染病疫情监测',
  'WiNEX-HOCC',
  'ACIS',
  '移动医生站',
  'Framework',
  'MDM_HIS',
  'ConfigTest',
  'Manage',
  'CIS',
  '体检管理',
  'DRG',
  'ONDS',
  '智能导医机器人',
  'EC',
  'NIS',
  'PublicTech',
  'QA',
  '4.0产品后台',
  '移动护理',
  '智能预问诊',
  'EDIS',
  '自助机HSS',
  '863计划',
  'TestDept',
  '一站式住院服务',
  'CHD',
  '控费管理',
  'EMPI',
  '院感产品',
  'ET-INTERNET',
  'EMNIS',
  'Cost',
  '数据底座',
  'His_Service',
  'ICIS',
  '口腔门诊',
  'HPEMS',
  'Other',
  '治疗管理系统',
  '医院集成平台ESB',
  '移动业务研发中心',
  'MIMIICSP',
  '医疗质量管理',
  'SSO',
  '家床系统',
  'HDevManage',
  '智慧病区',
  'COVIDTest',
  '院内互联网服务',
  'ASMC',
  '康复产品',
  'CTMS',
  'UED_HIS',
  '人力资源管理',
  '护士站分诊',
  'WITECH',
  'DataHealth',
  '手术管理',
  '基础HIS',
  'IntegrationTest',
  'TADHIS',
  'THIS5.0解耦',
  '集成平台框架',
  '门诊输液',
  'IOT',
  'CDSS',
];

// 项目到集合的映射
const PROJECT_TO_COLLECTION = Object.fromEntries([
  ...WINNING_6_0_PROJECTS.map((p) => [p, 'WINNING-6.0']),
  ...WN_PH_PLATFORM_PROJECTS.map((p) => [p, 'WN_PH-Platform']),
  ...WN_TECH_PROJECTS.map((p) => [p, 'WN_TECH']),
  ...WN_HIS_PROJECTS.map((p) => [p, 'wn_his']),
]);

/**
 * 获取配置文件路径
 */
function getConfigPath() {
  // 相对于工具文件的位置，找到 config 目录
  const toolDir = __dirname;
  const skillDir = path.dirname(toolDir);
  return path.join(skillDir, 'config', 'tfs-config.json');
}

/**
 * 格式化日期为TFS WIQL格式 (TFS 2018 需要日期格式 YYYY-MM-DD，不能包含时间部分)
 */
function formatDateForWIQL(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * 加载配置
 */
function loadConfig() {
  const configPath = getConfigPath();

  if (!fs.existsSync(configPath)) {
    throw new Error(
      '配置文件不存在: ' +
        configPath +
        '\n' +
        '请先创建配置文件，格式如下:\n' +
        '{\n' +
        '  "serverUrl": "http://tfs2018-web.winning.com.cn:8080/tfs/WINNING-6.0",\n' +
        '  "pat": "your-personal-access-token",\n' +
        '  "defaultCollection": "WINNING-6.0"  // 可选\n' +
        '}\n\n' +
        '获取 PAT Token:\n' +
        '1. 登录 TFS: http://tfs2018-web.winning.com.cn:8080/tfs/\n' +
        '2. 用户头像 → 安全 → +添加 → 个人访问令牌\n' +
        '3. 选择权限: 工作项(读取、管理)、代码(读取)'
    );
  }

  const configContent = fs.readFileSync(configPath, 'utf-8');
  const config = JSON.parse(configContent);

  return {
    serverUrl: config.serverUrl || DEFAULT_SERVER_URL,
    pat: config.pat,
    defaultCollection: config.defaultCollection || 'WINNING-6.0',
    defaultProject: config.defaultProject || null,
    defaultAssignee: config.defaultAssignee || null,
  };
}

/**
 * 保存配置
 */
function saveConfig(serverUrl, pat, defaultCollection = null) {
  const configPath = getConfigPath();
  const configDir = path.dirname(configPath);

  // 确保目录存在
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  const config = {
    serverUrl: serverUrl || DEFAULT_SERVER_URL,
    pat: pat,
  };

  // 只有在明确指定时才添加 defaultCollection
  if (defaultCollection) {
    config.defaultCollection = defaultCollection;
  }

  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  console.log('配置已保存到:', configPath);
}

/**
 * 保存默认集合
 */
function saveDefaultCollection(collectionName) {
  const configPath = getConfigPath();
  const configContent = fs.readFileSync(configPath, 'utf-8');
  const config = JSON.parse(configContent);

  config.defaultCollection = collectionName;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}

/**
 * 保存默认项目
 */
function saveDefaultProject(projectName) {
  const configPath = getConfigPath();
  const configContent = fs.readFileSync(configPath, 'utf-8');
  const config = JSON.parse(configContent);

  config.defaultProject = projectName;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}

/**
 * 解析项目名称，返回项目 ID 和所属集合
 * @param {string} projectName - 项目名称
 * @returns {object} { projectId, collectionName, collectionUrl }
 */
function resolveProject(projectName) {
  const projectId = PROJECTS[projectName];

  if (!projectId) {
    return null;
  }

  // 查找项目所属的集合
  const collectionName = PROJECT_TO_COLLECTION[projectName];
  const collection = COLLECTIONS[collectionName];

  return {
    projectId,
    collectionName,
    collectionUrl: collection?.url,
  };
}

/**
 * TFS 客户端类
 */
class TFSClient {
  constructor(collectionName = null) {
    const config = loadConfig();
    // 使用指定的集合或默认集合
    const targetCollection = collectionName || config.defaultCollection || 'WINNING-6.0';
    this.collectionName = targetCollection;
    this.serverUrl = COLLECTIONS[targetCollection]?.url || config.serverUrl;
    this.pat = config.pat;
    this.authHandler = azureDevOps.getPersonalAccessTokenHandler(config.pat);
    this.connection = new azureDevOps.WebApi(this.serverUrl, this.authHandler);
    this.witApi = null;
    this.gitApi = null;
  }

  /**
   * 获取当前集合名称
   */
  getCollectionName() {
    return this.collectionName;
  }

  /**
   * 切换到指定集合
   */
  switchCollection(collectionName) {
    if (!COLLECTIONS[collectionName]) {
      throw new Error(
        `集合不存在: ${collectionName}。可用集合: ${Object.keys(COLLECTIONS).join(', ')}`
      );
    }

    this.collectionName = collectionName;
    this.serverUrl = COLLECTIONS[collectionName].url;
    this.connection = new azureDevOps.WebApi(this.serverUrl, this.authHandler);
    this.witApi = null;
    this.gitApi = null;
  }

  /**
   * 获取当前PAT对应的用户信息
   * @returns {Promise<object>} { displayName, uniqueName, accountName, domain }
   */
  async getCurrentUser() {
    // 尝试通过 API 获取当前用户信息
    // TFS 2018 的方式：通过查询当前用户的工作项来推断用户身份
    const witApi = await this.getWorkItemApi();

    // 使用 WIQL 查询 @me 的任务来获取用户信息
    const wiql = `
      SELECT [System.Id], [System.AssignedTo]
      FROM WorkItems
      WHERE [System.AssignedTo] = @me
      ORDER BY [System.ChangedDate] DESC
    `;

    try {
      const queryResult = await witApi.queryByWiql({ query: wiql }, null, 1);

      if (queryResult.workItems && queryResult.workItems.length > 0) {
        // 获取第一个工作项的详细信息以提取用户信息
        const workItem = await witApi.getWorkItem(queryResult.workItems[0].id, ['System.AssignedTo'], null, 'All', null);

        if (workItem && workItem.fields && workItem.fields['System.AssignedTo']) {
          const assignedTo = workItem.fields['System.AssignedTo'];
          return {
            displayName: assignedTo.displayName || '',
            uniqueName: assignedTo.uniqueName || '',  // 格式: WINNING\jia_wl
            accountName: this.extractAccountName(assignedTo.uniqueName || assignedTo.displayName || ''),
            domain: 'WINNING'
          };
        }
      }

      // 如果查询不到，返回 null 表示无法自动获取
      return null;
    } catch (error) {
      // API 调用失败，返回 null
      console.warn('无法通过API获取当前用户信息:', error.message);
      return null;
    }
  }

  /**
   * 从用户名中提取账号部分
   * @param {string} uniqueName - 格式如 "WINNING\jia_wl" 或 "jia_wl"
   * @returns {string} 账号名（如 "jia_wl"）
   */
  extractAccountName(uniqueName) {
    if (uniqueName.includes('\\')) {
      return uniqueName.split('\\')[1];
    }
    if (uniqueName.includes('/')) {
      return uniqueName.split('/')[1];
    }
    return uniqueName;
  }

  /**
   * 获取默认指派给用户名（从配置或自动检测）
   * @returns {Promise<string|null>} TFS 格式的用户名（如 "WINNING\jia_wl"）或 null
   */
  async getDefaultAssignee() {
    // 优先从配置读取
    const config = loadConfig();

    if (config.defaultAssignee) {
      // 配置中已设置，直接返回
      // 支持两种格式：完整格式 "WINNING\jia_wl" 或简写 "jia_wl"
      if (config.defaultAssignee.includes('\\')) {
        return config.defaultAssignee;
      }
      return `WINNING\\${config.defaultAssignee}`;
    }

    // 尝试通过 PAT 自动获取
    const currentUser = await this.getCurrentUser();

    if (currentUser && currentUser.uniqueName) {
      // 已获取到完整格式
      if (currentUser.uniqueName.includes('\\')) {
        return currentUser.uniqueName;
      }
      // 构造标准格式
      return `${currentUser.domain}\\${currentUser.accountName}`;
    }

    // 无法获取，返回 null
    return null;
  }

  /**
   * 获取工作项跟踪 API
   */
  async getWorkItemApi() {
    if (!this.witApi) {
      this.witApi = await this.connection.getWorkItemTrackingApi();
    }
    return this.witApi;
  }

  /**
   * 获取 Git API
   */
  async getGitApi() {
    if (!this.gitApi) {
      this.gitApi = await this.connection.getGitApi();
    }
    return this.gitApi;
  }

  /**
   * 按 ID 获取单个工作项
   * API: getWorkItem(id, fields, asOf, expand, project)
   */
  async getWorkItem(id, project = null) {
    const witApi = await this.getWorkItemApi();
    return await witApi.getWorkItem(id, null, null, 'All', project);
  }

  /**
   * 批量获取工作项
   * API: getWorkItems(ids, fields, asOf, expand, errorPolicy, project)
   */
  async getWorkItems(ids, project = null) {
    const witApi = await this.getWorkItemApi();
    return await witApi.getWorkItems(ids, null, null, 'All', null, project);
  }

  /**
   * 使用 WIQL 查询工作项
   */
  async queryWorkItems(wiql, project = null) {
    const witApi = await this.getWorkItemApi();
    const queryResult = await witApi.queryByWiql({ query: wiql });

    if (!queryResult.workItems || queryResult.workItems.length === 0) {
      return [];
    }

    const ids = queryResult.workItems.map((wi) => wi.id);
    // 注意：TFS 2018 API 的 getWorkItems 第6个参数（project）不能传入字符串值，否则会返回 undefined
    // 因此这里不传入 project 参数，依赖 WIQL 查询时的项目过滤
    // 另外：批量获取大量工作项时，分批获取以避免 API 返回部分失败
    const batchSize = 50;
    const allWorkItems = [];

    for (let i = 0; i < ids.length; i += batchSize) {
      const batch = ids.slice(i, i + batchSize);
      const items = await witApi.getWorkItems(batch, null, null, 'All', null);
      if (items && Array.isArray(items)) {
        allWorkItems.push(...items);
      }
    }

    return allWorkItems;
  }

  /**
   * 按 TFS 中「已保存查询」的 ID（通常为 GUID）执行查询并返回完整工作项列表
   * @param {string} queryId - 已保存查询 ID
   * @param {object} [teamContext] - 可选团队/项目上下文（部分查询需要）
   * @param {number | undefined} top - 可选，限制返回条数
   */
  async queryWorkItemsByQueryId(queryId, teamContext = undefined, top = undefined) {
    const witApi = await this.getWorkItemApi();
    const queryResult = await witApi.queryById(queryId, teamContext, undefined, top);

    if (!queryResult.workItems || queryResult.workItems.length === 0) {
      return [];
    }

    const ids = queryResult.workItems.map((wi) => wi.id);
    const batchSize = 50;
    const allWorkItems = [];

    for (let i = 0; i < ids.length; i += batchSize) {
      const batch = ids.slice(i, i + batchSize);
      const items = await witApi.getWorkItems(batch, null, null, 'All', null);
      if (items && Array.isArray(items)) {
        allWorkItems.push(...items);
      }
    }

    return allWorkItems;
  }

  /**
   * 查询分配给我的活动任务
   */
  async getMyTasks(project = null) {
    let wiql = `
      SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo]
      FROM WorkItems
      WHERE [System.WorkItemType] = 'Task'
      AND [System.State] <> 'Closed'
      AND [System.AssignedTo] = @me
    `;

    if (project) {
      wiql += ` AND [System.TeamProject] = '${project}'`;
    }

    wiql += ' ORDER BY [System.ChangedDate] DESC';

    return await this.queryWorkItems(wiql, project);
  }

  /**
   * 查询未关闭的 Bug
   */
  async getOpenBugs(project = null) {
    let wiql = `
      SELECT [System.Id], [System.Title], [System.State], [Microsoft.VSTS.Common.Severity]
      FROM WorkItems
      WHERE [System.WorkItemType] = 'Bug'
      AND [System.State] <> 'Closed'
    `;

    if (project) {
      wiql += ` AND [System.TeamProject] = '${project}'`;
    }

    wiql += ' ORDER BY [System.CreatedDate] DESC';

    return await this.queryWorkItems(wiql, project);
  }

  /**
   * 查询近期已解决/已关闭的工作项
   * @param {string} project - 项目名称，null表示所有项目
   * @param {number} days - 最近天数，默认7天
   * @param {string[]} states - 状态列表，默认 ['Resolved', 'Closed']
   */
  async getRecentResolvedWorkItems(project = null, days = 7, states = ['Resolved', 'Closed']) {
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const startDateStr = formatDateForWIQL(startDate);
    const endDateStr = formatDateForWIQL(endDate);

    // TFS 2018 不支持 System.ClosedDate 和 System.ResolvedDate 字段
    // 使用 System.ChangedDate 进行日期过滤
    let wiql = `
      SELECT [System.Id], [System.Title], [System.WorkItemType],
             [System.State], [System.AssignedTo], [System.CreatedDate],
             [System.ChangedDate],
             [System.Description], [Microsoft.VSTS.Common.Priority],
             [Microsoft.VSTS.Common.Severity], [System.Reason]
      FROM WorkItems
      WHERE [System.State] IN (${states.map((s) => `'${s}'`).join(', ')})
      AND [System.ChangedDate] >= '${startDateStr}'
      AND [System.ChangedDate] <= '${endDateStr}'
    `;

    if (project) {
      wiql += ` AND [System.TeamProject] = '${project}'`;
    }

    wiql += ' ORDER BY [System.ChangedDate] DESC';

    return await this.queryWorkItems(wiql, project);
  }

  /**
   * 创建工作项
   * 使用直接 REST API（绕过 azure-devops-node-api 的 location GUID 路由，兼容 TFS 2018）
   *
   * @param {string} project - 项目名称
   * @param {string} workItemType - 工作项类型（如 "任务"、"需求"、"Bug"，中文名直接使用，英文名自动加 $ 前缀）
   * @param {object} fields - 字段键值对，支持两种格式：
   *   - 简单键：{ title, description, assignedTo, priority, parentId, finishDate, originalEstimate, tags, ... }
   *   - TFS 字段名：{ 'System.Title': '...', 'Microsoft.VSTS.Scheduling.OriginalEstimate': 2.0, ... }
   * @returns {Promise<object>} { success, id, url, workItem, message }
   */
  async createWorkItem(project, workItemType, fields) {
    // 映射简单键到 TFS 字段名
    const FIELD_MAP = {
      title: 'System.Title',
      description: 'System.Description',
      assignedTo: 'System.AssignedTo',
      priority: 'Microsoft.VSTS.Common.Priority',
      severity: 'Microsoft.VSTS.Common.Severity',
      tags: 'System.Tags',
      iterationPath: 'System.IterationPath',
      areaPath: 'System.AreaPath',
      startDate: 'Microsoft.VSTS.Scheduling.StartDate',
      finishDate: 'Microsoft.VSTS.Scheduling.FinishDate',
      originalEstimate: 'Microsoft.VSTS.Scheduling.OriginalEstimate',
    };

    const document = [];
    const parentId = fields.parentId || null;

    for (const [key, value] of Object.entries(fields)) {
      if (key === 'parentId') continue; // parentId 单独处理
      if (value === undefined || value === null) continue;

      const fieldName = FIELD_MAP[key] || key; // 如果已经是 TFS 字段名则直接用
      document.push({
        op: 'add',
        path: `/fields/${fieldName}`,
        value: fieldName === 'Microsoft.VSTS.Common.Priority' ? String(value) : value,
      });
    }

    // 添加父子关联
    if (parentId) {
      document.push({
        op: 'add',
        path: '/relations/-',
        value: {
          rel: 'System.LinkTypes.Hierarchy-Reverse',
          url: `${this.serverUrl}/_apis/wit/workItems/${parentId}`,
          attributes: { isLocked: false },
        },
      });
    }

    // 构建 URL：{serverUrl}/{project}/_apis/wit/workitems/${type}?api-version=4.1
    // TFS 2018 需要在类型前加 $ 符号（如 $任务、$Bug）
    // 支持英文类型名自动映射为中文（TFS 2018 REST API 要求中文）
    const TYPE_NAME_MAP = {
      'Task': '任务',
      'Bug': 'Bug',
      'User Story': '需求',
      'Issue': '问题',
      'Test Case': '用例',
    };
    const mappedType = TYPE_NAME_MAP[workItemType] || workItemType;
    const typeName = mappedType.startsWith('$') ? mappedType : `$${mappedType}`;
    const createUrl = `${this.serverUrl}/${encodeURIComponent(project)}/_apis/wit/workitems/${encodeURIComponent(typeName)}?api-version=4.1`;

    const auth = Buffer.from(`:${this.pat}`).toString('base64');
    const body = JSON.stringify(document);

    const response = await new Promise((resolve, reject) => {
      const urlObj = new URL(createUrl);
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
        res.on('end', () => resolve({ statusCode: res.statusCode, body: data }));
      });
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    if (response.statusCode !== 200) {
      let errorMsg = `创建工作项失败: HTTP ${response.statusCode}`;
      try {
        const err = JSON.parse(response.body);
        errorMsg += `\n${err.message || response.body}`;
      } catch (e) {
        errorMsg += `\n${response.body}`;
      }
      throw new Error(errorMsg);
    }

    const createdWorkItem = JSON.parse(response.body);

    // 返回兼容格式：顶层包含 id/fields/_links 供旧调用方使用，同时提供 success/workItem
    return Object.assign(createdWorkItem, {
      success: true,
      message: `成功创建工作项 ${createdWorkItem.id} (${workItemType})`,
    });
  }

  /**
   * 更新工作项状态
   */
  async updateWorkItemState(id, newState, comment = null) {
    const witApi = await this.getWorkItemApi();
    const document = [{ op: 'replace', path: '/fields/System.State', value: newState }];

    if (comment) {
      document.push({
        op: 'add',
        path: '/fields/System.History',
        value: comment,
      });
    }

    return await witApi.updateWorkItem(null, document, id);
  }

  /**
   * 添加评论
   */
  async addComment(workItemId, comment) {
    const witApi = await this.getWorkItemApi();
    const document = [{ op: 'add', path: '/fields/System.History', value: comment }];
    return await witApi.updateWorkItem(null, document, workItemId);
  }

  /**
   * 上传附件到 TFS
   * @param {string} filePath - 本地文件路径
   * @param {string} fileName - 上传到 TFS 后显示的文件名
   * @returns {Promise<string>} 附件的 URL
   */
  async uploadAttachment(filePath, fileName = null) {
    const fileNameToUse = fileName || path.basename(filePath);
    const encodedFileName = encodeURIComponent(fileNameToUse);
    const apiUrl = `${this.serverUrl}/_apis/wit/attachments?fileName=${encodedFileName}&uploadType=simple&api-version=4.1`;

    const fileData = fs.readFileSync(filePath);
    const auth = Buffer.from(`:${this.pat}`).toString('base64');

    return new Promise((resolve, reject) => {
      const urlObj = new URL(apiUrl);
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port,
        path: urlObj.pathname + urlObj.search,
        method: 'POST',
        headers: {
          'Authorization': `Basic ${auth}`,
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileData.length
        }
      };

      const client = urlObj.protocol === 'https:' ? https : http;
      const req = client.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const result = JSON.parse(data);
            if (result.url) {
              resolve(result.url);
            } else if (result.id) {
              resolve(`${this.serverUrl}/_apis/wit/attachments/${result.id}?fileName=${encodedFileName}`);
            } else {
              reject(new Error(`上传附件失败: ${data}`));
            }
          } catch (e) {
            reject(new Error(`上传附件失败: ${data}`));
          }
        });
      });
      req.on('error', reject);
      req.write(fileData);
      req.end();
    });
  }

  /**
   * 添加带图片的评论
   * @param {number|string} workItemId - 工作项 ID
   * @param {string} comment - 评论内容（支持 HTML）
   * @param {string|Array} imagePaths - 本地图片路径或路径数组
   * @returns {Promise<Object>} 更新后的工作项
   */
  async addCommentWithImages(workItemId, comment, imagePaths = []) {
    const images = Array.isArray(imagePaths) ? imagePaths : [imagePaths];
    const imageUrls = [];

    for (const imagePath of images) {
      if (imagePath && fs.existsSync(imagePath)) {
        const url = await this.uploadAttachment(imagePath);
        imageUrls.push(url);
      }
    }

    let finalComment = comment;
    if (imageUrls.length > 0) {
      const imageTags = imageUrls.map(url => `<img src="${url}" style="width:800px;"/><br/>`).join('');
      finalComment = comment + '<br/><br/>' + imageTags;
    }

    return await this.addComment(workItemId, finalComment);
  }

  /**
   * 添加附件到工作项（通过 Relations）
   * @param {number|string} workItemId - 工作项 ID
   * @param {string} filePath - 本地文件路径
   * @param {string} comment - 附件说明
   * @returns {Promise<Object>} 更新后的工作项
   */
  async addAttachmentToWorkItem(workItemId, filePath, comment = '') {
    const fileName = path.basename(filePath);
    const attachmentUrl = await this.uploadAttachment(filePath, fileName);

    const witApi = await this.getWorkItemApi();
    const document = [{
      op: 'add',
      path: '/relations/-',
      value: {
        rel: 'AttachedFile',
        url: attachmentUrl,
        attributes: {
          comment: comment || '附件'
        }
      }
    }];

    return await witApi.updateWorkItem(null, document, workItemId);
  }

  /**
   * 添加评论、截图到评论、添加附件到工作项
   * @param {number|string} workItemId - 工作项 ID
   * @param {string} comment - 评论内容
   * @param {string|Array} filePaths - 本地文件路径或路径数组（PNG 嵌入评论，HTML 及其他只添加附件）
   * @param {boolean} addAsAttachment - 是否同时添加为附件
   * @returns {Promise<Object>} 更新后的工作项
   */
  async addCommentWithImagesAndAttachment(workItemId, comment, filePaths = [], addAsAttachment = true) {
    const files = Array.isArray(filePaths) ? filePaths : [filePaths];
    const imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
    const imageFiles = [];
    const allFiles = [];

    for (const filePath of files) {
      if (filePath && fs.existsSync(filePath)) {
        const ext = path.extname(filePath).toLowerCase();
        allFiles.push(filePath);
        if (imageExtensions.includes(ext)) {
          imageFiles.push(filePath);
        }
      }
    }

    const result = await this.addCommentWithImages(workItemId, comment, imageFiles);

    if (addAsAttachment) {
      for (const filePath of allFiles) {
        const ext = path.extname(filePath).toLowerCase();
        const attType = ext === '.html' ? '缺陷回归测试报告' : '缺陷回归测试截图';
        await this.addAttachmentToWorkItem(workItemId, filePath, attType);
      }
    }

    return result;
  }

  /**
   * 更新工作项的分配人
   * @param {number|string} id - 工作项 ID
   * @param {string} assignedTo - TFS 用户显示名或账号
   * @param {string} comment - 可选评论
   */
  async updateAssignedTo(id, assignedTo, comment = null) {
    const witApi = await this.getWorkItemApi();
    const document = [
      { op: 'replace', path: '/fields/System.AssignedTo', value: assignedTo }
    ];

    if (comment) {
      document.push({
        op: 'add',
        path: '/fields/System.History',
        value: comment
      });
    }

    return await witApi.updateWorkItem(null, document, id);
  }

  /**
   * 更新工作项的多个字段
   * @param {number|string} id - 工作项 ID
   * @param {Object} fields - 字段名到值的映射 { "System.State": "Closed", ... }
   * @param {string} comment - 可选评论
   */
  async updateWorkItemFields(id, fields, comment = null) {
    const witApi = await this.getWorkItemApi();
    const document = [];

    for (const [path, value] of Object.entries(fields)) {
      document.push({
        op: 'replace',
        path: path.startsWith('/') ? path : `/fields/${path}`,
        value
      });
    }

    if (comment) {
      document.push({
        op: 'add',
        path: '/fields/System.History',
        value: comment
      });
    }

    return await witApi.updateWorkItem(null, document, id);
  }

  /**
   * 获取工作项的修订历史
   * @param {number|string} id - 工作项 ID
   * @returns {Promise<Array>} 修订历史数组
   */
  async getWorkItemRevisions(id) {
    const witApi = await this.getWorkItemApi();
    const revisions = await witApi.getRevisions(id);
    return revisions || [];
  }

  /**
   * 获取工作项的修订数量
   * @param {number|string} id - 工作项 ID
   * @returns {Promise<number>} 修订次数
   */
  async getWorkItemRevisionCount(id) {
    const revisions = await this.getWorkItemRevisions(id);
    return revisions.length;
  }

  /**
   * 为工作项添加标签（保留现有标签）
   * @param {number|string} id - 工作项 ID
   * @param {string|Array} tags - 要添加的标签（字符串或数组）
   * @param {string} existingTags - 可选，现有标签字符串（避免额外 API 调用）
   * @returns {Promise<Object>} 更新后的工作项
   */
  async addTags(id, tags, existingTags = null) {
    const witApi = await this.getWorkItemApi();

    // 标准化为数组
    const tagsToAdd = Array.isArray(tags) ? tags : [tags];

    // 获取现有标签（如果未提供则调用 API）
    let tagList = [];
    if (existingTags !== null) {
      // 复用调用方提供的标签
      tagList = existingTags
        ? existingTags.split(';').map(t => t.trim()).filter(t => t)
        : [];
    } else {
      // 获取当前工作项以获取现有标签
      // 注意：API 签名是 getWorkItem(id, fields, asOf, expand, project)
      const workItem = await witApi.getWorkItem(id, null, null, 'All', null);
      if (!workItem || !workItem.fields) {
        // 工作项不存在或无 fields，从空标签开始
        tagList = [];
      } else {
        const currentTags = workItem.fields?.['System.Tags'] || '';
        tagList = currentTags ? currentTags.split(';').map(t => t.trim()).filter(t => t) : [];
      }
    }

    // 添加新标签（去重）
    for (const tag of tagsToAdd) {
      if (!tagList.includes(tag)) {
        tagList.push(tag);
      }
    }

    // 构建更新文档
    const newTagsValue = tagList.join('; ');
    const document = [
      { op: 'replace', path: '/fields/System.Tags', value: newTagsValue }
    ];

    return await witApi.updateWorkItem(null, document, id);
  }

  /**
   * 获取项目的 Git 仓库列表
   */
  async getRepositories(project) {
    const gitApi = await this.getGitApi();
    return await gitApi.getRepositories(project);
  }

  /**
   * 获取最近的提交记录
   * @param {string} repositoryId - 仓库ID
   * @param {string} project - 项目名称
   * @param {number} top - 返回记录数，默认20
   * @param {number} days - 最近天数，用于客户端日期过滤，默认null（不过滤）
   */
  async getCommits(repositoryId, project, top = 20, days = null) {
    const gitApi = await this.getGitApi();

    // TFS 2018 API 的日期参数可能不工作，需要先获取提交后在客户端过滤
    const commits = await gitApi.getCommits(
      repositoryId,
      project,
      null, // branch
      null, // requestorId
      null, // itemPath
      top,
      null, // skip
      null, // includeLinks
      null, // fromDate - TFS 2018 可能不支持
      null // toDate - TFS 2018 可能不支持
    );

    // 如果指定了天数，在客户端进行日期过滤
    if (days) {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - days);

      return commits.filter((commit) => {
        const commitDate = new Date(commit.author?.date || commit.committer?.date);
        return commitDate >= cutoffDate;
      });
    }

    return commits;
  }

  /**
   * 检查提交的工作项关联
   */
  async checkCommitWorkItems(repositoryId, projectId, commitId) {
    const gitApi = await this.getGitApi();
    const commit = await gitApi.getCommit(commitId, repositoryId, projectId);

    const workItems = commit.workItems || [];
    return {
      commitId: commitId,
      hasWorkItems: workItems.length > 0,
      workItemCount: workItems.length,
      workItems: workItems.map((wi) => ({
        id: wi.id,
        url: wi.url,
      })),
    };
  }

  /**
   * 获取项目 ID
   */
  getProjectId(projectName) {
    return PROJECTS[projectName];
  }

  /**
   * 获取所有项目列表
   */
  getProjects() {
    return { ...PROJECTS };
  }

  /**
   * 检查项目是否存在
   */
  hasProject(projectName) {
    return projectName in PROJECTS;
  }
}

/**
 * 查找项目所在的集合
 * @param {string} projectName - 项目名称
 * @returns {object|null} { collectionName, collectionUrl } 或 null
 */
export function findProjectCollection(projectName) {
  const result = resolveProject(projectName);
  if (result) {
    return {
      collectionName: result.collectionName,
      collectionUrl: result.collectionUrl,
    };
  }
  return null;
}

/**
 * 获取所有集合信息
 */
export function getCollections() {
  return { ...COLLECTIONS };
}

/**
 * 获取默认集合名称
 */
export function getDefaultCollection() {
  const config = loadConfig();
  return config.defaultCollection || 'WINNING-6.0';
}

/**
 * 获取默认项目名称
 */
export function getDefaultProject() {
  const config = loadConfig();
  return config.defaultProject || null;
}

/**
 * 设置默认集合
 */
export function setDefaultCollection(collectionName) {
  if (!COLLECTIONS[collectionName]) {
    throw new Error(
      `集合不存在: ${collectionName}。可用集合: ${Object.keys(COLLECTIONS).join(', ')}`
    );
  }
  saveDefaultCollection(collectionName);
}

/**
 * 设置默认项目
 */
export function setDefaultProject(projectName) {
  if (!PROJECTS[projectName]) {
    throw new Error(
      `项目不存在: ${projectName}。可用项目: ${Object.keys(PROJECTS).join(', ')}`
    );
  }
  saveDefaultProject(projectName);
}

// 导出
export default TFSClient;
export { loadConfig, saveConfig, PROJECTS, COLLECTIONS, PROJECT_TO_COLLECTION };
