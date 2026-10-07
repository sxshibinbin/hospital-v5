import React, { useEffect, useState } from 'react';
import { Users, MessageSquare, FileText, Database, Activity, CalendarClock } from 'lucide-react';
import { getDashboardStats, DashboardStats } from '@/api';
import { maskPhone } from '@/lib/utils';

const Dashboard = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const data = await getDashboardStats();
        setStats(data);
      } catch (error) {
        console.error('Failed to fetch dashboard stats', error);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="flex items-center space-x-2 animate-pulse text-[#6C63FF]">
          <Activity size={24} />
          <span className="font-medium text-lg">加载数据大盘中...</span>
        </div>
      </div>
    );
  }

  if (!stats) return null;

  const statCards = [
    { title: '总注册用户', value: stats.total_users, icon: <Users size={24} className="text-blue-500" />, bg: 'bg-blue-50' },
    { title: '总会话记录', value: stats.total_sessions, icon: <MessageSquare size={24} className="text-emerald-500" />, bg: 'bg-emerald-50' },
    { title: '智能诊断卡片', value: stats.total_consultations, icon: <FileText size={24} className="text-purple-500" />, bg: 'bg-purple-50' },
    { title: '高频问题预设', value: stats.total_questions, icon: <Database size={24} className="text-orange-500" />, bg: 'bg-orange-50' },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-800">数据仪表盘</h2>
        <p className="text-slate-500 mt-1 text-sm">欢迎回来，以下是平台当前的整体运行数据概览。</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((card, idx) => (
          <div key={idx} className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className={`p-3 rounded-xl ${card.bg}`}>
                {card.icon}
              </div>
            </div>
            <div className="mt-4">
              <p className="text-sm font-medium text-slate-500">{card.title}</p>
              <h3 className="text-3xl font-bold text-slate-800 mt-1">{card.value}</h3>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* 最新注册用户 */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <h3 className="font-semibold text-slate-800 flex items-center">
              <Users size={18} className="mr-2 text-slate-400" /> 最新注册用户
            </h3>
          </div>
          <div className="divide-y divide-slate-100">
            {stats.recent_users.length === 0 ? (
              <div className="p-6 text-center text-slate-500 text-sm">暂无新用户</div>
            ) : (
              stats.recent_users.map(u => (
                <div key={u.id} className="p-4 px-6 flex items-center justify-between hover:bg-slate-50/50 transition-colors">
                  <div className="flex flex-col">
                    <span className="font-medium text-slate-800">{u.display_name}</span>
                    <span className="text-xs text-slate-500">{maskPhone(u.phone)}</span>
                  </div>
                  <div className="flex items-center text-xs text-slate-400">
                    <CalendarClock size={14} className="mr-1" />
                    {new Date(u.created_at).toLocaleDateString()}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* 最新问诊记录 */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <h3 className="font-semibold text-slate-800 flex items-center">
              <FileText size={18} className="mr-2 text-slate-400" /> 最新智能问诊记录
            </h3>
          </div>
          <div className="divide-y divide-slate-100">
            {stats.recent_consultations.length === 0 ? (
              <div className="p-6 text-center text-slate-500 text-sm">暂无新问诊记录</div>
            ) : (
              stats.recent_consultations.map(c => (
                <div key={c.id} className="p-4 px-6 flex items-center justify-between hover:bg-slate-50/50 transition-colors">
                  <div className="flex flex-col">
                    <span className="font-medium text-slate-800">报告 #{c.id}</span>
                    <span className="text-xs text-slate-500 mt-0.5">建议科室：{c.department}</span>
                  </div>
                  <div className="flex items-center text-xs text-slate-400">
                    <CalendarClock size={14} className="mr-1" />
                    {new Date(c.created_at).toLocaleDateString()}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;