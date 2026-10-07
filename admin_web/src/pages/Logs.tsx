import React, { useEffect, useMemo, useState } from 'react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { ChevronLeft, ChevronRight, Eye, FileClock, RotateCcw, Search } from 'lucide-react';
import { getOperationLogs, OperationLog } from '@/api';

type LogFilters = {
  start_date: string;
  end_date: string;
  module: string;
  action: string;
  result: string;
  terminal: string;
  keyword: string;
};

const DEFAULT_FILTERS: LogFilters = {
  start_date: '',
  end_date: '',
  module: '',
  action: '',
  result: '',
  terminal: '',
  keyword: '',
};

const MODULE_LABELS: Record<string, string> = {
  auth: '登录登出',
  profile: '健康档案',
  question: '高频问题',
  agreement: '协议隐私',
  setting: '系统配置',
  admin: '后台管理',
};

const ACTION_LABELS: Record<string, string> = {
  login_password: '密码登录',
  login_sms: '短信登录',
  login_carrier: '一键登录',
  logout: '退出登录',
  profile_create: '新增档案',
  profile_update: '修改档案',
  profile_delete: '删除档案',
  update_user_status: '用户状态',
  create_question: '新增问题',
  update_question: '修改问题',
  publish_question: '发布问题',
  delete_question: '删除问题',
  update_agreement: '更新协议',
  update_setting: '更新配置',
  update_password: '修改密码',
};

const RESULT_LABELS: Record<string, string> = {
  success: '成功',
  failure: '失败',
};

const TERMINAL_LABELS: Record<string, string> = {
  app: 'App',
  pc: 'PC',
  admin_web: '后台管理',
};

const MODULE_OPTIONS = [
  ['', '全部'],
  ['auth', '登录登出'],
  ['profile', '健康档案'],
  ['question', '高频问题'],
  ['agreement', '协议隐私'],
  ['setting', '系统配置'],
  ['admin', '后台管理'],
] as const;

const ACTION_OPTIONS = [
  ['', '全部'],
  ['login_password', '密码登录'],
  ['login_sms', '短信登录'],
  ['login_carrier', '一键登录'],
  ['logout', '退出登录'],
  ['profile_create', '新增档案'],
  ['profile_update', '修改档案'],
  ['profile_delete', '删除档案'],
  ['update_user_status', '用户状态'],
  ['create_question', '新增问题'],
  ['update_question', '修改问题'],
  ['publish_question', '发布问题'],
  ['delete_question', '删除问题'],
  ['update_agreement', '更新协议'],
  ['update_setting', '更新配置'],
  ['update_password', '修改密码'],
] as const;

const RESULT_OPTIONS = [
  ['', '全部'],
  ['success', '成功'],
  ['failure', '失败'],
] as const;

const TERMINAL_OPTIONS = [
  ['', '全部'],
  ['app', 'App'],
  ['pc', 'PC'],
  ['admin_web', '后台管理'],
] as const;

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100];

const formatDateTime = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '-';
  }
  return date.toLocaleString('zh-CN');
};

const formatRangeValue = (value: string, kind: 'start' | 'end') => {
  if (!value) {
    return undefined;
  }
  return `${value}T${kind === 'start' ? '00:00:00' : '23:59:59'}`;
};

const getModuleLabel = (value?: string | null) => (value ? MODULE_LABELS[value] || value : '-');
const getActionLabel = (value?: string | null) => (value ? ACTION_LABELS[value] || value : '-');
const getResultLabel = (value?: string | null) => (value ? RESULT_LABELS[value] || value : '-');
const getTerminalLabel = (value?: string | null) => (value ? TERMINAL_LABELS[value] || value : '-');

const getTableDetails = (log: OperationLog) => {
  if (log.module === 'profile' && log.action === 'profile_create') {
    return '新增健康档案';
  }
  if (log.module === 'profile' && log.action === 'profile_update') {
    return '修改健康档案';
  }
  if (log.module === 'consultation') {
    const consultationActions: Record<string, string> = {
      consultation_record_create: '新增问诊记录',
      consultation_record_update: '修改问诊记录',
      consultation_record_delete: '删除问诊记录',
    };
    return consultationActions[log.action] || log.details || '-';
  }
  return log.details || '-';
};

const getBadgeClass = (kind: 'success' | 'failure' | 'neutral') => {
  switch (kind) {
    case 'success':
      return 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border-0';
    case 'failure':
      return 'bg-red-50 text-red-700 hover:bg-red-100 border-0';
    default:
      return 'bg-slate-100 text-slate-700 hover:bg-slate-200 border-0';
  }
};

