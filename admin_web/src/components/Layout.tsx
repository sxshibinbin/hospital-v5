import React from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import { FileClock, FileText, LayoutDashboard, LogOut, MessageCircleQuestion, MessageSquareText, Settings, Users, ShieldCheck } from 'lucide-react';
import { logout } from '@/api';

const Layout = () => {
  const location = useLocation();
  const isLogsPage = location.pathname === '/logs';
  const navItems = [
    { path: '/dashboard', label: '仪表盘', icon: <LayoutDashboard size={20} /> },
    { path: '/users', label: '用户管理', icon: <Users size={20} /> },
    { path: '/questions', label: '高频问题管理', icon: <MessageCircleQuestion size={20} /> },
    { path: '/feedback', label: 'AI 回复反馈', icon: <MessageSquareText size={20} /> },
    { path: '/ai-safety', label: 'AI 安全机制', icon: <ShieldCheck size={20} /> },
    { path: '/ai-safety/intent-rules', label: '意图规则 / 标准回答', icon: <ShieldCheck size={18} /> },
    { path: '/ai-safety/words', label: '敏感词库', icon: <ShieldCheck size={18} /> },
    { path: '/agreements', label: '协议与隐私', icon: <FileText size={20} /> },
    { path: '/logs', label: '日志管理', icon: <FileClock size={20} /> },
    { path: '/settings', label: '系统设置', icon: <Settings size={20} /> },
  ];
  const activeItem = navItems.find(item => item.path === location.pathname) || navItems[0];
  return <div className="flex h-screen w-full bg-slate-50"><aside className="flex w-64 flex-shrink-0 flex-col bg-slate-900 text-white shadow-xl"><div className="flex h-16 items-center border-b border-slate-800 px-6 text-xl font-bold tracking-wide"><span className="text-[#6C63FF]">AI</span> 医疗问诊后台</div><nav className="flex-1 space-y-2 overflow-y-auto px-3 py-6">{navItems.map(item => { const active = location.pathname === item.path; return <Link key={item.path} to={item.path} className={`flex items-center space-x-3 rounded-lg px-4 py-3 transition-all duration-200 ${active ? 'bg-[#6C63FF] text-white shadow-md shadow-[#6C63FF]/20' : 'text-slate-400 hover:bg-slate-800 hover:text-slate-100'}`}>{item.icon}<span className="font-medium">{item.label}</span></Link>; })}</nav><div className="flex items-center justify-between border-t border-slate-800 p-4 text-sm text-slate-500"><span>Admin User</span><button onClick={() => { void logout(); }} className="rounded-md p-1.5 hover:bg-slate-800" title="退出登录"><LogOut size={16} /></button></div></aside><main className="flex min-h-0 flex-1 flex-col overflow-hidden"><header className="z-10 flex h-16 items-center justify-between border-b border-slate-200 bg-white px-8 shadow-sm"><h1 className="text-xl font-semibold text-slate-800">{activeItem.label}</h1><div className="flex h-8 w-8 items-center justify-center rounded-full bg-[#6C63FF]/10 font-bold text-[#6C63FF]">A</div></header><div className={`min-h-0 flex-1 p-8 ${isLogsPage ? 'overflow-hidden' : 'overflow-auto'}`}><Outlet /></div></main></div>;
};
export default Layout;
