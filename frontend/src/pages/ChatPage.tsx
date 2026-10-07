import { useMemo, useState, useEffect, useRef, useCallback } from 'react';
import { App, Avatar, Button, Collapse, ConfigProvider, Form, Input, InputNumber, Modal, Select, theme } from 'antd';
import {
  AudioMutedOutlined,
  DeleteOutlined,
  IdcardOutlined,  // MedicineBoxOutlined,
  // EditOutlined,
  LeftOutlined,
  LogoutOutlined,
  // MenuOutlined,
  MessageOutlined,
  MoreOutlined,
  PlusOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import ChatContainer from '../components/ChatContainer';
import { fetchCurrentUser, logout as logoutCurrentUser } from '../api/auth';
import type { CurrentUserResponse } from '../api/auth';
import { deleteChatSession, fetchChatSessionDetail, fetchChatSessions } from '../api/chatSessions';
import type { ChatSessionMessage, ChatSessionSummary } from '../api/chatSessions';
import { deleteConsultationRecord, fetchConsultationRecords } from '../api/consultations';
import type { SavedConsultationRecord } from '../api/consultations';
import { createHealthProfile, fetchHealthProfiles } from '../api/profiles';
import type { HealthProfile } from '../api/profiles';
import { normalizeAuthToken } from '../utils/authToken';
import { initJSBridge, notifyFlutterBack } from '../utils/jsbridge';
import gsap from 'gsap';
import Logo from '../components/Logo';
import { AI_WATERMARK_TEXT } from '../utils/aiWatermark';

const formatRecordTime = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '刚刚保存';
  }

  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const getSessionGroupLabel = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '更早';
  }

  const today = new Date();
  const currentDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const targetDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.floor((currentDate.getTime() - targetDate.getTime()) / (1000 * 60 * 60 * 24));

  if (diffDays <= 0) {
    return '今天';
  }

  if (diffDays === 1) {
    return '昨天';
  }

  return '更早';
};

const maskPhone = (phone: string) => {
  if (!phone) {
    return '';
  }

  return phone.replace(/^(\d{3})\d{4}(\d{4})$/, '$1****$2');
};

const getAvatarLabel = (displayName: string) => {
  const trimmedDisplayName = displayName.trim();
  return trimmedDisplayName ? trimmedDisplayName.slice(0, 1) : '医';
};

const RELATION_OPTIONS = [
  { label: '本人', value: 'self' },
  { label: '母亲', value: 'mother' },
  { label: '父亲', value: 'father' },
  { label: '配偶', value: 'spouse' },
  { label: '孩子', value: 'child' },
  { label: '兄弟姐妹', value: 'sibling' },
  { label: '其他家人', value: 'other' },
];

const GENDER_OPTIONS = [
  { label: '男', value: '男' },
  { label: '女', value: '女' },
  { label: '未填写', value: '未填写' },
];

const RELATION_LABEL_MAP: Record<string, string> = {
  self: '本人',
  mother: '母亲',
  father: '父亲',
  spouse: '配偶',
  child: '孩子',
  sibling: '兄弟姐妹',
  parent: '父母',
  son: '儿子',
  daughter: '女儿',
  grandfather: '祖父',
  grandmother: '祖母',
  other: '其他家人',
};

const getRelationLabel = (relation: string) => RELATION_LABEL_MAP[relation] || relation;

