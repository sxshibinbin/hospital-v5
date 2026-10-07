import React, { useEffect, useState } from 'react';
import { Search, MessageSquareText } from 'lucide-react';
import { getAiFeedback, AiFeedback } from '@/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';

const Feedback = () => {
  const [items, setItems] = useState<AiFeedback[]>([]);
  const [keyword, setKeyword] = useState('');
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<AiFeedback | null>(null);
  const load = async () => { setLoading(true); try { setItems((await getAiFeedback({ keyword })).items); } finally { setLoading(false); } };
  useEffect(() => { void load(); }, []);
  return <div className="space-y-6">
    <div className="flex items-center justify-between"><div><h2 className="text-2xl font-bold text-slate-900">AI 回复反馈</h2><p className="mt-1 text-sm text-slate-500">查看用户对 AI 问答的意见和建议</p></div></div>
    <div className="flex max-w-xl gap-2"><Input value={keyword} onChange={e => setKeyword(e.target.value)} onKeyDown={e => e.key === 'Enter' && void load()} placeholder="检索反馈人、问题、AI回复或反馈内容" /><Button onClick={() => void load()}><Search className="mr-2 h-4 w-4" />检索</Button></div>
    <div className="rounded-xl border bg-white"><Table><TableHeader><TableRow><TableHead>反馈人</TableHead><TableHead>时间</TableHead><TableHead>问题</TableHead><TableHead>反馈内容</TableHead><TableHead>操作</TableHead></TableRow></TableHeader><TableBody>{loading ? <TableRow><TableCell colSpan={5} className="text-center">加载中...</TableCell></TableRow> : items.map(item => <TableRow key={item.id}><TableCell>{item.feedback_user || '-'}</TableCell><TableCell>{new Date(item.created_at).toLocaleString()}</TableCell><TableCell className="max-w-xs truncate">{item.question}</TableCell><TableCell className="max-w-xs truncate">{item.content}</TableCell><TableCell><Button variant="ghost" size="sm" onClick={() => setSelected(item)}><MessageSquareText className="mr-1 h-4 w-4" />查看</Button></TableCell></TableRow>)}</TableBody></Table></div>
    <Dialog open={Boolean(selected)} onOpenChange={open => !open && setSelected(null)}><DialogContent className="max-w-3xl"><DialogHeader><DialogTitle>反馈详情</DialogTitle></DialogHeader>{selected && <div className="space-y-4 text-sm"><div><b>反馈人：</b>{selected.feedback_user}<span className="ml-6"><b>时间：</b>{new Date(selected.created_at).toLocaleString()}</span></div><div><b>问题</b><p className="mt-1 whitespace-pre-wrap rounded bg-slate-50 p-3">{selected.question}</p></div><div><b>AI 回复</b><p className="mt-1 max-h-64 overflow-auto whitespace-pre-wrap rounded bg-slate-50 p-3">{selected.ai_response}</p></div><div><b>反馈内容</b><p className="mt-1 whitespace-pre-wrap rounded bg-indigo-50 p-3">{selected.content}</p></div></div>}</DialogContent></Dialog>
  </div>;
};
export default Feedback;
