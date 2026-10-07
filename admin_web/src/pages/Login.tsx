import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { login } from '@/api';

const Login = () => {
  const [account, setAccount] = useState('admin');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!account.trim() || !password) {
      setError('请输入账号和密码');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await login(account.trim(), password);
      navigate('/questions');
    } catch (err: any) {
      setError(err.response?.data?.detail || '登录失败，请检查账号密码');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 px-4">
      <div className="w-full max-w-sm rounded-2xl bg-white p-8 shadow-xl shadow-slate-200/50">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-[#6C63FF]/10">
            <span className="text-2xl font-bold text-[#6C63FF]">AI</span>
          </div>
          <h2 className="text-2xl font-bold tracking-tight text-slate-900">医疗问诊后台</h2>
          <p className="mt-2 text-sm text-slate-500">请输入管理员账号密码登录</p>
        </div>
        <form onSubmit={handleLogin} className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">账号</label>
            <Input type="text" value={account} onChange={e => setAccount(e.target.value)} placeholder="请输入管理员账号" required />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-slate-700">密码</label>
            <Input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="请输入密码" required />
          </div>
          {error && <div className="rounded-md bg-red-50 p-3 text-sm text-red-600">{error}</div>}
          <Button type="submit" className="w-full shadow-md shadow-[#6C63FF]/20" disabled={loading}>
            {loading ? '登录中…' : '登录'}
          </Button>
        </form>
      </div>
    </div>
  );
};

export default Login;
