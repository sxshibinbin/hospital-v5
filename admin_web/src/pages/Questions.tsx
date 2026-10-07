import React, { useEffect, useState } from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Plus, Pencil, Trash2, Globe, ArrowUp, ArrowDown } from 'lucide-react';
import { getQuestions, createQuestion, updateQuestion, deleteQuestion, publishQuestion, Question, QuestionCreate } from '@/api';

const Questions = () => {
  const [questions, setQuestions] = useState<Question[]>([]);
  const [loading, setLoading] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);

  const [formData, setFormData] = useState<QuestionCreate>({
    question: '',
    answer_template: '',
    category: '常规问题',
    is_top: false,
    status: 'draft',
    sort_weight: 0,
  });

  const fetchQuestions = async () => {
    setLoading(true);
    try {
      const data = await getQuestions();
      setQuestions(data);
    } catch (error) {
      console.error('Failed to fetch questions:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchQuestions();
  }, []);

  const handleOpenDialog = (question?: Question) => {
    if (question) {
      setEditingId(question.id);
      setFormData({
        question: question.question,
        answer_template: question.answer_template,
        category: question.category || '',
        is_top: question.is_top,
        status: question.status,
        sort_weight: question.sort_weight,
      });
    } else {
      setEditingId(null);
      setFormData({
        question: '',
        answer_template: '',
        category: '常规问题',
        is_top: false,
        status: 'draft',
        sort_weight: 0,
      });
    }
    setIsDialogOpen(true);
  };

  const handleSave = async () => {
    try {
      if (editingId) {
        await updateQuestion(editingId, formData);
      } else {
        await createQuestion(formData);
      }
      setIsDialogOpen(false);
      fetchQuestions();
    } catch (error) {
      console.error('Failed to save question:', error);
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('确定要删除这个问题吗？')) {
      try {
        await deleteQuestion(id);
        fetchQuestions();
      } catch (error) {
        console.error('Failed to delete question:', error);
      }
    }
  };

  const handlePublish = async (id: number) => {
    try {
      await publishQuestion(id);
      fetchQuestions();
    } catch (error) {
      console.error('Failed to publish question:', error);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'published':
        return <Badge variant="published">已发布</Badge>;
      case 'draft':
        return <Badge variant="draft">待审核(草稿)</Badge>;
      case 'disabled':
        return <Badge variant="disabled">已禁用</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center bg-white p-6 rounded-xl shadow-sm border border-slate-100">
        <div>
          <h2 className="text-2xl font-bold text-slate-800">高频问题列表</h2>
          <p className="text-slate-500 mt-1 text-sm">管理 App 端首页展示的猜你想问列表，支持配置动态变量如 [姓名]、[科室]。</p>
        </div>
        <Button onClick={() => handleOpenDialog()} className="shadow-md shadow-[#6C63FF]/20">
          <Plus className="w-4 h-4 mr-2" />
          新建问题
        </Button>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
        <Table>
          <TableHeader className="bg-slate-50/80">
            <TableRow>
              <TableHead className="w-[80px]">ID</TableHead>
              <TableHead className="w-[200px]">分类</TableHead>
              <TableHead className="w-[300px]">问题文本</TableHead>
              <TableHead>状态</TableHead>
              <TableHead>权重</TableHead>
              <TableHead>点击量</TableHead>
              <TableHead className="text-right">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  <div className="flex items-center justify-center space-x-2 animate-pulse">
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full"></div>
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full" style={{ animationDelay: '200ms' }}></div>
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full" style={{ animationDelay: '400ms' }}></div>
                    <span>数据加载中...</span>
                  </div>
                </TableCell>
              </TableRow>
            ) : questions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  暂无数据，请点击右上角新建。
                </TableCell>
              </TableRow>
            ) : (
              questions.map((q) => (
                <TableRow key={q.id} className="group">
                  <TableCell className="font-medium text-slate-600">#{q.id}</TableCell>
                  <TableCell>
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-800">
                      {q.category || '未分类'}
                    </span>
                  </TableCell>
                  <TableCell>
                    <div className="font-medium text-slate-900">{q.question}</div>
                    <div className="text-xs text-slate-400 mt-1 truncate max-w-[280px]" title={q.answer_template}>
                      {q.answer_template}
                    </div>
                  </TableCell>
                  <TableCell>{getStatusBadge(q.status)}</TableCell>
                  <TableCell>
                    <div className="flex items-center space-x-1">
                      <span className="text-slate-700 font-mono bg-slate-50 px-2 py-1 rounded border border-slate-200">{q.sort_weight}</span>
                      {q.is_top && <Badge className="bg-orange-100 text-orange-700 hover:bg-orange-100 border-0 ml-2">置顶</Badge>}
                    </div>
                  </TableCell>
                  <TableCell>
                    <span className="text-slate-500">{q.click_count} 次</span>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex items-center justify-end space-x-2 opacity-80 group-hover:opacity-100 transition-opacity">
                      {q.status !== 'published' && (
                        <Button variant="outline" size="sm" onClick={() => handlePublish(q.id)} className="h-8 border-green-200 text-green-700 hover:bg-green-50">
                          <Globe className="w-3.5 h-3.5 mr-1" />
                          发布
                        </Button>
                      )}
                      <Button variant="outline" size="sm" onClick={() => handleOpenDialog(q)} className="h-8">
                        <Pencil className="w-3.5 h-3.5 mr-1" />
                        编辑
                      </Button>
                      <Button variant="destructive" size="sm" onClick={() => handleDelete(q.id)} className="h-8 bg-red-50 text-red-600 hover:bg-red-100 hover:text-red-700 border-0 shadow-none">
                        <Trash2 className="w-3.5 h-3.5" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="sm:max-w-[600px]">
          <DialogHeader>
            <DialogTitle>{editingId ? '编辑高频问题' : '新建高频问题'}</DialogTitle>
            <DialogDescription>
              填写用户经常提问的内容及其标准答案模板。答案中可使用变量，如 `[姓名]`、`[年龄]`、`[性别]`、`[科室]`。
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-6 py-4">
            <div className="grid gap-2">
              <label htmlFor="question" className="text-sm font-medium text-slate-700">问题文本 <span className="text-red-500">*</span></label>
              <Input
                id="question"
                placeholder="例如：如何调理脾虚？"
                value={formData.question}
                onChange={(e) => setFormData({ ...formData, question: e.target.value })}
              />
            </div>
            
            <div className="grid gap-2">
              <label htmlFor="answer" className="text-sm font-medium text-slate-700">标准答案模板 <span className="text-red-500">*</span></label>
              <Textarea
                id="answer"
                placeholder="支持 Markdown 格式。可插入变量，例如：[姓名] 您好，建议您前往 [科室] 就诊。"
                className="min-h-[160px] resize-none"
                value={formData.answer_template}
                onChange={(e) => setFormData({ ...formData, answer_template: e.target.value })}
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-2">
                <label htmlFor="category" className="text-sm font-medium text-slate-700">问题分类</label>
                <Input
                  id="category"
                  placeholder="例如：中医养生"
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                />
              </div>
              <div className="grid gap-2">
                <label htmlFor="sort_weight" className="text-sm font-medium text-slate-700">排序权重</label>
                <Input
                  id="sort_weight"
                  type="number"
                  placeholder="数字越大越靠前"
                  value={formData.sort_weight}
                  onChange={(e) => setFormData({ ...formData, sort_weight: parseInt(e.target.value) || 0 })}
                />
              </div>
            </div>

            <div className="flex items-center space-x-6 pt-2">
              <label className="flex items-center space-x-2 cursor-pointer group">
                <input
                  type="checkbox"
                  className="rounded border-slate-300 text-[#6C63FF] focus:ring-[#6C63FF] w-4 h-4 cursor-pointer"
                  checked={formData.is_top}
                  onChange={(e) => setFormData({ ...formData, is_top: e.target.checked })}
                />
                <span className="text-sm font-medium text-slate-700 group-hover:text-slate-900 transition-colors">强制置顶展示</span>
              </label>

              <label className="flex items-center space-x-2 cursor-pointer group">
                <input
                  type="checkbox"
                  className="rounded border-slate-300 text-[#6C63FF] focus:ring-[#6C63FF] w-4 h-4 cursor-pointer"
                  checked={formData.status === 'disabled'}
                  onChange={(e) => setFormData({ ...formData, status: e.target.checked ? 'disabled' : (editingId ? formData.status : 'draft') })}
                />
                <span className="text-sm font-medium text-slate-700 group-hover:text-slate-900 transition-colors">禁用此问题</span>
              </label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDialogOpen(false)}>取消</Button>
            <Button onClick={handleSave} className="shadow-md shadow-[#6C63FF]/20">保存</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default Questions;