function ChatPage() {
  const { message } = App.useApp();
  const navigate = useNavigate();
  const isFlutterEnv = typeof window !== 'undefined' && typeof window.FlutterBridge !== 'undefined';
  const [profileForm] = Form.useForm<{
    name: string;
    relation: string;
    gender: string;
    age: number;
    medical_history?: string;
    allergies?: string;
  }>();
  const [mode, setMode] = useState<'normal' | 'medical'>('normal');
  const [token, setToken] = useState<string>(normalizeAuthToken(localStorage.getItem('token')));
  const [currentUser, setCurrentUser] = useState<CurrentUserResponse | null>(null);
  const [chatSessions, setChatSessions] = useState<ChatSessionSummary[]>([]);
  const [isLoadingSessions, setIsLoadingSessions] = useState(false);
  const [activeSessionId, setActiveSessionId] = useState<number | null>(null);
  const [activeSessionMessages, setActiveSessionMessages] = useState<ChatSessionMessage[]>([]);
  const [activeConversationKey, setActiveConversationKey] = useState('new');
  const [isLoadingActiveSession, setIsLoadingActiveSession] = useState(false);
  const [deletingSessionId, setDeletingSessionId] = useState<number | null>(null);
  const [consultationRecords, setConsultationRecords] = useState<SavedConsultationRecord[]>([]);
  const [isLoadingRecords, setIsLoadingRecords] = useState(false);
  const [deletingConsultationRecordId, setDeletingConsultationRecordId] = useState<number | null>(null);
  const [profiles, setProfiles] = useState<HealthProfile[]>([]);
  const [selectedConsultationProfileId, setSelectedConsultationProfileId] = useState<number | null>(null);
  const [isProfilesModalOpen, setIsProfilesModalOpen] = useState(false);
  const [isLoadingProfiles, setIsLoadingProfiles] = useState(false);
  const [isCreatingProfile, setIsCreatingProfile] = useState(false);
  const [isSubmittingProfile, setIsSubmittingProfile] = useState(false);
  const pageRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    initJSBridge((receivedToken) => {
      const normalizedToken = normalizeAuthToken(receivedToken);
      setToken(normalizedToken);

      if (normalizedToken) {
        localStorage.setItem('token', normalizedToken);
      } else {
        localStorage.removeItem('token');
      }
    });
  }, []);

  useEffect(() => {
    if (!pageRef.current) {
      return;
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    gsap.fromTo(
      pageRef.current.querySelectorAll('[data-shell-enter]'),
      { opacity: 0, y: reduceMotion ? 0 : 12 },
      {
        opacity: 1,
        y: 0,
        duration: reduceMotion ? 0.1 : 0.45,
        ease: 'power4.out',
        stagger: reduceMotion ? 0 : 0.06,
      },
    );
  }, [mode]);
  const loadCurrentUser = useCallback(async () => {
    if (!token) {
      setCurrentUser(null);
      return;
    }

    try {
      const user = await fetchCurrentUser(token);
      setCurrentUser(user);
    } catch {
      setCurrentUser(null);
    }
  }, [token]);

  const loadConsultationRecords = useCallback(async () => {
    if (!token) {
      setConsultationRecords([]);
      return;
    }

    try {
      setIsLoadingRecords(true);
      const records = await fetchConsultationRecords(token);
      setConsultationRecords(records);
    } catch {
      setConsultationRecords([]);
    } finally {
      setIsLoadingRecords(false);
    }
  }, [token]);

  const loadProfiles = useCallback(async () => {
    if (!token) {
      setProfiles([]);
      return [];
    }

    try {
      setIsLoadingProfiles(true);
      const nextProfiles = await fetchHealthProfiles(token);
      setProfiles(nextProfiles);
      return nextProfiles;
    } catch (error: unknown) {
      const errorMessage = error instanceof Error && error.message ? error.message : '获取健康档案失败';
      message.error(errorMessage);
      return [];
    } finally {
      setIsLoadingProfiles(false);
    }
  }, [message, token]);

  const loadChatSessions = useCallback(async () => {
    if (!token) {
      setChatSessions([]);
      return;
    }

    try {
      setIsLoadingSessions(true);
      const sessions = await fetchChatSessions(token);
      setChatSessions(sessions);
    } catch {
      setChatSessions([]);
    } finally {
      setIsLoadingSessions(false);
    }
  }, [token]);

  const handleLogout = useCallback(async () => {
    const currentToken = token;
    if (currentToken) {
      try {
        await logoutCurrentUser(currentToken);
      } catch {
        // Local logout should still complete if the network request fails.
      }
    }
    localStorage.removeItem('token');
    setToken('');
    setCurrentUser(null);
    navigate('/login', { replace: true });
  }, [navigate, token]);

  useEffect(() => {
    void loadCurrentUser();
  }, [loadCurrentUser]);

  useEffect(() => {
    if (!token) {
      setChatSessions([]);
      setActiveSessionId(null);
      setActiveSessionMessages([]);
      setActiveConversationKey('new');
    }
  }, [token]);

  useEffect(() => {
    void loadChatSessions();
  }, [loadChatSessions]);

  useEffect(() => {
    void loadConsultationRecords();
  }, [loadConsultationRecords]);

  useEffect(() => {
    void loadProfiles();
  }, [loadProfiles]);

  const sortedProfiles = useMemo(
    () =>
      [...profiles].sort((left, right) => {
        if (left.relation === 'self' && right.relation !== 'self') {
          return -1;
        }

        if (left.relation !== 'self' && right.relation === 'self') {
          return 1;
        }

        return left.id - right.id;
      }),
    [profiles],
  );

  const selectedConsultationProfile = useMemo(
    () => sortedProfiles.find((profile) => profile.id === selectedConsultationProfileId) ?? null,
    [selectedConsultationProfileId, sortedProfiles],
  );

  const displayedConsultationRecords = useMemo(() => {
    if (mode === 'medical' && selectedConsultationProfileId) {
      return consultationRecords.filter((record) => record.profile_id === selectedConsultationProfileId);
    }

    return consultationRecords;
  }, [consultationRecords, mode, selectedConsultationProfileId]);

  useEffect(() => {
    if (!sortedProfiles.length) {
      setSelectedConsultationProfileId(null);
      return;
    }

    if (
      selectedConsultationProfileId &&
      sortedProfiles.some((profile) => profile.id === selectedConsultationProfileId)
    ) {
      return;
    }

    const defaultProfile = sortedProfiles.find((profile) => profile.relation === 'self') ?? sortedProfiles[0];
    setSelectedConsultationProfileId(defaultProfile?.id ?? null);
  }, [selectedConsultationProfileId, sortedProfiles]);

  const handleSelectChatSession = async (session: ChatSessionSummary) => {
    if (!token || isLoadingActiveSession) {
      return;
    }

    try {
      setIsLoadingActiveSession(true);
      const detail = await fetchChatSessionDetail(token, session.id);
      setMode(detail.mode);
      setActiveSessionId(detail.id);
      setActiveSessionMessages(detail.messages);
      setActiveConversationKey(`session_${detail.id}`);
    } catch (error: unknown) {
      const errorMessage = error instanceof Error && error.message ? error.message : '打开对话历史失败';
      message.error(errorMessage);
    } finally {
      setIsLoadingActiveSession(false);
    }
  };

  const handleStartNewConversation = () => {
    setActiveSessionId(null);
    setActiveSessionMessages([]);
    setActiveConversationKey(`new_${Date.now()}`);
  };

  const handleSessionPersisted = useCallback((session: ChatSessionSummary) => {
    setActiveSessionId(session.id);
    setChatSessions((currentSessions) => {
      const nextSessions = [session, ...currentSessions.filter((item) => item.id !== session.id)];
      return nextSessions.sort((left, right) => new Date(right.updated_at).getTime() - new Date(left.updated_at).getTime());
    });
  }, []);

  const groupedChatSessions = useMemo(() => {
    const groups: Array<{ label: '今天' | '昨天' | '更早'; items: ChatSessionSummary[] }> = [
      { label: '今天', items: [] },
      { label: '昨天', items: [] },
      { label: '更早', items: [] },
    ];

    chatSessions.forEach((session) => {
      const group = groups.find((item) => item.label === getSessionGroupLabel(session.updated_at));
      group?.items.push(session);
    });

    return groups.filter((group) => group.items.length > 0);
  }, [chatSessions]);

  const handleDeleteChatSession = useCallback(
    (session: ChatSessionSummary) => {
      if (!token || deletingSessionId) {
        return;
      }

      Modal.confirm({
        title: '删除这条对话历史？',
        content: '删除后将无法恢复，但不会影响已经保存的个人问诊记录。',
        okText: '确认删除',
        cancelText: '取消',
        okButtonProps: {
          danger: true,
          className: 'rounded-xl',
        },
        cancelButtonProps: {
          className: 'rounded-xl',
        },
        onOk: async () => {
          try {
            setDeletingSessionId(session.id);
            await deleteChatSession(token, session.id);
            setChatSessions((currentSessions) => currentSessions.filter((item) => item.id !== session.id));

            if (activeSessionId === session.id) {
              setActiveSessionId(null);
              setActiveSessionMessages([]);
              setActiveConversationKey(`new_${Date.now()}`);
            }

            message.success('已删除这条对话历史');
          } catch (error: unknown) {
            const errorMessage = error instanceof Error && error.message ? error.message : '删除对话历史失败';
            message.error(errorMessage);
          } finally {
            setDeletingSessionId(null);
          }
        },
      });
    },
    [activeSessionId, deletingSessionId, message, token],
  );

  const handleDeleteConsultationRecord = useCallback(
    (record: SavedConsultationRecord) => {
      if (!token || deletingConsultationRecordId) {
        return;
      }

      Modal.confirm({
        title: '删除这条问诊记录？',
        content: '删除后将无法恢复，同时会从对应健康档案的病史中移除这条记录。',
        okText: '确认删除',
        cancelText: '取消',
        okButtonProps: {
          danger: true,
          className: 'rounded-xl',
        },
        cancelButtonProps: {
          className: 'rounded-xl',
        },
        onOk: async () => {
          try {
            setDeletingConsultationRecordId(record.id);
            await deleteConsultationRecord(token, record.id);
            setConsultationRecords((currentRecords) => currentRecords.filter((item) => item.id !== record.id));
            await loadProfiles();
            message.success('已删除问诊记录，并同步更新健康档案病史');
          } catch (error: unknown) {
            const errorMessage = error instanceof Error && error.message ? error.message : '删除问诊记录失败';
            message.error(errorMessage);
          } finally {
            setDeletingConsultationRecordId(null);
          }
        },
      });
    },
    [deletingConsultationRecordId, loadProfiles, message, token],
  );

  const handleOpenHealthProfiles = async () => {
    if (!token) {
      navigate('/login');
      return;
    }
    setIsProfilesModalOpen(true);
    setIsCreatingProfile(false);
    profileForm.resetFields();
    profileForm.setFieldsValue({
      name: currentUser?.display_name || '',
      relation: sortedProfiles.some((profile) => profile.relation === 'self') ? 'mother' : 'self',
      gender: '未填写',
    });
    await loadProfiles();
  };

  const handleCreateProfile = async (values: {
    name: string;
    relation: string;
    gender: string;
    age: number;
    medical_history?: string;
    allergies?: string;
  }) => {
    if (!token) {
      navigate('/login');
      return;
    }

    try {
      setIsSubmittingProfile(true);
      const createdProfile = await createHealthProfile(token, {
        ...values,
        medical_history: values.medical_history?.trim() || null,
        allergies: values.allergies?.trim() || null,
      });
      const nextProfiles = [...profiles, createdProfile];
      setProfiles(nextProfiles);
      setSelectedConsultationProfileId(createdProfile.id);
      setIsCreatingProfile(false);
      profileForm.resetFields();
      message.success(`已为${createdProfile.name}创建健康档案`);
    } catch (error: unknown) {
      const errorMessage = error instanceof Error && error.message ? error.message : '创建健康档案失败';
      message.error(errorMessage);
    } finally {
      setIsSubmittingProfile(false);
    }
  };

  return (
    <ConfigProvider
      theme={{
        algorithm: theme.defaultAlgorithm,
        token: {
          colorPrimary: 'oklch(0.205 0 0)',
          borderRadius: 18,
        },
      }}
    >
      <div
        ref={pageRef}
        className="flex h-screen w-screen overflow-hidden bg-[radial-gradient(circle_at_top,rgba(99,102,241,0.16),transparent_28%),radial-gradient(circle_at_bottom_right,rgba(168,85,247,0.12),transparent_24%),linear-gradient(180deg,#eef1ff_0%,#f5f6ff_55%,#f6f3ff_100%)]"
      >
        <aside className="hidden h-full w-[272px] shrink-0 flex-col border-r border-white/50 bg-white/55 backdrop-blur-xl lg:flex">
          <div data-shell-enter className="flex items-center justify-between px-5 pb-4 pt-5">
            <div className="flex items-center gap-3">
              <Logo className="w-10 h-10 rounded-xl" />
              <div>
                <div className="text-lg font-semibold tracking-tight text-foreground">三十天时刻智护</div>
                <div className="text-xs text-muted-foreground">你的 AI 健康助手</div>
              </div>
            </div>
            {/* <Button
              type="text"
              icon={<EditOutlined />}
              className="flex h-9 w-9 items-center justify-center rounded-full border border-white/60 bg-white/70 text-foreground shadow-sm"
            /> */}
          </div>

          <div data-shell-enter className="px-4">
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={handleStartNewConversation}
              className="h-11 w-full rounded-2xl border-0 bg-[linear-gradient(135deg,rgba(99,102,241,0.95),rgba(129,140,248,0.82))] text-sm font-semibold shadow-[0_16px_34px_rgba(99,102,241,0.24)]"
            >
              开启新对话
            </Button>
          </div>

          <div data-shell-enter className="mt-5 px-4">
            <div className="rounded-[28px] border border-white/60 bg-white/80 p-3 shadow-[0_20px_45px_rgba(149,157,215,0.14)]">
              <div className="mb-2 text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">咨询模式</div>
              <div className="grid grid-cols-2 gap-2">
                <Button
                  type={mode === 'normal' ? 'primary' : 'default'}
                  onClick={() => setMode('normal')}
                  className="h-10 rounded-2xl border-0 text-sm shadow-none"
                >
                  健康问答
                </Button>
                <Button
                  type={mode === 'medical' ? 'primary' : 'default'}
                  onClick={() => setMode('medical')}
                  className="h-10 rounded-2xl border-0 text-sm shadow-none"
                >
                  AI导诊
                </Button>
              </div>
            </div>
          </div>

          <div className="scrollbar-hidden mt-6 flex-1 overflow-y-auto px-3 pb-4">
            <div data-shell-enter className="mb-4 px-2 text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              对话历史
            </div>
            {!token ? (
              <div
                data-shell-enter
                className="rounded-[22px] border border-dashed border-white/70 bg-white/58 px-4 py-4 text-sm leading-6 text-muted-foreground"
              >
                登录后会自动记录每一次新对话，方便你后续回看曾经咨询过的问题与 AI 回复。
              </div>
            ) : isLoadingSessions ? (
              <div
                data-shell-enter
                className="rounded-[22px] border border-white/70 bg-white/62 px-4 py-4 text-sm text-muted-foreground"
              >
                正在加载对话历史…
              </div>
            ) : chatSessions.length ? (
              <div className="space-y-4">
                {groupedChatSessions.map((group) => (
                  <div key={group.label} data-shell-enter className="space-y-2">
                    <div className="px-2 text-[11px] font-semibold uppercase tracking-[0.24em] text-muted-foreground/80">
                      {group.label}
                    </div>
                    <div className="space-y-2">
                      {group.items.map((session) => {
                        const isActive = activeSessionId === session.id;
                        const isDeleting = deletingSessionId === session.id;

                        return (
                          <div
                            key={session.id}
                            className={`group rounded-[22px] border px-3 py-3 ${
                              isActive
                                ? 'border-indigo-200/80 bg-[linear-gradient(135deg,rgba(255,255,255,0.96),rgba(238,242,255,0.98))] shadow-[0_14px_30px_rgba(99,102,241,0.12)]'
                                : 'border-white/70 bg-white/68'
                            }`}
                          >
                            <div className="flex items-start gap-3">
                              <button
                                type="button"
                                disabled={isLoadingActiveSession || isDeleting}
                                onClick={() => {
                                  void handleSelectChatSession(session);
                                }}
                                className="flex min-w-0 flex-1 items-start gap-3 text-left"
                              >
                                <div
                                  className={`mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-2xl ${
                                    isActive ? 'bg-indigo-100 text-indigo-600' : 'bg-white/85 text-muted-foreground'
                                  }`}
                                >
                                  <MessageOutlined className="text-xs" />
                                </div>
                                <div className="min-w-0 flex-1">
                                  <div className="line-clamp-2 text-sm font-medium leading-6 text-foreground">
                                    {session.title}
                                  </div>
                                  <div className="mt-1 line-clamp-2 text-xs leading-5 text-muted-foreground">
                                    {session.last_message || '点击查看完整对话记录'}
                                  </div>
                                  <div className="mt-2 flex items-center justify-between gap-3 text-xs text-muted-foreground">
                                    <span className="truncate">{session.mode === 'medical' ? 'AI导诊' : '健康问答'}</span>
                                    <span className="shrink-0">{formatRecordTime(session.updated_at)}</span>
                                  </div>
                                </div>
                              </button>
                              <Button
                                type="text"
                                danger
                                icon={<DeleteOutlined />}
                                loading={isDeleting}
                                onClick={() => {
                                  handleDeleteChatSession(session);
                                }}
                                className={`mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-2xl bg-white/72 text-muted-foreground hover:bg-red-50 hover:text-red-500 ${
                                  isDeleting
                                    ? 'opacity-100'
                                    : 'pointer-events-none opacity-0 group-hover:pointer-events-auto group-hover:opacity-100 group-focus-within:pointer-events-auto group-focus-within:opacity-100'
                                }`}
                              />
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div
                data-shell-enter
                className="rounded-[22px] border border-dashed border-white/70 bg-white/58 px-4 py-4 text-sm leading-6 text-muted-foreground"
              >
                还没有历史对话。发送第一条消息后，系统会自动为你创建一条新的对话记录。
              </div>
            )}

            <div data-shell-enter className="mb-4 mt-6 px-2 text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground flex justify-between items-center">
              <span>个人问诊记录</span>
              {token && !profiles.length && (
                <Button 
                  type="link" 
                  size="small" 
                  className="text-[10px] h-auto p-0 text-indigo-500"
                  onClick={() => void handleOpenHealthProfiles()}
                >
                  完善健康档案获得精准建议 &gt;
                </Button>
              )}
            </div>
            {!token ? (
              <div
                data-shell-enter
                className="rounded-[22px] border border-dashed border-white/70 bg-white/58 px-4 py-4 text-sm leading-6 text-muted-foreground"
              >
                登录后可保存问诊结果，系统会在后续问答中自动参考你的历史病例信息。
              </div>
            ) : isLoadingRecords ? (
              <div
                data-shell-enter
                className="rounded-[22px] border border-white/70 bg-white/62 px-4 py-4 text-sm text-muted-foreground"
              >
                正在加载个人问诊记录…
              </div>
            ) : displayedConsultationRecords.length ? (
              <div className="space-y-2">
                {mode === 'medical' && selectedConsultationProfile && (
                  <div className="rounded-[20px] border border-indigo-100/80 bg-[linear-gradient(135deg,rgba(255,255,255,0.96),rgba(241,245,255,0.94))] px-4 py-3 text-xs leading-6 text-muted-foreground">
                    当前显示 <span className="font-semibold text-foreground">{selectedConsultationProfile.name}</span> 的个人问诊记录
                  </div>
                )}
                {displayedConsultationRecords.map((record, index) => (
                  <div
                    key={record.id}
                    data-shell-enter
                    className={`group rounded-[22px] border px-3 py-3 ${
                      index === 0
                        ? 'border-indigo-200/80 bg-[linear-gradient(135deg,rgba(255,255,255,0.95),rgba(238,242,255,0.95))] shadow-[0_14px_30px_rgba(99,102,241,0.10)]'
                        : 'border-white/70 bg-white/68'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div
                        className={`mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-2xl ${
                          index === 0 ? 'bg-indigo-100 text-indigo-600' : 'bg-white/85 text-muted-foreground'
                        }`}
                      >
                        <MessageOutlined className="text-xs" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0 flex-1 line-clamp-2 text-sm font-medium leading-6 text-foreground">
                            {record.summary || record.analysis || '已保存的问诊记录'}
                          </div>
                          <div className="flex shrink-0 items-center gap-1">
                            <div className="rounded-full bg-white/85 px-2.5 py-1 text-[11px] text-muted-foreground">
                              {record.profile_name} · {getRelationLabel(record.relation)}
                            </div>
                            <Button
                              type="text"
                              danger
                              aria-label="删除问诊记录"
                              title="删除问诊记录"
                              icon={<DeleteOutlined />}
                              loading={deletingConsultationRecordId === record.id}
                              onClick={() => handleDeleteConsultationRecord(record)}
                              className={`flex h-8 w-8 items-center justify-center rounded-xl text-muted-foreground hover:bg-red-50 hover:text-red-500 ${
                                deletingConsultationRecordId === record.id
                                  ? 'opacity-100'
                                  : 'pointer-events-none opacity-0 group-hover:pointer-events-auto group-hover:opacity-100 group-focus-within:pointer-events-auto group-focus-within:opacity-100'
                              }`}
                            />
                          </div>
                        </div>
                        <div className="mt-2 flex items-center justify-between gap-3 text-xs text-muted-foreground">
                          <span className="truncate">{record.recommended_department || '待定科室'}</span>
                          <span className="shrink-0">{formatRecordTime(record.created_at)}</span>
                        </div>
                        {record.hospital_suggestion && (
                          <div className="mt-2 line-clamp-2 text-xs leading-5 text-muted-foreground">
                            {record.hospital_suggestion}
                          </div>
                        )}
                        <div className="mt-2 text-[10px] text-muted-foreground/80">
                          {AI_WATERMARK_TEXT}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div
                data-shell-enter
                className="rounded-[22px] border border-dashed border-white/70 bg-white/58 px-4 py-4 text-sm leading-6 text-muted-foreground"
              >
                {mode === 'medical' && selectedConsultationProfile
                  ? `暂无${selectedConsultationProfile.name}的问诊记录。完成一次AI导诊后，点击问诊卡片里的“保存到个人记录”即可沉淀为对应咨询人的病例。`
                  : '暂无保存的问诊结果。完成一次AI导诊后，点击问诊卡片里的“保存到个人记录”即可沉淀为历史病例。'}
              </div>
            )}
          </div>

          <div data-shell-enter className="space-y-2 border-t border-white/50 px-4 py-4">
            {token && currentUser ? (
              <>
                <Button
                  type="text"
                  icon={<IdcardOutlined />}
                  onClick={() => {
                    void handleOpenHealthProfiles();
                  }}
                  className="flex h-10 w-full items-center justify-start gap-2 rounded-2xl bg-white/60 px-3 text-sm text-foreground"
                >
                  健康档案
                </Button>
                <button
                  type="button"
                  className="flex w-full items-center gap-3 rounded-[24px] border border-white/70 bg-white/78 px-3 py-3 text-left shadow-[0_18px_36px_rgba(149,157,215,0.12)]"
                >
                  <Avatar className="flex h-11 w-11 items-center justify-center bg-[linear-gradient(135deg,rgba(99,102,241,0.94),rgba(168,85,247,0.82))] text-sm font-semibold text-white">
                    {getAvatarLabel(currentUser.display_name)}
                  </Avatar>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-semibold text-foreground">{currentUser.display_name}</div>
                    <div className="mt-1 truncate text-xs text-muted-foreground">
                      {maskPhone(currentUser.phone)}
                    </div>
                  </div>
                </button>
                {!isFlutterEnv && (
                  <Button
                    type="text"
                    icon={<LogoutOutlined />}
                    onClick={() => {
                      void handleLogout();
                    }}
                    className="flex h-10 w-full items-center justify-start gap-2 rounded-2xl px-3 text-sm text-muted-foreground"
                  >
                    退出登录
                  </Button>
                )}
              </>
            ) : (
              <Button
                type="text"
                icon={<UserOutlined />}
                onClick={() => navigate('/login')}
                className="flex h-10 w-full items-center justify-start gap-2 rounded-2xl px-3 text-sm text-muted-foreground"
              >
                点击登录
              </Button>
            )}
          </div>
        </aside>

        <main className="flex min-w-0 flex-1 flex-col">
          <header className="hidden items-center justify-between px-6 pb-4 pt-5 lg:flex">
            <div data-shell-enter className="flex items-center gap-3">
              {/* <Button
                type="text"
                icon={<MenuOutlined />}
                className="flex h-11 w-11 items-center justify-center rounded-full border border-white/60 bg-white/72 text-foreground shadow-sm"
              /> */}
              {/* <div className="rounded-full border border-white/60 bg-white/70 px-4 py-2 text-sm font-medium text-muted-foreground shadow-sm">
                三十天时刻智护 · AI 健康助手
              </div> */}
            </div>
            <div data-shell-enter className="text-center">
              <div className="text-lg font-semibold tracking-tight text-foreground">我是时小安，你的 AI 健康助手</div>
              <div className="mt-1 text-sm text-muted-foreground">医学问题、解读报告、检索文献，都来问我吧</div>
            </div>
            <div data-shell-enter className="flex items-center gap-2">
              <Button
                type={mode === 'normal' ? 'primary' : 'default'}
                onClick={() => setMode('normal')}
                className="h-10 rounded-full border-0 px-5"
              >
                健康问答
              </Button>
              <Button
                type={mode === 'medical' ? 'primary' : 'default'}
                onClick={() => setMode('medical')}
                className="h-10 rounded-full border-0 px-5"
              >
                AI导诊
              </Button>
            </div>
          </header>

          <header className="flex items-center justify-between px-4 pb-3 pt-[max(env(safe-area-inset-top),12px)] lg:hidden">
            <div data-shell-enter className="flex items-center gap-2">
              <Button
                type="text"
                icon={<LeftOutlined />}
                onClick={notifyFlutterBack}
                className="flex h-11 w-11 items-center justify-center rounded-full border border-white/60 bg-white/75 text-foreground shadow-sm"
              />
              <div className="flex items-center gap-2">
                <Logo className="w-10 h-10 rounded-xl" />
                <div>
                  <div className="text-[1.75rem] font-semibold leading-none tracking-tight text-foreground">三十天时刻智护</div>
                </div>
              </div>
            </div>
            <div data-shell-enter className="flex items-center gap-2">
              <div className="rounded-full border border-white/60 bg-white/75 px-4 py-2 text-sm font-semibold text-foreground shadow-sm">
                {mode === 'normal' ? '智能体' : '问诊中'}
              </div>
              <Button
                type="text"
                icon={<AudioMutedOutlined />}
                className="flex h-11 w-11 items-center justify-center rounded-full border border-white/60 bg-white/75 text-foreground shadow-sm"
              />
              <Button
                type="text"
                icon={<MoreOutlined />}
                className="flex h-11 w-11 items-center justify-center rounded-full border border-white/60 bg-white/75 text-foreground shadow-sm"
              />
            </div>
          </header>

          {mode === 'medical' && token && (
            <div className="px-4 pb-3 lg:px-6">
              <div
                data-shell-enter
                className="rounded-[28px] border border-white/65 bg-white/78 p-4 shadow-[0_20px_48px_rgba(148,163,184,0.14)]"
              >
                <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                  <div>
                    <div className="text-sm font-semibold text-foreground">当前咨询人</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      AI导诊保存的问诊卡片会自动关联到当前选中的健康档案
                    </div>
                  </div>
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                    {sortedProfiles.length ? (
                      <Select
                        value={selectedConsultationProfileId ?? undefined}
                        onChange={(value) => {
                          if (mode === 'medical' && value !== selectedConsultationProfileId) {
                            // AI导诊模式下切换就诊人：开启新会话，避免不同咨询人的对话混在一起
                            handleStartNewConversation();
                          }
                          setSelectedConsultationProfileId(value);
                        }}
                        options={sortedProfiles.map((profile) => ({
                          value: profile.id,
                          label: `${profile.name} · ${getRelationLabel(profile.relation)}`,
                        }))}
                        className="min-w-[220px]"
                      />
                    ) : (
                      <div className="rounded-2xl bg-muted/50 px-3 py-2 text-xs text-muted-foreground">
                        还没有可选咨询人，请先创建本人或家人档案
                      </div>
                    )}
                    <Button
                      type="default"
                      onClick={() => {
                        void handleOpenHealthProfiles();
                      }}
                      className="h-10 rounded-full border-white/70 bg-white/80 px-4"
                    >
                      管理健康档案
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div data-shell-enter className="min-h-0 flex-1 px-0 pb-0 lg:px-6 lg:pb-6">
            <ChatContainer
              mode={mode}
              token={token}
              activeSessionId={activeSessionId}
              initialMessages={activeSessionMessages}
              conversationKey={activeConversationKey}
              consultationProfileId={selectedConsultationProfileId}
              consultationProfileName={selectedConsultationProfile?.name ?? null}
              onModeChange={setMode}
              onRecordsChange={loadConsultationRecords}
              onSessionPersisted={handleSessionPersisted}
            />
          </div>
        </main>
      </div>
      <Modal
        open={isProfilesModalOpen}
        onCancel={() => setIsProfilesModalOpen(false)}
        footer={null}
        centered
        title="健康档案"
      >
        <div className="space-y-4">
          <div className="rounded-[22px] border border-white/70 bg-[linear-gradient(135deg,rgba(255,255,255,0.96),rgba(241,245,255,0.92))] px-4 py-4 text-sm leading-6 text-muted-foreground">
            你可以在这里为自己或家人建立健康档案。AI导诊保存的问诊结果，会自动归档到当前选中的咨询人名下。
          </div>

          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="text-sm font-semibold text-foreground">档案列表</div>
              <div className="mt-1 text-xs text-muted-foreground">支持维护本人、父母、孩子等家人的长期健康信息</div>
            </div>
            <Button
              type={isCreatingProfile ? 'default' : 'primary'}
              icon={<PlusOutlined />}
              onClick={() => {
                setIsCreatingProfile((current) => !current);
                profileForm.setFieldsValue({
                  name: currentUser?.display_name || '',
                  relation: sortedProfiles.some((profile) => profile.relation === 'self') ? 'mother' : 'self',
                  gender: '未填写',
                });
              }}
              className="h-10 rounded-full border-0 px-4"
            >
              {isCreatingProfile ? '收起创建' : '新建家人档案'}
            </Button>
          </div>

          {isCreatingProfile && (
            <div className="rounded-[24px] border border-white/70 bg-white/88 px-4 py-4 shadow-[0_12px_32px_rgba(149,157,215,0.10)]">
              <Form layout="vertical" form={profileForm} onFinish={(values) => void handleCreateProfile(values)}>
                <div className="grid gap-3 sm:grid-cols-2">
                  <Form.Item
                    label="姓名"
                    name="name"
                    rules={[{ required: true, message: '请填写咨询人姓名' }]}
                    className="mb-0"
                  >
                    <Input placeholder="例如：妈妈 / 张女士 / 本人" className="rounded-2xl" />
                  </Form.Item>
                  <Form.Item
                    label="关系"
                    name="relation"
                    rules={[{ required: true, message: '请选择与自己的关系' }]}
                    className="mb-0"
                  >
                    <Select options={RELATION_OPTIONS} className="rounded-2xl" />
                  </Form.Item>
                  <Form.Item
                    label="性别"
                    name="gender"
                    rules={[{ required: true, message: '请选择性别' }]}
                    className="mb-0"
                  >
                    <Select options={GENDER_OPTIONS} className="rounded-2xl" />
                  </Form.Item>
                  <Form.Item
                    label="年龄"
                    name="age"
                    rules={[{ required: true, message: '请填写年龄' }]}
                    className="mb-0"
                  >
                    <InputNumber min={0} max={120} className="w-full rounded-2xl" placeholder="年龄" />
                  </Form.Item>
                </div>
                <Form.Item label="既往病史" name="medical_history" className="mb-3 mt-3">
                  <Input.TextArea rows={3} placeholder="如高血压、糖尿病、手术史等" className="rounded-2xl" />
                </Form.Item>
                <Form.Item label="过敏信息" name="allergies" className="mb-0">
                  <Input.TextArea rows={2} placeholder="如药物、食物或环境过敏" className="rounded-2xl" />
                </Form.Item>
                <div className="mt-4 flex items-center justify-end gap-2">
                  <Button
                    onClick={() => {
                      setIsCreatingProfile(false);
                      profileForm.resetFields();
                    }}
                    className="h-10 rounded-full px-4"
                  >
                    取消
                  </Button>
                  <Button htmlType="submit" type="primary" loading={isSubmittingProfile} className="h-10 rounded-full px-5">
                    保存档案
                  </Button>
                </div>
              </Form>
            </div>
          )}

          {isLoadingProfiles ? (
            <div className="rounded-2xl border border-white/70 bg-muted/40 px-4 py-5 text-sm text-muted-foreground">
              正在加载健康档案…
            </div>
          ) : profiles.length ? (
            sortedProfiles.map((profile) => (
              <div
                key={profile.id}
                className="rounded-[22px] border border-white/70 bg-white px-4 py-4 shadow-[0_12px_30px_rgba(149,157,215,0.10)]"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-foreground">{profile.name}</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {getRelationLabel(profile.relation)} · {profile.gender} · {profile.age} 岁
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {selectedConsultationProfileId === profile.id && (
                      <div className="rounded-full bg-indigo-100 px-3 py-1 text-xs text-indigo-700">当前咨询人</div>
                    )}
                    <Button
                      type={selectedConsultationProfileId === profile.id ? 'primary' : 'default'}
                      onClick={() => setSelectedConsultationProfileId(profile.id)}
                      className="h-9 rounded-full px-4"
                    >
                      {selectedConsultationProfileId === profile.id ? '已选中' : '用于AI导诊'}
                    </Button>
                  </div>
                </div>
                <div className="mt-3 space-y-2 text-sm leading-6 text-muted-foreground">
                  <div>病史：{profile.medical_history || '暂无记录'}</div>
                  <div>过敏：{profile.allergies || '暂无记录'}</div>
                </div>
                
                {/* 问诊记录卡片折叠面板 */}
                {consultationRecords.filter(record => record.profile_id === profile.id).length > 0 && (
                  <div className="mt-4 border-t border-muted/30 pt-3">
                    <Collapse
                      ghost
                      size="small"
                      expandIconPosition="end"
                      items={[
                        {
                          key: 'records',
                          label: <span className="text-xs font-medium text-muted-foreground">该成员的问诊记录 ({consultationRecords.filter(record => record.profile_id === profile.id).length})</span>,
                          children: (
                            <div className="flex flex-col gap-3 mt-1">
                              {consultationRecords
                                .filter(record => record.profile_id === profile.id)
                                .map(record => (
                                  <div key={record.id} className="rounded-xl border border-muted/50 bg-slate-50/50 p-3 text-xs">
                                    <div className="mb-2 font-medium text-foreground border-b border-muted/20 pb-1">
                                      记录时间: {new Date(record.created_at).toLocaleString('zh-CN', { hour12: false })}
                                    </div>
                                    <div className="space-y-1.5 text-muted-foreground">
                                      {record.summary && <div><span className="font-medium text-slate-700">患者概览：</span>{record.summary}</div>}
                                      {record.analysis && <div><span className="font-medium text-slate-700">病情分析：</span>{record.analysis}</div>}
                                      {record.recommended_department && <div><span className="font-medium text-slate-700">推荐科室：</span>{record.recommended_department}</div>}
                                      {record.hospital_suggestion && <div><span className="font-medium text-slate-700">就医建议：</span>{record.hospital_suggestion}</div>}
                                    </div>
                                    <div className="mt-2 border-t border-muted/30 pt-1.5 text-[10px] text-muted-foreground/80">
                                      {AI_WATERMARK_TEXT}
                                    </div>
                                  </div>
                                ))}
                            </div>
                          ),
                        }
                      ]}
                    />
                  </div>
                )}
              </div>
            ))
          ) : (
            <div className="rounded-2xl border border-dashed border-white/70 bg-muted/30 px-4 py-5 text-sm text-muted-foreground">
              你还没有创建健康档案，后续可以在这里管理本人或家人的基础健康信息。
            </div>
          )}
        </div>
      </Modal>
    </ConfigProvider>
  );
}

export default ChatPage;