const Logs = () => {
  const [draftFilters, setDraftFilters] = useState<LogFilters>(DEFAULT_FILTERS);
  const [queryFilters, setQueryFilters] = useState<LogFilters>(DEFAULT_FILTERS);
  const [logs, setLogs] = useState<OperationLog[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [loading, setLoading] = useState(true);
  const [selectedLog, setSelectedLog] = useState<OperationLog | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);

  const totalPages = useMemo(() => Math.max(1, Math.ceil(total / pageSize)), [pageSize, total]);

  const fetchLogs = async () => {
    setLoading(true);
    try {
      const data = await getOperationLogs({
        page,
        page_size: pageSize,
        start_time: formatRangeValue(queryFilters.start_date, 'start'),
        end_time: formatRangeValue(queryFilters.end_date, 'end'),
        module: queryFilters.module || undefined,
        action: queryFilters.action || undefined,
        result: queryFilters.result || undefined,
        terminal: queryFilters.terminal || undefined,
        keyword: queryFilters.keyword || undefined,
      });
      setLogs(data.items);
      setTotal(data.total);
    } catch (error) {
      console.error('Failed to fetch logs:', error);
      setLogs([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchLogs();
  }, [page, pageSize, queryFilters]);

  const handleSearch = () => {
    setPage(1);
    setQueryFilters({ ...draftFilters });
  };

  const handleReset = () => {
    setDraftFilters(DEFAULT_FILTERS);
    setQueryFilters(DEFAULT_FILTERS);
    setPage(1);
  };

  const openDetail = (log: OperationLog) => {
    setSelectedLog(log);
    setIsDetailOpen(true);
  };

  return (
    <div className="flex h-full min-h-0 flex-col gap-4 overflow-hidden">
      <div className="flex shrink-0 items-center justify-between rounded-xl border border-slate-100 bg-white p-4 shadow-sm">
        <div>
          <h2 className="flex items-center text-xl font-bold text-slate-800">
            <FileClock className="mr-2 text-[#6C63FF]" size={22} />
            日志管理
          </h2>
          <p className="mt-1 text-xs text-slate-500">
            查询登录、健康档案和后台维护日志，支持分页和条件筛选。
          </p>
        </div>
      </div>

      <div className="shrink-0 overflow-x-auto rounded-xl border border-slate-100 bg-white p-3 shadow-sm">
        <div className="flex min-w-max items-end gap-2">
          <div className="w-[138px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">开始时间</label>
            <Input
              type="date"
              className="h-9 px-2 text-xs"
              value={draftFilters.start_date}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, start_date: e.target.value }))}
            />
          </div>
          <div className="w-[138px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">结束时间</label>
            <Input
              type="date"
              className="h-9 px-2 text-xs"
              value={draftFilters.end_date}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, end_date: e.target.value }))}
            />
          </div>
          <div className="w-[120px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">日志模块</label>
            <select
              value={draftFilters.module}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, module: e.target.value }))}
              className="flex h-9 w-full rounded-md border border-slate-200 bg-white px-2 text-xs outline-none ring-offset-white transition-colors focus-visible:border-slate-400 focus-visible:ring-2 focus-visible:ring-slate-200"
            >
              {MODULE_OPTIONS.map(([value, label]) => (
                <option key={value || 'all-module'} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="w-[120px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">操作类型</label>
            <select
              value={draftFilters.action}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, action: e.target.value }))}
              className="flex h-9 w-full rounded-md border border-slate-200 bg-white px-2 text-xs outline-none ring-offset-white transition-colors focus-visible:border-slate-400 focus-visible:ring-2 focus-visible:ring-slate-200"
            >
              {ACTION_OPTIONS.map(([value, label]) => (
                <option key={value || 'all-action'} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="w-[90px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">结果</label>
            <select
              value={draftFilters.result}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, result: e.target.value }))}
              className="flex h-9 w-full rounded-md border border-slate-200 bg-white px-2 text-xs outline-none ring-offset-white transition-colors focus-visible:border-slate-400 focus-visible:ring-2 focus-visible:ring-slate-200"
            >
              {RESULT_OPTIONS.map(([value, label]) => (
                <option key={value || 'all-result'} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="w-[110px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">终端</label>
            <select
              value={draftFilters.terminal}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, terminal: e.target.value }))}
              className="flex h-9 w-full rounded-md border border-slate-200 bg-white px-2 text-xs outline-none ring-offset-white transition-colors focus-visible:border-slate-400 focus-visible:ring-2 focus-visible:ring-slate-200"
            >
              {TERMINAL_OPTIONS.map(([value, label]) => (
                <option key={value || 'all-terminal'} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>
          <div className="w-[220px] shrink-0 space-y-1">
            <label className="text-xs font-medium text-slate-700">关键字</label>
            <Input
              className="h-9 px-2 text-xs"
              value={draftFilters.keyword}
              onChange={(e) => setDraftFilters((prev) => ({ ...prev, keyword: e.target.value }))}
              placeholder="搜索操作人、对象、请求ID、详情..."
            />
          </div>
          <div className="flex shrink-0 items-end gap-2">
            <Button onClick={handleSearch} className="h-9 px-3 text-xs bg-[#6C63FF] text-white hover:bg-[#5b54e6]">
              <Search className="mr-1.5 h-3.5 w-3.5" />
              查询
            </Button>
            <Button variant="outline" onClick={handleReset} className="h-9 px-3 text-xs">
              <RotateCcw className="mr-1.5 h-3.5 w-3.5" />
              重置
            </Button>
          </div>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-auto rounded-xl border border-slate-100 bg-white shadow-sm">
        <Table containerClassName="overflow-visible" className="min-w-[1080px]">
          <TableHeader className="sticky top-0 z-10 bg-slate-50/95 shadow-[0_1px_0_0_rgb(226_232_240)]">
            <TableRow>
              <TableHead className="w-[160px]">时间</TableHead>
              <TableHead>日志</TableHead>
              <TableHead className="w-[120px]">终端</TableHead>
              <TableHead className="w-[100px]">结果</TableHead>
              <TableHead className="w-[200px]">操作人</TableHead>
              <TableHead>详情</TableHead>
              <TableHead className="w-[100px] text-right">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  加载日志中...
                </TableCell>
              </TableRow>
            ) : logs.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  暂无日志
                </TableCell>
              </TableRow>
            ) : (
              logs.map((log) => (
                <TableRow key={log.id} className="align-top">
                  <TableCell className="text-sm text-slate-600">{formatDateTime(log.created_at)}</TableCell>
                  <TableCell>
                    <div className="space-y-2">
                      <Badge className={getBadgeClass('neutral')}>{getModuleLabel(log.module)}</Badge>
                      <div className="font-medium text-slate-900">{getActionLabel(log.action)}</div>
                      <div className="text-xs text-slate-400">
                        {log.target_type ? `${log.target_type}${log.target_id ? ` #${log.target_id}` : ''}` : '-'}
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge className={getBadgeClass('neutral')}>{getTerminalLabel(log.terminal)}</Badge>
                  </TableCell>
                  <TableCell>
                    <Badge className={getBadgeClass(log.result === 'failure' ? 'failure' : 'success')}>
                      {getResultLabel(log.result)}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="space-y-1">
                      <div className="font-medium text-slate-900">{log.actor_name || '-'}</div>
                      <div className="text-xs text-slate-400">{log.actor_phone_masked || '-'}</div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <div className="max-w-[420px] truncate text-sm text-slate-700" title={getTableDetails(log)}>
                      {getTableDetails(log)}
                    </div>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button variant="outline" size="sm" onClick={() => openDetail(log)} className="h-8">
                      <Eye className="mr-1 h-3.5 w-3.5" />
                      详情
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex shrink-0 flex-col gap-3 rounded-xl border border-slate-100 bg-white px-5 py-3 shadow-sm md:flex-row md:items-center md:justify-between">
        <div className="text-sm text-slate-500">
          共 {total} 条，当前第 {page} / {totalPages} 页
        </div>
        <div className="flex items-center gap-3">
          <select
            value={pageSize}
            onChange={(e) => {
              setPage(1);
              setPageSize(Number(e.target.value));
            }}
            className="flex h-9 rounded-md border border-slate-200 bg-white px-3 text-sm outline-none"
          >
            {PAGE_SIZE_OPTIONS.map((size) => (
              <option key={size} value={size}>
                {size} 条/页
              </option>
            ))}
          </select>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((prev) => Math.max(1, prev - 1))}
              disabled={page <= 1}
              className="h-9"
            >
              <ChevronLeft className="mr-1 h-4 w-4" />
              上一页
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
              disabled={page >= totalPages}
              className="h-9"
            >
              下一页
              <ChevronRight className="ml-1 h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>

      <Dialog open={isDetailOpen} onOpenChange={setIsDetailOpen}>
        <DialogContent className="max-w-3xl">
          <DialogHeader>
            <DialogTitle>日志详情</DialogTitle>
          </DialogHeader>
          {selectedLog && (
            <div className="grid gap-4">
              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                <div>
                  <div className="text-xs text-slate-500">日志ID</div>
                  <div className="text-sm font-medium text-slate-900">{selectedLog.id}</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">时间</div>
                  <div className="text-sm font-medium text-slate-900">{formatDateTime(selectedLog.created_at)}</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">模块 / 操作</div>
                  <div className="text-sm font-medium text-slate-900">
                    {getModuleLabel(selectedLog.module)} / {getActionLabel(selectedLog.action)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">终端 / 结果</div>
                  <div className="text-sm font-medium text-slate-900">
                    {getTerminalLabel(selectedLog.terminal)} / {getResultLabel(selectedLog.result)}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">操作人</div>
                  <div className="text-sm font-medium text-slate-900">{selectedLog.actor_name || '-'}</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">手机号</div>
                  <div className="text-sm font-medium text-slate-900">{selectedLog.actor_phone_masked || '-'}</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">对象</div>
                  <div className="text-sm font-medium text-slate-900">
                    {selectedLog.target_type ? `${selectedLog.target_type}${selectedLog.target_id ? ` #${selectedLog.target_id}` : ''}` : '-'}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">IP / 请求ID</div>
                  <div className="text-sm font-medium text-slate-900">
                    {selectedLog.ip_address || '-'} / {selectedLog.request_id || '-'}
                  </div>
                </div>
              </div>

              <div>
                <div className="mb-2 text-xs text-slate-500">详情</div>
                <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-800">
                  {selectedLog.details || '-'}
                </div>
              </div>

              <div>
                <div className="mb-2 text-xs text-slate-500">User-Agent</div>
                <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-800">
                  {selectedLog.user_agent || '-'}
                </div>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default Logs;
