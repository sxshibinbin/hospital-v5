import React, { useState } from 'react';
import { Layout, Menu, Table, Button, Space, Modal, Form, Input, InputNumber, Typography, Statistic, Card, Row, Col } from 'antd';
import {
  DashboardOutlined,
  QuestionCircleOutlined,
  EditOutlined,
  DeleteOutlined,
} from '@ant-design/icons';

const { Header, Sider, Content } = Layout;
const { Title } = Typography;

interface HighFreqQuestion {
  id: string;
  question: string;
  answer_template: string;
  frequency_threshold: number;
  click_rate: number;
}

const initialQuestions: HighFreqQuestion[] = [
  { id: '1', question: '孩子发烧反复应该怎么观察？', answer_template: '您好，针对孩子反复发烧的情况，建议前往[科室]就诊。在此之前可以尝试物理降温...', frequency_threshold: 100, click_rate: 1520 },
  { id: '2', question: '胃痛反复发作该挂什么科？', answer_template: '建议挂[科室]，通常是消化内科。', frequency_threshold: 50, click_rate: 890 },
];

const AdminPage: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false);
  const [activeMenu, setActiveMenu] = useState('dashboard');
  const [questions, setQuestions] = useState<HighFreqQuestion[]>(initialQuestions);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [editingQuestion, setEditingQuestion] = useState<HighFreqQuestion | null>(null);
  const [form] = Form.useForm();

  const handleEdit = (record: HighFreqQuestion) => {
    setEditingQuestion(record);
    form.setFieldsValue(record);
    setIsModalVisible(true);
  };

  const handleDelete = (id: string) => {
    setQuestions(questions.filter(q => q.id !== id));
  };

  const handleModalOk = () => {
    form.validateFields().then((values) => {
      if (editingQuestion) {
        setQuestions(questions.map(q => q.id === editingQuestion.id ? { ...q, ...values } : q));
      } else {
        const newQ = { id: Date.now().toString(), ...values, click_rate: 0 };
        setQuestions([...questions, newQ]);
      }
      setIsModalVisible(false);
    });
  };

  const columns = [
    { title: '问题', dataIndex: 'question', key: 'question' },
    { title: '答案模板', dataIndex: 'answer_template', key: 'answer_template', ellipsis: true },
    { title: '频次阈值', dataIndex: 'frequency_threshold', key: 'frequency_threshold' },
    { title: '点击量', dataIndex: 'click_rate', key: 'click_rate' },
    {
      title: '操作',
      key: 'action',
      render: (_: unknown, record: HighFreqQuestion) => (
        <Space size="middle">
          <Button type="link" icon={<EditOutlined />} onClick={() => handleEdit(record)}>编辑</Button>
          <Button type="link" danger icon={<DeleteOutlined />} onClick={() => handleDelete(record.id)}>删除</Button>
        </Space>
      ),
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed}>
        <div style={{ height: 32, margin: 16, background: 'rgba(255, 255, 255, 0.2)', borderRadius: 6 }} />
        <Menu
          theme="dark"
          defaultSelectedKeys={['dashboard']}
          mode="inline"
          onSelect={({ key }) => setActiveMenu(key)}
          items={[
            { key: 'dashboard', icon: <DashboardOutlined />, label: '数据看板' },
            { key: 'questions', icon: <QuestionCircleOutlined />, label: '高频问题管理' },
          ]}
        />
      </Sider>
      <Layout className="site-layout">
        <Header style={{ padding: 0, background: '#fff' }} />
        <Content style={{ margin: '0 16px' }}>
          <div style={{ padding: 24, minHeight: 360, marginTop: 16, background: '#fff' }}>
            {activeMenu === 'dashboard' && (
              <div>
                <Title level={4}>数据看板</Title>
                <Row gutter={16}>
                  <Col span={8}>
                    <Card>
                      <Statistic title="总提问次数" value={112893} />
                    </Card>
                  </Col>
                  <Col span={8}>
                    <Card>
                      <Statistic title="高频问题覆盖率" value={68} suffix="%" />
                    </Card>
                  </Col>
                  <Col span={8}>
                    <Card>
                      <Statistic title="用户好评率" value={95.6} suffix="%" />
                    </Card>
                  </Col>
                </Row>
              </div>
            )}
            {activeMenu === 'questions' && (
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
                  <Title level={4}>高频问题管理</Title>
                  <Button type="primary" onClick={() => {
                    setEditingQuestion(null);
                    form.resetFields();
                    setIsModalVisible(true);
                  }}>
                    新增问题
                  </Button>
                </div>
                <Table columns={columns} dataSource={questions} rowKey="id" />
              </div>
            )}
          </div>
        </Content>
      </Layout>

      <Modal
        title={editingQuestion ? "编辑问题" : "新增问题"}
        open={isModalVisible}
        onOk={handleModalOk}
        onCancel={() => setIsModalVisible(false)}
      >
        <Form form={form} layout="vertical">
          <Form.Item name="question" label="问题" rules={[{ required: true, message: '请输入问题' }]}>
            <Input />
          </Form.Item>
          <Form.Item name="answer_template" label="答案模板 (可使用 [科室] 变量)" rules={[{ required: true, message: '请输入答案模板' }]}>
            <Input.TextArea rows={4} />
          </Form.Item>
          <Form.Item name="frequency_threshold" label="频次阈值" rules={[{ required: true, message: '请输入频次阈值' }]}>
            <InputNumber min={1} style={{ width: '100%' }} />
          </Form.Item>
        </Form>
      </Modal>
    </Layout>
  );
};

export default AdminPage;
