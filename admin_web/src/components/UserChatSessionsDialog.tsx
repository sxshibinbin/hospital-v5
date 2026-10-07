import React, { useEffect, useState, useRef } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from '@/components/ui/dialog';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Badge } from '@/components/ui/badge';
import { User, MessageSquare, Clock, Bot, ChevronRight, X } from 'lucide-react';
import { getUserChatSessions, getAdminChatSessionDetail, ChatSessionSummary, ChatSessionDetail } from '@/api';

interface UserChatSessionsDialogProps {
  userId: number;
  userName: string;
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
}

const UserChatSessionsDialog: React.FC<UserChatSessionsDialogProps> = ({
  userId,
  userName,
  isOpen,
  onOpenChange,
}) => {
  const [sessions, setSessions] = useState<ChatSessionSummary[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<number | null>(null);
  const [sessionDetail, setSessionDetail] = useState<ChatSessionDetail | null>(null);
  
  const [loadingSessions, setLoadingSessions] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen && userId) {
      fetchSessions();
      setSelectedSessionId(null);
      setSessionDetail(null);
    }
  }, [isOpen, userId]);

  useEffect(() => {
    if (selectedSessionId) {
      fetchSessionDetail(selectedSessionId);
    }
  }, [selectedSessionId]);

  useEffect(() => {
    if (sessionDetail && messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [sessionDetail]);

  const fetchSessions = async () => {
    setLoadingSessions(true);
    try {
      const data = await getUserChatSessions(userId);
      setSessions(data);
    } catch (error) {
      console.error('Failed to fetch user chat sessions:', error);
    } finally {
      setLoadingSessions(false);
    }
  };

  const fetchSessionDetail = async (sessionId: number) => {
    setLoadingDetail(true);
    try {
      const data = await getAdminChatSessionDetail(sessionId);
      setSessionDetail(data);
    } catch (error) {
      console.error('Failed to fetch session detail:', error);
    } finally {
      setLoadingDetail(false);
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[900px] w-[90vw] h-[80vh] p-0 flex flex-col gap-0 overflow-hidden bg-white border-slate-200">
        <DialogHeader className="px-6 py-4 border-b border-slate-100 flex-none flex flex-row items-center justify-between">
          <DialogTitle className="text-lg font-semibold text-slate-800 flex items-center gap-2">
            <MessageSquare className="w-5 h-5 text-[#6C63FF]" />
            {userName} 的历史咨询记录
          </DialogTitle>
          <DialogClose className="rounded-full p-1.5 hover:bg-slate-100 transition-colors">
            <X className="w-4 h-4 text-slate-500" />
          </DialogClose>
        </DialogHeader>

        <div className="flex-1 flex min-h-0 divide-x divide-slate-100">
          {/* Left Sidebar - Session List */}
          <div className="w-1/3 flex flex-col bg-slate-50/50">
            <div className="px-4 py-3 text-xs font-medium text-slate-500 uppercase tracking-wider border-b border-slate-100 bg-slate-50">
              会话列表 ({sessions.length})
            </div>
            <ScrollArea className="flex-1">
              {loadingSessions ? (
                <div className="p-8 flex justify-center">
                  <div className="w-6 h-6 border-2 border-[#6C63FF] border-t-transparent rounded-full animate-spin"></div>
                </div>
              ) : sessions.length === 0 ? (
                <div className="p-8 text-center text-slate-400 text-sm">
                  该用户暂无历史咨询
                </div>
              ) : (
                <div className="flex flex-col p-2 gap-1">
                  {sessions.map((session) => (
                    <button
                      key={session.id}
                      onClick={() => setSelectedSessionId(session.id)}
                      className={`text-left p-3 rounded-lg transition-all ${
                        selectedSessionId === session.id
                          ? 'bg-white shadow-sm ring-1 ring-slate-200 text-[#6C63FF]'
                          : 'hover:bg-slate-100 text-slate-700'
                      }`}
                    >
                      <div className="flex justify-between items-start mb-1">
                        <h4 className="font-medium text-sm truncate pr-2">
                          {session.title || '未命名咨询'}
                        </h4>
                        <Badge variant="outline" className={`text-[10px] px-1.5 py-0 border-0 ${session.mode === 'medical' ? 'bg-blue-50 text-blue-600' : 'bg-slate-100 text-slate-600'}`}>
                          {session.mode === 'medical' ? '导诊' : '常规'}
                        </Badge>
                      </div>
                      <p className="text-xs text-slate-400 truncate mb-2">
                        {session.last_message || '无内容'}
                      </p>
                      <div className="flex items-center text-[10px] text-slate-400">
                        <Clock className="w-3 h-3 mr-1" />
                        {formatDate(session.updated_at)}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </ScrollArea>
          </div>

          {/* Right Main Area - Chat Detail */}
          <div className="w-2/3 flex flex-col bg-white">
            {selectedSessionId ? (
              loadingDetail ? (
                <div className="flex-1 flex items-center justify-center">
                  <div className="flex flex-col items-center gap-3 text-slate-400">
                    <div className="w-8 h-8 border-2 border-[#6C63FF] border-t-transparent rounded-full animate-spin"></div>
                    <span className="text-sm">正在加载聊天记录...</span>
                  </div>
                </div>
              ) : sessionDetail ? (
                <>
                  <div className="px-6 py-3 border-b border-slate-50 bg-white flex justify-between items-center shadow-sm z-10">
                    <div>
                      <h3 className="font-medium text-slate-800">{sessionDetail.title}</h3>
                      <p className="text-xs text-slate-400 mt-0.5">创建于 {formatDate(sessionDetail.created_at)}</p>
                    </div>
                  </div>
                  <ScrollArea className="flex-1 p-6">
                    <div className="flex flex-col gap-6 pb-4">
                      {sessionDetail.messages.length === 0 ? (
                        <div className="text-center text-slate-400 py-10 text-sm">
                          这条会话中没有消息记录
                        </div>
                      ) : (
                        sessionDetail.messages.map((msg, idx) => (
                          <div 
                            key={msg.id || idx} 
                            className={`flex gap-3 max-w-[85%] ${msg.role === 'user' ? 'ml-auto flex-row-reverse' : ''}`}
                          >
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                              msg.role === 'user' 
                                ? 'bg-slate-100 text-slate-600' 
                                : 'bg-[#6C63FF]/10 text-[#6C63FF]'
                            }`}>
                              {msg.role === 'user' ? <User size={16} /> : <Bot size={16} />}
                            </div>
                            <div className={`flex flex-col gap-1 min-w-0 ${msg.role === 'user' ? 'items-end' : 'items-start'}`}>
                              <div className="text-xs text-slate-400">
                                {msg.role === 'user' ? '用户' : 'AI 助手'}
                              </div>
                              <div className={`px-4 py-2.5 text-sm leading-relaxed whitespace-pre-wrap break-words ${
                                msg.role === 'user'
                                  ? 'bg-[#6C63FF] text-white rounded-2xl rounded-tr-sm'
                                  : 'bg-slate-100 text-slate-800 rounded-2xl rounded-tl-sm'
                              }`}>
                                {msg.content}
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                      <div ref={messagesEndRef} />
                    </div>
                  </ScrollArea>
                </>
              ) : null
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-slate-400 gap-4">
                <div className="w-16 h-16 rounded-full bg-slate-50 flex items-center justify-center">
                  <MessageSquare className="w-8 h-8 text-slate-300" />
                </div>
                <p className="text-sm">在左侧选择一条会话以查看详细记录</p>
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default UserChatSessionsDialog;