import React, { useEffect, useState } from 'react';
import { checkAiSafety, getAiSafetyEvents } from '@/api';

const phaseText: Record<string, string> = { input: '输入拦截', output: '输出拦截' };
const riskText: Record<string, string> = { critical: '严重', high: '高风险', medium: '中风险', low: '低风险', none: '无风险' };
const actionText: Record<string, string> = { block: '拦截', fixed_reply: '固定回复', refuse_guide: '拒绝并引导', emergency_guide: '紧急引导', rewrite_guide: '改写并引导', model_fallback: '模型回答' };
const intentText: Record<string, string> = { I1: '诊断请求', I2: '症状判断', I3: '用药推荐', I4: '剂量咨询', I5: '病情严重程度', I6: '停药/换药', I7: '处方请求', I8: '偏方/替代治疗', I11: '自伤或紧急情况', I12: '普通问题' };

const AiSafety: React.FC = () => {
  const [text, setText] = useState('');
  const [result, setResult] = useState<any>(null);
  const [events, setEvents] = useState<any[]>([]);
  const [expanded, setExpanded] = useState<number | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const pageSize = 10;
  const reload = async (targetPage = page) => {
    try { const data = await getAiSafetyEvents({ page: targetPage, page_size: pageSize }); setEvents(data.items); setTotal(data.total); setPage(data.page); } catch { /* 页面保持现状 */ }
  };
  const check = async () => { try { setResult(await checkAiSafety(text)); } catch { setResult({ error: '安全检测失败，请稍后重试' }); } };
  useEffect(() => { void reload(1); }, []);
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  return <div className="space-y-4">
    <section className="rounded-xl bg-white px-6 py-4 shadow">
      <h2 className="mb-3 text-lg font-semibold">规则检测</h2>
      <textarea rows={3} className="w-full rounded border p-3" value={text} onChange={(event) => setText(event.target.value)} placeholder="输入问题进行安全判定" />
      <div className="mt-3 flex items-center gap-3"><button className="rounded bg-indigo-600 px-4 py-2 text-white" onClick={() => void check()}>检测</button>{result && <span className="text-sm text-slate-500">已完成检测</span>}</div>
      {result && <pre className="mt-3 max-h-32 overflow-auto rounded bg-slate-50 p-3 text-sm">{JSON.stringify(result, null, 2)}</pre>}
    </section>
    <section className="rounded-xl bg-white p-6 shadow">
      <div className="mb-4 flex items-center justify-between"><div><h2 className="text-lg font-semibold">违规记录</h2><p className="mt-1 text-sm text-slate-500">规则由内置基础规则和数据库可配置规则共同组成。</p></div><button className="rounded border px-3 py-1 text-sm" onClick={() => void reload(page)}>刷新</button></div>
      <div className="overflow-hidden rounded-lg border"><div className="max-h-[calc(100vh-390px)] min-h-[240px] overflow-auto"><table className="w-full min-w-[900px] text-left text-sm">
        <thead className="sticky top-0 z-10 bg-slate-50"><tr className="border-b"><th className="p-3">时间</th><th className="p-3">阶段</th><th className="p-3">风险</th><th className="p-3">处理动作</th><th className="p-3">违规类型</th><th className="p-3">操作</th></tr></thead>
        <tbody>{events.map((item) => <React.Fragment key={item.id}><tr className="border-b"><td className="p-3">{item.created_at ? new Date(item.created_at).toLocaleString('zh-CN') : '-'}</td><td className="p-3">{phaseText[item.phase] || item.phase}</td><td className="p-3">{riskText[item.risk_level] || item.risk_level}</td><td className="p-3">{actionText[item.action] || item.action}</td><td className="p-3">{intentText[item.intent_code] || item.intent_code}</td><td className="p-3"><button className="text-indigo-600" onClick={() => setExpanded(expanded === item.id ? null : item.id)}>{expanded === item.id ? '收起' : '查看详情'}</button></td></tr>
          {expanded === item.id && <tr className="bg-slate-50"><td colSpan={6} className="p-4"><div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm"><div className="mb-4 flex flex-wrap gap-2"><span className="rounded-full bg-red-50 px-3 py-1 text-xs text-red-700">{riskText[item.risk_level] || item.risk_level}</span><span className="rounded-full bg-indigo-50 px-3 py-1 text-xs text-indigo-700">{phaseText[item.phase] || item.phase}</span><span className="rounded-full bg-amber-50 px-3 py-1 text-xs text-amber-700">{actionText[item.action] || item.action}</span></div><div className="grid gap-4 md:grid-cols-4"><div><div className="text-xs text-slate-500">违规原因</div><div className="mt-1 font-medium">{item.violation_reason || '命中安全规则'}</div></div><div><div className="text-xs text-slate-500">规则类别</div><div className="mt-1 font-medium">{item.category || '-'}</div></div><div><div className="text-xs text-slate-500">审核状态</div><div className="mt-1 font-medium">{item.review_status === 'pending' ? '待审核' : item.review_status === 'reviewed' ? '已审核' : '无需审核'}</div></div><div><div className="text-xs text-slate-500">终端 / 场景</div><div className="mt-1 font-medium">{item.terminal || '-'} / {item.scene || '-'}</div></div></div><div className="mt-5 grid gap-4 lg:grid-cols-2"><div><div className="mb-2 text-sm font-semibold">违规提问 / 内容</div><div className="min-h-20 rounded-lg border-l-4 border-red-400 bg-red-50/60 p-3 text-sm leading-6">{item.excerpt || '-'}</div></div><div><div className="mb-2 text-sm font-semibold">AI 回复</div><div className="min-h-20 rounded-lg border-l-4 border-emerald-400 bg-emerald-50/60 p-3 text-sm leading-6">{item.reply_text || '-'}</div></div></div></div></td></tr>}</React.Fragment>)}</tbody>
      </table></div></div>
      <div className="mt-4 flex items-center justify-between text-sm text-slate-600"><span>共 {total} 条，第 {page} / {totalPages} 页</span><div className="flex gap-2"><button disabled={page <= 1} className="rounded border px-3 py-1 disabled:cursor-not-allowed disabled:opacity-40" onClick={() => void reload(page - 1)}>上一页</button><button disabled={page >= totalPages} className="rounded border px-3 py-1 disabled:cursor-not-allowed disabled:opacity-40" onClick={() => void reload(page + 1)}>下一页</button></div></div>
    </section>
  </div>;
};
export default AiSafety;
