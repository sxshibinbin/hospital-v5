import React, { useEffect, useState } from 'react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { ShieldCheck, Settings as SettingsIcon, Save } from 'lucide-react';
import { getSettings, updateSettings, updatePassword, Config } from '@/api';

const Settings = () => {
  const [configs, setConfigs] = useState<Config[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [savingPwd, setSavingPwd] = useState(false);

  // Form State
  const [highFreqThreshold, setHighFreqThreshold] = useState('10');
  const [systemName, setSystemName] = useState('AI 医疗问诊后台');

  // Password State
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const fetchConfigs = async () => {
    setLoading(true);
    try {
      const data = await getSettings();
      setConfigs(data);
      const threshold = data.find(c => c.key === 'high_freq_threshold')?.value;
      const sysName = data.find(c => c.key === 'system_name')?.value;
      if (threshold) setHighFreqThreshold(threshold);
      if (sysName) setSystemName(sysName);
    } catch (error) {
      console.error('Failed to fetch configs:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConfigs();
  }, []);

  const handleSaveConfigs = async () => {
    setSaving(true);
    try {
      await updateSettings([
        { key: 'high_freq_threshold', value: highFreqThreshold },
        { key: 'system_name', value: systemName },
      ]);
      alert('系统配置已保存成功！');
      fetchConfigs();
    } catch (error) {
      console.error('Failed to save configs:', error);
      alert('保存失败，请重试');
    } finally {
      setSaving(false);
    }
  };

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      alert('两次输入的新密码不一致！');
      return;
    }
    if (newPassword.length < 6) {
      alert('新密码长度不能少于 6 位！');
      return;
    }
    
    setSavingPwd(true);
    try {
      await updatePassword(oldPassword, newPassword);
      alert('密码修改成功，请牢记您的新密码。');
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (error: any) {
      console.error('Failed to update password:', error);
      alert(error.response?.data?.detail || '修改密码失败，请检查原密码是否正确');
    } finally {
      setSavingPwd(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="flex items-center space-x-2 animate-pulse text-[#6C63FF]">
          <SettingsIcon size={24} className="animate-spin" />
          <span className="font-medium text-lg">加载系统配置中...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex justify-between items-center bg-white p-6 rounded-xl shadow-sm border border-slate-100">
        <div>
          <h2 className="text-2xl font-bold text-slate-800 flex items-center">
            <SettingsIcon className="mr-2 text-[#6C63FF]" />
            系统全局设置
          </h2>
          <p className="text-slate-500 mt-1 text-sm">
            管理平台的基础业务参数以及管理员的安全选项。
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* 左侧：业务参数配置 */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-100 p-6 flex flex-col h-full">
          <div className="border-b border-slate-100 pb-4 mb-6">
            <h3 className="text-lg font-semibold text-slate-800 flex items-center">
              业务参数配置
            </h3>
            <p className="text-xs text-slate-500 mt-1">
              调整高频问题触发逻辑及基础应用信息。
            </p>
          </div>

          <div className="space-y-5 flex-1">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">系统名称</label>
              <Input
                value={systemName}
                onChange={(e) => setSystemName(e.target.value)}
                placeholder="例如：AI 医疗问诊后台"
              />
              <p className="text-xs text-slate-400">将显示在导航栏顶部及登录页。</p>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">高频问题候选阈值 (次/日)</label>
              <Input
                type="number"
                value={highFreqThreshold}
                onChange={(e) => setHighFreqThreshold(e.target.value)}
                placeholder="例如：10"
              />
              <p className="text-xs text-slate-400">
                若单日相同语义的提问达到此阈值，将自动进入后台待审核高频库 (第二期功能)。
              </p>
            </div>
          </div>

          <div className="pt-6 mt-4 border-t border-slate-100 flex justify-end">
            <Button onClick={handleSaveConfigs} disabled={saving} className="shadow-md shadow-[#6C63FF]/20">
              <Save className="w-4 h-4 mr-2" />
              {saving ? '保存中...' : '保存配置'}
            </Button>
          </div>
        </div>

        {/* 右侧：管理员安全设置 */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-100 p-6 flex flex-col h-full">
          <div className="border-b border-slate-100 pb-4 mb-6">
            <h3 className="text-lg font-semibold text-slate-800 flex items-center text-orange-600">
              <ShieldCheck className="w-5 h-5 mr-1.5" />
              安全与密码
            </h3>
            <p className="text-xs text-slate-500 mt-1">
              定期修改管理员密码以保障后台数据安全。
            </p>
          </div>

          <form onSubmit={handleUpdatePassword} className="space-y-5 flex-1">
            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">当前密码 <span className="text-red-500">*</span></label>
              <Input
                type="password"
                required
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                placeholder="请输入当前登录的密码"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">新密码 <span className="text-red-500">*</span></label>
              <Input
                type="password"
                required
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="请输入新密码（至少6位）"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium text-slate-700">确认新密码 <span className="text-red-500">*</span></label>
              <Input
                type="password"
                required
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="请再次输入新密码"
              />
            </div>

            <div className="pt-6 mt-4 border-t border-slate-100 flex justify-end">
              <Button type="submit" variant="default" className="bg-slate-900 hover:bg-slate-800 text-white" disabled={savingPwd}>
                {savingPwd ? '修改中...' : '确认修改'}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Settings;