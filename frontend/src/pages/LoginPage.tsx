import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button, Checkbox, Form, Input, message, QRCode, Tabs } from 'antd';
import { MobileOutlined, SafetyCertificateOutlined } from '@ant-design/icons';
import { cancelQrLoginSession, createQrLoginSession, fetchQrLoginStatus, sendSmsCode, loginWithSms } from '../api/auth';
import Logo from '../components/Logo';
import gsap from 'gsap';

type LoginFormValues = {
  phone: string;
  code: string;
};

const getErrorMessage = (error: unknown, fallback: string) => {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return fallback;
};

const USER_AGREEMENT_URL = 'https://web.sstkjgf.com/user-agreement.html';
const PRIVACY_POLICY_URL = 'https://web.sstkjgf.com/privacy-policy.html';

const LoginPage: React.FC = () => {
  const [form] = Form.useForm();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [loading, setLoading] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [activeTab, setActiveTab] = useState('sms');
  const [agreed, setAgreed] = useState(false);
  const [qrPayload, setQrPayload] = useState('');
  const [qrSessionId, setQrSessionId] = useState('');
  const [qrPcSecret, setQrPcSecret] = useState('');
  const [qrExpiresAt, setQrExpiresAt] = useState(0);
  const [qrStatus, setQrStatus] = useState<'idle' | 'loading' | 'pending' | 'scanned' | 'expired' | 'error'>('idle');
  const [qrNow, setQrNow] = useState(Date.now());

  useEffect(() => {
    if (searchParams.get('expired') === '1') {
      message.warning('登录已过期，请重新登录');
    }
  }, [searchParams]);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    if (countdown > 0) {
      timer = setInterval(() => {
        setCountdown((c) => c - 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [countdown]);

  useEffect(() => {
    gsap.fromTo(
      '.login-container',
      { opacity: 0, y: 20 },
      { opacity: 1, y: 0, duration: 0.6, ease: 'power4.out' }
    );
  }, []);

  const handleSendCode = async () => {
    if (!agreed) {
      message.error('请先阅读并同意《用户协议》和《隐私政策》');
      return;
    }
    try {
      const phone = form.getFieldValue('phone');
      if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
        message.error('请输入正确的手机号');
        return;
      }
      
      const res = await sendSmsCode(phone);
      if (res?.debug_mode) {
        message.success(
          `验证码发送成功（调试模式：${res.debug_code} 或随机码 ${res.code} 均可登录）`
        );
      } else {
        message.success('验证码发送成功');
      }
      setCountdown(60);
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '发送失败'));
    }
  };

  const handleLogin = async (values: LoginFormValues) => {
    try {
      setLoading(true);
      const res = await loginWithSms(values.phone, values.code);
      localStorage.setItem('token', res.access_token);
      message.success('登录成功');
      navigate('/chat', { replace: true });
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '登录失败'));
    } finally {
      setLoading(false);
    }
  };

  const stopQrPolling = () => {
    setQrSessionId('');
    setQrPcSecret('');
  };

  const loadQrSession = useCallback(async () => {
    if (!agreed) {
      message.error('请先阅读并同意《用户协议》和《隐私政策》');
      return;
    }
    stopQrPolling();
    setQrStatus('loading');
    try {
      const session = await createQrLoginSession();
      setQrPayload(session.qr_payload);
      setQrSessionId(session.session_id);
      setQrPcSecret(session.pc_secret);
      setQrExpiresAt(new Date(session.expires_at).getTime());
      setQrNow(Date.now());
      setQrStatus('pending');
    } catch (error: unknown) {
      setQrStatus('error');
      message.error(getErrorMessage(error, '二维码生成失败'));
    }
  }, [agreed]);

  useEffect(() => {
    if (activeTab !== 'qrcode' || !agreed) {
      return;
    }
    if (!qrSessionId) {
      void loadQrSession();
    }
  }, [activeTab, agreed, qrSessionId, loadQrSession]);

  useEffect(() => {
    if (activeTab !== 'qrcode' || !qrSessionId || !qrPcSecret || qrStatus !== 'pending' && qrStatus !== 'scanned') {
      return;
    }
    const interval = window.setInterval(async () => {
      setQrNow(Date.now());
      if (Date.now() >= qrExpiresAt) {
        setQrStatus('expired');
        window.clearInterval(interval);
        return;
      }
      try {
        const status = await fetchQrLoginStatus(qrSessionId, qrPcSecret);
        if (status.status === 'confirmed' && status.access_token) {
          localStorage.setItem('token', status.access_token);
          setQrStatus('idle');
          window.clearInterval(interval);
          message.success('登录成功');
          navigate('/chat', { replace: true });
          return;
        }
        if (status.status === 'scanned') setQrStatus('scanned');
        if (status.status === 'expired' || status.status === 'rejected' || status.status === 'cancelled' || status.status === 'consumed') {
          setQrStatus(status.status === 'expired' ? 'expired' : 'error');
          stopQrPolling();
        }
      } catch (error: unknown) {
        if (Date.now() >= qrExpiresAt) return;
        message.error(getErrorMessage(error, '扫码状态查询失败'));
      }
    }, 2000);
    return () => window.clearInterval(interval);
  }, [activeTab, qrSessionId, qrPcSecret, qrStatus, qrExpiresAt, navigate]);

  useEffect(() => () => {
    if (qrSessionId && qrPcSecret) {
      void cancelQrLoginSession(qrSessionId, qrPcSecret).catch(() => undefined);
    }
  }, [qrSessionId, qrPcSecret]);

  const qrRemainingSeconds = Math.min(60, Math.max(0, Math.ceil((qrExpiresAt - qrNow) / 1000)));
  const showLegacyQrRefreshButton = false;

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-[radial-gradient(circle_at_top,rgba(99,102,241,0.16),transparent_28%),radial-gradient(circle_at_bottom_right,rgba(168,85,247,0.12),transparent_24%),linear-gradient(180deg,#eef1ff_0%,#f5f6ff_55%,#f6f3ff_100%)] px-4">
      <div className="login-container w-full max-w-md rounded-[24px] border border-white/60 bg-white/80 p-8 shadow-[0_20px_45px_rgba(149,157,215,0.14)] backdrop-blur-xl">
        <div className="mb-8 text-center">
          <Logo />
          <h1 className="text-2xl font-bold tracking-tight text-foreground">三十天时刻智护</h1>
          <p className="mt-2 text-sm text-muted-foreground">你的 AI 健康助手，随时为您服务</p>
        </div>

        <Tabs 
          activeKey={activeTab} 
          onChange={setActiveTab} 
          centered
          items={[
            {
              key: 'sms',
              label: '手机号登录',
              children: (
                <Form
                  form={form}
                  name="login"
                  onFinish={handleLogin}
                  layout="vertical"
                  size="large"
                  className="mt-4"
                >
                  <Form.Item
                    name="phone"
                    rules={[
                      { required: true, message: '请输入手机号' },
                      { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号格式' }
                    ]}
                  >
                    <Input 
                      prefix={<MobileOutlined className="text-muted-foreground" />} 
                      placeholder="请输入手机号" 
                      className="rounded-xl"
                    />
                  </Form.Item>

                  <Form.Item className="mb-0">
                    <div className="flex gap-3">
                      <Form.Item
                        name="code"
                        rules={[{ required: true, message: '请输入验证码' }]}
                        className="mb-0 flex-1"
                      >
                        <Input 
                          prefix={<SafetyCertificateOutlined className="text-muted-foreground" />} 
                          placeholder="请输入验证码" 
                          className="rounded-xl"
                        />
                      </Form.Item>
                      <Button 
                        onClick={handleSendCode} 
                        disabled={countdown > 0}
                        className="rounded-xl px-6"
                      >
                        {countdown > 0 ? `${countdown}s 后重试` : '获取验证码'}
                      </Button>
                    </div>
                  </Form.Item>

                  <Form.Item className="mb-0 mt-6">
                    <Button 
                      type="primary" 
                      htmlType="submit" 
                      loading={loading}
                      className="h-12 w-full rounded-xl border-0 bg-[linear-gradient(135deg,rgba(99,102,241,0.95),rgba(129,140,248,0.82))] text-base font-semibold shadow-[0_16px_34px_rgba(99,102,241,0.24)]"
                    >
                      登录 / 注册
                    </Button>
                  </Form.Item>
                </Form>
              )
            },
            {
              key: 'qrcode',
              label: 'App 扫码登录',
              children: (
                <div className="mt-8 flex flex-col items-center justify-center py-6">
                  {!agreed && (
                    <div className="flex h-48 w-48 items-center justify-center rounded-2xl border-2 border-dashed border-indigo-200 bg-indigo-50/50 px-6 text-center text-sm text-indigo-400">
                      请先勾选并同意用户协议
                    </div>
                  )}
                  {agreed && qrPayload && qrStatus !== 'expired' && qrStatus !== 'error' ? (
                    <QRCode value={qrPayload} size={192} bordered={false} />
                  ) : (
                    <div
                      className={`flex h-48 w-48 items-center justify-center rounded-2xl border-2 border-dashed border-indigo-200 bg-indigo-50/50 text-sm text-indigo-400 ${!agreed ? 'hidden' : ''}`}
                      onClick={agreed && (qrStatus === 'expired' || qrStatus === 'error') ? () => void loadQrSession() : undefined}
                      role={agreed && (qrStatus === 'expired' || qrStatus === 'error') ? 'button' : undefined}
                      tabIndex={agreed && (qrStatus === 'expired' || qrStatus === 'error') ? 0 : undefined}
                    >
                      {qrStatus === 'loading' ? '二维码生成中…' : '二维码已失效'}
                    </div>
                  )}
                  <p className="mt-6 text-sm font-medium text-foreground">请使用 App 扫一扫</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {qrStatus === 'scanned'
                      ? '已扫描，请在 App 中确认登录'
                      : qrStatus === 'expired'
                        ? '二维码已过期，请手动刷新'
                        : qrStatus === 'error'
                          ? '二维码状态异常，请重新刷新'
                          : `二维码有效期 ${qrRemainingSeconds} 秒`}
                  </p>
                  {showLegacyQrRefreshButton && (qrStatus === 'expired' || qrStatus === 'error' || !qrPayload) && (
                    <Button className="mt-4 rounded-xl" onClick={() => void loadQrSession()} loading={qrStatus === 'loading'}>
                      刷新二维码
                    </Button>
                  )}
                </div>
              )
            }
          ]}
        />
        
        <div className="mt-8 flex items-start justify-center gap-2 text-xs text-muted-foreground">
          <Checkbox
            checked={agreed}
            onChange={(e) => setAgreed(e.target.checked)}
            className="mt-[1px]"
          />
          <span>
            登录即代表您同意
            <a href={USER_AGREEMENT_URL} target="_blank" rel="noreferrer" className="text-indigo-500 hover:text-indigo-600 mx-1">《用户协议》</a>
            和
            <a href={PRIVACY_POLICY_URL} target="_blank" rel="noreferrer" className="text-indigo-500 hover:text-indigo-600 mx-1">《隐私政策》</a>
          </span>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
