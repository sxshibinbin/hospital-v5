import React, { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { FileText, Save, Settings as SettingsIcon } from 'lucide-react';
import { getAgreements, updateAgreement } from '@/api';
import MDEditor from '@uiw/react-md-editor';

const Agreements = () => {
  const [loading, setLoading] = useState(true);
  const [savingAgreement, setSavingAgreement] = useState(false);

  // Agreement State
  const [userAgreement, setUserAgreement] = useState('');
  const [privacyPolicy, setPrivacyPolicy] = useState('');

  const fetchAgreements = async () => {
    setLoading(true);
    try {
      const agreementsData = await getAgreements();
      const ua = agreementsData.find(a => a.type === 'user_agreement')?.content;
      const pp = agreementsData.find(a => a.type === 'privacy_policy')?.content;
      if (ua) setUserAgreement(ua);
      if (pp) setPrivacyPolicy(pp);
    } catch (error) {
      console.error('Failed to fetch agreements:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAgreements();
  }, []);

  const handleSaveAgreements = async () => {
    setSavingAgreement(true);
    try {
      await Promise.all([
        updateAgreement('user_agreement', '用户协议', userAgreement),
        updateAgreement('privacy_policy', '隐私政策', privacyPolicy)
      ]);
      alert('协议配置已保存成功！');
    } catch (error) {
      console.error('Failed to save agreements:', error);
      alert('保存协议失败，请重试');
    } finally {
      setSavingAgreement(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="flex items-center space-x-2 animate-pulse text-[#6C63FF]">
          <SettingsIcon size={24} className="animate-spin" />
          <span className="font-medium text-lg">加载协议配置中...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-6xl">
      <div className="flex justify-between items-center bg-white p-6 rounded-xl shadow-sm border border-slate-100">
        <div>
          <h2 className="text-2xl font-bold text-slate-800 flex items-center">
            <FileText className="mr-2 text-blue-600" />
            协议与隐私配置
          </h2>
          <p className="text-slate-500 mt-1 text-sm">
            配置小程序/APP端展示的《用户协议》与《隐私政策》，支持 Markdown 格式，所见即所得。
          </p>
        </div>
        <Button onClick={handleSaveAgreements} disabled={savingAgreement} className="shadow-md shadow-blue-600/20 bg-blue-600 hover:bg-blue-700 text-white">
          <Save className="w-4 h-4 mr-2" />
          {savingAgreement ? '保存中...' : '保存协议配置'}
        </Button>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-100 p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="space-y-3" data-color-mode="light">
            <label className="text-base font-semibold text-slate-800">用户协议 (Markdown)</label>
            <div className="rounded-md overflow-hidden border border-slate-200">
              <MDEditor
                value={userAgreement}
                onChange={(val) => setUserAgreement(val || '')}
                height={600}
                preview="live"
              />
            </div>
          </div>
          
          <div className="space-y-3" data-color-mode="light">
            <label className="text-base font-semibold text-slate-800">隐私政策 (Markdown)</label>
            <div className="rounded-md overflow-hidden border border-slate-200">
              <MDEditor
                value={privacyPolicy}
                onChange={(val) => setPrivacyPolicy(val || '')}
                height={600}
                preview="live"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Agreements;