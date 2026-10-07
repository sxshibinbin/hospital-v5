import { useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { AiIntentRule, AiIntentRulePayload, createAiIntentRule, deleteAiIntentRule, getAiIntentRules, updateAiIntentRule } from '@/api';

const initialForm: AiIntentRulePayload = { scene_name: '', intent_code: '', risk_level: 'medium', triggers: '', match_mode: 'keyword', reply_template: '', action: 'fixed_reply', scope: 'all', priority: 100, status: 'enabled', remark: '' };

export default function IntentRules() {
  const [items, setItems] = useState<AiIntentRule[]>([]);
  const [keyword, setKeyword] = useState('');
  const [page, setPage] = useState(1);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<AiIntentRulePayload>(initialForm);
  const [saving, setSaving] = useState(false);
  const size = 10;
  const load = async () => setItems((await getAiIntentRules()).items);
  useEffect(() => { void load(); }, []);
  const filtered = useMemo(() => items.filter(x => `${x.intent_code} ${x.scene_name} ${x.triggers} ${x.reply_template || ''}`.toLowerCase().includes(keyword.toLowerCase())), [items, keyword]);
  const count = Math.max(1, Math.ceil(filtered.length / size));
  const rows = filtered.slice((page - 1) * size, page * size);
  useEffect(() => setPage(1), [keyword]);
  const setField = <K extends keyof AiIntentRulePayload>(key: K, value: AiIntentRulePayload[K]) => setForm(current => ({ ...current, [key]: value }));
  const openNew = () => { setEditingId(null); setForm(initialForm); setDialogOpen(true); };
  const openEdit = (item: AiIntentRule) => { const { id, hit_count, created_at, updated_at, ...payload } = item; void id; void hit_count; void created_at; void updated_at; setEditingId(item.id); setForm(payload); setDialogOpen(true); };
  const save = async () => {
    if (!form.scene_name.trim() || !form.intent_code.trim() || !form.triggers.trim() || !form.action.trim()) return;
    setSaving(true);
    try { if (editingId === null) await createAiIntentRule(form); else await updateAiIntentRule(editingId, form); setDialogOpen(false); await load(); }
    finally { setSaving(false); }
  };
  const remove = async (item: AiIntentRule) => { if (window.confirm(`确定删除“${item.scene_name}”吗？删除后将立即不再生效。`)) { await deleteAiIntentRule(item.id); await load(); } };
  return <div className="space-y-6">
    <div className="flex items-center justify-between rounded-xl border bg-white p-6 shadow-sm"><div><h2 className="text-2xl font-bold">意图规划 / 标准回答</h2><p className="mt-1 text-sm text-slate-500">维护意图识别规则及命中后的标准回答。</p></div><Button onClick={openNew}><Plus className="mr-2 h-4 w-4" />新增规则</Button></div>
    <div className="rounded-xl border bg-white p-4 shadow-sm"><Input className="max-w-sm" placeholder="搜索意图、触发词或标准回答" value={keyword} onChange={e => setKeyword(e.target.value)} /></div>
    <div className="overflow-hidden rounded-xl border bg-white shadow-sm"><div className="max-h-[560px] overflow-auto"><table className="min-w-[1280px] w-full text-sm"><thead className="bg-slate-50 text-left"><tr>{['场景/意图','风险','触发规则','标准回答','动作','范围','优先级','状态','命中','操作'].map(x => <th className="px-4 py-3" key={x}>{x}</th>)}</tr></thead><tbody>{rows.map(x => <tr className="border-t" key={x.id}><td className="px-4 py-3">{x.scene_name} / {x.intent_code}</td><td className="px-4 py-3"><Badge>{x.risk_level}</Badge></td><td className="max-w-[220px] truncate px-4 py-3">{x.triggers}</td><td className="max-w-[320px] px-4 py-3">{x.reply_template || '未配置'}</td><td className="px-4 py-3">{x.action}</td><td className="px-4 py-3">{x.scope}</td><td className="px-4 py-3">{x.priority}</td><td className="px-4 py-3">{x.status}</td><td className="px-4 py-3">{x.hit_count}</td><td className="px-4 py-3"><div className="flex gap-2"><Button size="sm" variant="outline" onClick={() => openEdit(x)}><Pencil className="mr-1 h-3.5 w-3.5" />编辑</Button><Button size="sm" variant="destructive" onClick={() => void remove(x)}><Trash2 className="h-3.5 w-3.5" /></Button></div></td></tr>)}</tbody></table></div><div className="flex items-center justify-between border-t px-4 py-3 text-sm"><span>共 {filtered.length} 条</span><div className="flex items-center gap-2"><Button size="sm" variant="outline" disabled={page <= 1} onClick={() => setPage(page - 1)}>上一页</Button><span>{page} / {count}</span><Button size="sm" variant="outline" disabled={page >= count} onClick={() => setPage(page + 1)}>下一页</Button></div></div></div>
    <Dialog open={dialogOpen} onOpenChange={setDialogOpen}><DialogContent className="max-h-[calc(100vh-2rem)] overflow-y-auto sm:max-w-4xl"><DialogHeader><DialogTitle>{editingId === null ? '新增意图规则' : '编辑意图规则'}</DialogTitle><DialogDescription>带 * 的字段为必填项。启用后的修改会立即应用到安全规则。</DialogDescription></DialogHeader><div className="grid gap-4 py-2"><div className="grid grid-cols-2 gap-4"><Field label="场景名称 *"><Input value={form.scene_name} onChange={e => setField('scene_name', e.target.value)} /></Field><Field label="意图编码 *"><Input value={form.intent_code} onChange={e => setField('intent_code', e.target.value)} /></Field></div><Field label="触发规则 *"><Textarea className="min-h-20" placeholder="多个关键词请用英文逗号分隔" value={form.triggers} onChange={e => setField('triggers', e.target.value)} /></Field><Field label="标准回答"><Textarea className="min-h-24" value={form.reply_template || ''} onChange={e => setField('reply_template', e.target.value)} /></Field><div className="grid grid-cols-3 gap-4"><SelectField label="风险等级" value={form.risk_level} onChange={value => setField('risk_level', value as AiIntentRulePayload['risk_level'])} options={['low','medium','high','critical']} /><SelectField label="状态" value={form.status} onChange={value => setField('status', value as AiIntentRulePayload['status'])} options={['enabled','disabled']} /><Field label="匹配方式"><Input value={form.match_mode} onChange={e => setField('match_mode', e.target.value)} /></Field><Field label="处理动作 *"><Input value={form.action} onChange={e => setField('action', e.target.value)} /></Field><Field label="适用范围"><Input value={form.scope} onChange={e => setField('scope', e.target.value)} /></Field><Field label="优先级"><Input type="number" value={form.priority} onChange={e => setField('priority', Number(e.target.value) || 0)} /></Field></div><Field label="备注"><Input value={form.remark || ''} onChange={e => setField('remark', e.target.value)} /></Field></div><DialogFooter><Button variant="outline" onClick={() => setDialogOpen(false)}>取消</Button><Button disabled={saving || !form.scene_name.trim() || !form.intent_code.trim() || !form.triggers.trim() || !form.action.trim()} onClick={() => void save()}>{saving ? '保存中…' : '保存'}</Button></DialogFooter></DialogContent></Dialog>
  </div>;
}

function Field({ label, children }: { label: string; children: ReactNode }) { return <label className="grid gap-2 text-sm font-medium text-slate-700"><span>{label}</span>{children}</label>; }
function SelectField({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) { return <Field label={label}><select className="h-10 rounded-md border border-slate-200 bg-white px-3 text-sm" value={value} onChange={e => onChange(e.target.value)}>{options.map(option => <option key={option} value={option}>{option}</option>)}</select></Field>; }
