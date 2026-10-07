import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Actions, Sender, Bubble } from '@ant-design/x';
import type { BubbleItemType } from '@ant-design/x';
import { App, Avatar, Button, Grid, Input, Modal } from 'antd';
import { useNavigate } from 'react-router-dom';
import {
  ArrowRightOutlined,
  ArrowUpOutlined,
  CopyOutlined,
  MessageOutlined,
  DeleteOutlined,
  ExperimentOutlined,
  FileImageOutlined,
  FilePdfOutlined,
  MedicineBoxOutlined,
  PlusCircleOutlined,
  ReadOutlined,
  RedoOutlined,
  SkinOutlined,
} from '@ant-design/icons';
import MessageRender from './MessageRender';
import { AI_WATERMARK_TEXT } from '../utils/aiWatermark';
import { fetchChatStream } from '../api/chat';
import type { ChatStreamChunk } from '../api/chat';
import { fetchPublishedQuestions } from '../api/questions';
import { saveChatSession } from '../api/chatSessions';
import type { ChatSessionMessage, ChatSessionSummary } from '../api/chatSessions';
import { saveConsultationRecord } from '../api/consultations';
import { submitAiFeedback } from '../api/feedback';
import type { ConsultationCardData, ConsultationChatTurn } from '../api/consultations';
import gsap from 'gsap';
import heroImage from '../assets/hero.webp';

interface ChatContainerProps {
  mode: 'normal' | 'medical';
  token?: string;
  activeSessionId?: number | null;
  initialMessages?: ChatSessionMessage[];
  conversationKey?: string;
  consultationProfileId?: number | null;
  consultationProfileName?: string | null;
  onModeChange?: (mode: 'normal' | 'medical') => void;
  onRecordsChange?: () => Promise<void> | void;
  onSessionPersisted?: (session: ChatSessionSummary) => void;
}

interface ChatMessage extends ChatSessionMessage {
  attachments?: PendingAttachment[];
  loading?: boolean;
  safety?: ChatStreamChunk;
  notice?: string;
}

interface PendingAttachment {
  id: string;
  file: File;
  kind: 'image' | 'pdf';
  status: 'pending' | 'uploading' | 'success' | 'error';
  fileId?: string;
}

interface AttachmentContextItem {
  id: string;
  fileId: string;
  name: string;
  kind: PendingAttachment['kind'];
  size: number;
}

// AI 回复复制标识尾巴：点击"复制"按钮与选中文字复制（Ctrl+C / 右键复制）均需追加
const AI_COPY_SUFFIX = `——${AI_WATERMARK_TEXT}`;

const AttachmentThumbnail = ({ attachment }: { attachment: PendingAttachment }) => {
  const previewUrl = useMemo(() => {
    return attachment.kind === 'image' ? URL.createObjectURL(attachment.file) : null;
  }, [attachment.file, attachment.kind]);

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  if (attachment.kind === 'image') {
    return previewUrl ? (
      <img
        src={previewUrl}
        alt={attachment.file.name}
        className="h-10 w-10 shrink-0 rounded-lg object-cover ring-1 ring-border/60"
      />
    ) : (
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-muted/70 text-foreground">
        <FileImageOutlined />
      </div>
    );
  }

  return (
    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-red-50 text-red-500">
      <FilePdfOutlined />
    </div>
  );
};

const MAX_ATTACHMENTS = 5;
const STARTER_PROMPTS = [
  {
    category: '报告解读',
    question: '如何快速看懂血常规检查报告？',
    answer:
      '看血常规时可以先抓 4 个重点：一是白细胞，看是否提示感染或炎症；二是血红蛋白，看有无贫血；三是红细胞平均体积，看贫血类型；四是血小板，看凝血相关风险。如果你有具体的报告数值，我可以按“异常项、可能原因、是否需要复查”三步继续帮你解读。',
  },
  {
    category: '呼吸健康',
    question: '一直咳嗽两周需要注意什么？',
    answer:
      '咳嗽持续两周，先重点留意有没有发热、胸闷气短、黄痰带血、夜间明显加重，或近期接触流感、过敏源。如果只是轻度干咳，常见于感冒后气道敏感、过敏或鼻后滴流；如果伴随喘息、胸痛或症状越来越重，建议尽快线下就诊呼吸内科。我也可以继续帮你做一次症状分层判断。',
  },
  {
    category: '体检异常',
    question: '体检发现脂肪肝应该怎么办？',
    answer:
      '脂肪肝多数与体重、饮食结构、久坐和代谢问题有关，第一步通常不是急着吃药，而是先看肝功能、血脂、血糖和腹部超声结果。生活方式上建议控制含糖饮料和夜宵，增加步行或有氧运动，结合减重管理。若转氨酶升高、合并肥胖或糖脂代谢异常，建议到消化内科或肝病门诊进一步评估。',
  },
  {
    category: '就医分诊',
    question: '胃痛反复发作该挂什么科？',
    answer:
      '胃痛反复发作一般优先挂消化内科，尤其是伴随反酸、腹胀、恶心、黑便或进食后疼痛时更要尽快评估。如果疼痛突然加重、伴呕吐或明显出汗，也要警惕急腹症。就诊前可以先回忆疼痛部位、与进食关系、持续时间和是否服用止痛药，这些信息会帮助医生更快判断。',
  },
  {
    category: '儿科观察',
    question: '孩子发烧反复应该怎么观察？',
    answer:
      '孩子反复发烧时，重点观察精神状态、进食饮水、尿量、呼吸是否费力，以及体温变化和退烧药效果。若孩子精神差、持续高热超过 3 天、抽搐、呼吸急促、皮疹或明显嗜睡，应尽快就医。若你愿意，我可以按年龄、最高体温和伴随症状继续帮你判断风险等级。',
  },
  {
    category: '肝功能',
    question: '体检报告里转氨酶偏高说明什么？',
    answer:
      '转氨酶偏高说明肝细胞可能受到刺激或损伤，常见原因包括熬夜饮酒、脂肪肝、病毒性肝炎、药物影响或剧烈运动后暂时升高。判断严不严重，要结合 ALT、AST 的具体数值，以及胆红素、乙肝指标、腹部超声等一起看。若只是轻度升高，可先避免酒精和熬夜并复查；若持续升高或数值明显异常，建议尽快就诊。',
  },
];
const SHORTCUTS = [
  { label: 'AI导诊', prompt: '请根据我的症状给出初步分析', icon: <MedicineBoxOutlined /> },
  { label: '深度思考', prompt: '帮我快速检索相关医学信息', icon: <ExperimentOutlined /> },
  { label: '拍皮肤', prompt: '上传皮肤图片后我应该怎么描述症状？', icon: <SkinOutlined /> },
  { label: '就医助手', prompt: '帮我判断应该挂什么科', icon: <ReadOutlined /> },
];
const MOBILE_FEED_CARDS = [
  {
    title: '吃什么能有效祛湿？',
    description: '三十天时刻智护为你准备祛湿攻略',
    action: '去看看',
    prompt: '从饮食、作息、运动角度给我一份祛湿建议',
  },
  {
    title: '喝水后一直小便的人 vs 半天不去厕所的人，谁更健康？',
    description: '从饮水量和代谢角度解释',
    action: '了解',
    prompt: '喝水后排尿频率和健康之间有什么关系？',
  },
  {
    title: '睡觉穿袜子和不穿袜子，哪个更好？',
    description: '看看睡眠保暖的建议',
    action: '查看',
    prompt: '睡觉穿袜子和不穿袜子分别适合哪些人？',
  },
];
const HEALTH_SNAPSHOT = [
  { label: '报告单', value: '1 份' },
  { label: '健康档案', value: '更多数据' },
];

const formatFileSize = (size: number) => {
  if (size < 1024) {
    return `${size} B`;
  }

  if (size < 1024 * 1024) {
    return `${Math.round(size / 102.4) / 10} KB`;
  }

  return `${Math.round(size / 1024 / 102.4) / 10} MB`;
};

const getAttachmentKind = (file: File): PendingAttachment['kind'] | null => {
  if (file.type.startsWith('image/')) {
    return 'image';
  }

  if (file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')) {
    return 'pdf';
  }

  return null;
};

const buildMessageContent = (message: string) => {
  return message.trim();
};

const buildContextDisplayContent = (message: string) => {
  return message.trim();
};

const mergeAttachmentContexts = (
  currentContexts: AttachmentContextItem[],
  newAttachments: PendingAttachment[],
  effectiveFileIds: string[],
  newFileIds: string[],
) => {
  const nextContexts: AttachmentContextItem[] = [];
  const currentContextMap = new Map(currentContexts.map((item) => [item.fileId, item]));
  const newContextMap = new Map(
    newAttachments.map((attachment, index) => {
      const fileId = newFileIds[index];
      return fileId
        ? [fileId, {
          id: `${fileId}_${attachment.id}`,
          fileId,
          name: attachment.file.name,
          kind: attachment.kind,
          size: attachment.file.size,
        }]
        : null;
    }).filter((item): item is [string, AttachmentContextItem] => item !== null),
  );

  effectiveFileIds.forEach((fileId) => {
    const existingContext = currentContextMap.get(fileId) ?? newContextMap.get(fileId);
    if (existingContext) {
      nextContexts.push(existingContext);
    }
  });

  return nextContexts;
};

const buildHistoryPayload = (chatMessages: ChatMessage[]) =>
  chatMessages.map((item) => ({
    id: item.id,
    message: item.content,
  }));

const stripCardPayload = (content: string) => {
  let stripped = content.replace(/\[CARD\][\s\S]*?\[\/CARD\]/g, '').trim();
  stripped = stripped.replace(/```json\s*(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*```/gi, '').trim();
  stripped = stripped.replace(/(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*$/gi, '').trim();
  return stripped;
};

const buildConsultationHistory = (chatMessages: ChatMessage[]): ConsultationChatTurn[] =>
  chatMessages
    .map((item) => ({
      role: item.role === 'ai' ? 'assistant' : 'user',
      content: stripCardPayload(item.content),
    }))
    .filter((item): item is ConsultationChatTurn => Boolean(item.content));

const buildPersistedMessages = (chatMessages: ChatMessage[]): ChatSessionMessage[] =>
  chatMessages
    .filter((item) => Boolean(item.content.trim()))
    .map((item) => ({
      id: item.id,
      role: item.role,
      content: item.content,
      reasoning: item.reasoning,
      status: item.status,
      contextFileIds: item.contextFileIds,
      aiLabelMeta: item.aiLabelMeta,
    }));

const buildMessagesSignature = (
  chatMessages: ChatSessionMessage[],
  mode: 'normal' | 'medical',
  sessionId: number | null,
) => JSON.stringify({
  sessionId,
  mode,
  messages: chatMessages,
});

const senderHeader = (activeContextHeader: React.ReactNode, attachmentHeader: React.ReactNode) => {
  if (!activeContextHeader && !attachmentHeader) {
    return null;
  }

  return (
    <div className="space-y-2">
      {activeContextHeader}
      {attachmentHeader}
    </div>
  );
};

const ChatContainer: React.FC<ChatContainerProps> = ({
  mode,
  token,
  activeSessionId,
  initialMessages = [],
  conversationKey,
  consultationProfileId,
  consultationProfileName,
  onModeChange,
  onRecordsChange,
  onSessionPersisted,
}) => {
  const { message: messageApi } = App.useApp();
  const navigate = useNavigate();
  const chatRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const messageViewportRef = useRef<HTMLDivElement>(null);
  const isHydratingHistoryRef = useRef(false);
  const lastPersistedSignatureRef = useRef('');
  const lastHydratedConversationKeyRef = useRef(conversationKey ?? 'default');
  const screens = Grid.useBreakpoint();
  const isMobile = !screens.sm;
  const [inputValue, setInputValue] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [currentSessionId, setCurrentSessionId] = useState<number | null>(activeSessionId ?? null);
  const [isRequesting, setIsRequesting] = useState(false);
  const isRequestingRef = useRef(false);
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([]);
  const [activeAttachmentContexts, setActiveAttachmentContexts] = useState<AttachmentContextItem[]>([]);
  const [isThinking, setIsThinking] = useState(false);
  const [savingMessageId, setSavingMessageId] = useState<string | null>(null);
  const [savedMessageIds, setSavedMessageIds] = useState<string[]>([]);
  const [starterPrompts, setStarterPrompts] = useState<{ category: string; question: string; answer: string }[]>(STARTER_PROMPTS);
  const [feedbackTarget, setFeedbackTarget] = useState<ChatMessage | null>(null);
  const [feedbackText, setFeedbackText] = useState('');
  const [feedbackSubmitting, setFeedbackSubmitting] = useState(false);

  useEffect(() => {
    fetchPublishedQuestions()
      .then((questions) => {
        if (questions && questions.length > 0) {
          setStarterPrompts(questions.map(q => ({
            category: q.category || '常见问题',
            question: q.question,
            answer: q.answer_template,
          })));
        }
      })
      .catch(console.error);
  }, []);

  // 选中 AI 回复文字后复制（Ctrl+C / 右键复制）时，自动追加 AI 生成标识尾巴
  useEffect(() => {
    const handleNativeCopy = (event: ClipboardEvent) => {
      if (!event.clipboardData) {
        return;
      }
      const selection = window.getSelection();
      if (!selection || selection.isCollapsed || selection.rangeCount === 0) {
        return;
      }
      const anchorNode = selection.anchorNode;
      if (!anchorNode) {
        return;
      }
      const anchorElement = anchorNode.nodeType === Node.ELEMENT_NODE
        ? (anchorNode as Element)
        : anchorNode.parentElement;
      // 仅当选区起始于 AI 消息内容区域内才追加标识
      if (!anchorElement?.closest('[data-ai-content="true"]')) {
        return;
      }
      const selectedText = selection.toString();
      if (!selectedText.trim()) {
        return;
      }
      // 已带标识（例如消息末尾的显式水印）则不重复追加
      if (selectedText.trimEnd().endsWith(AI_COPY_SUFFIX)) {
        return;
      }
      event.clipboardData.setData('text/plain', `${selectedText}\n\n${AI_COPY_SUFFIX}`);
      event.preventDefault();
    };

    document.addEventListener('copy', handleNativeCopy);
    return () => document.removeEventListener('copy', handleNativeCopy);
  }, []);

  // Animate on mode change
  useEffect(() => {
    if (chatRef.current) {
      const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      gsap.fromTo(
        chatRef.current.querySelectorAll('[data-chat-stage]'),
        { opacity: 0, y: reduceMotion ? 0 : 12 },
        {
          opacity: 1,
          y: 0,
          duration: reduceMotion ? 0.1 : 0.45,
          ease: 'power4.out',
          stagger: reduceMotion ? 0 : 0.05,
        },
      );
    }
  }, [mode, messages.length]);

  useEffect(() => {
    if (!messageViewportRef.current) {
      return;
    }

    messageViewportRef.current.scrollTo({
      top: messageViewportRef.current.scrollHeight,
      behavior: 'smooth',
    });
  }, [messages]);

  useEffect(() => {
    const nextConversationKey = conversationKey ?? 'default';
    if (lastHydratedConversationKeyRef.current === nextConversationKey && activeSessionId === currentSessionId) {
      return;
    }

    lastHydratedConversationKeyRef.current = nextConversationKey;
    isHydratingHistoryRef.current = true;
    const hydratedMessages: ChatMessage[] = initialMessages.map((item) => ({
      ...item,
      loading: false,
    }));
    setCurrentSessionId(activeSessionId ?? null);
    setMessages(hydratedMessages);
    setInputValue('');
    setPendingAttachments([]);
    setActiveAttachmentContexts([]);
    setIsThinking(false);
    setSavingMessageId(null);
    setSavedMessageIds([]);
    lastPersistedSignatureRef.current = buildMessagesSignature(
      buildPersistedMessages(hydratedMessages),
      mode,
      activeSessionId ?? null,
    );
    isHydratingHistoryRef.current = false;
  }, [activeSessionId, conversationKey, currentSessionId, initialMessages, mode]);

  useEffect(() => {
    if (!token || isRequesting || isHydratingHistoryRef.current || !messages.length) {
      return;
    }

    const persistedMessages = buildPersistedMessages(messages);
    if (!persistedMessages.length) {
      return;
    }

    const nextSignature = buildMessagesSignature(persistedMessages, mode, currentSessionId);
    if (nextSignature === lastPersistedSignatureRef.current) {
      return;
    }

    let isCancelled = false;

    const persistConversation = async () => {
      try {
        const savedSession = await saveChatSession(token, mode, persistedMessages, currentSessionId);
        if (isCancelled) {
          return;
        }

        setCurrentSessionId(savedSession.id);
        lastPersistedSignatureRef.current = buildMessagesSignature(persistedMessages, mode, savedSession.id);
        onSessionPersisted?.(savedSession);
      } catch {
        if (!isCancelled) {
          messageApi.error('保存对话历史失败，请稍后重试');
        }
      }
    };

    void persistConversation();

    return () => {
      isCancelled = true;
    };
  }, [currentSessionId, messageApi, messages, mode, onSessionPersisted, token, isRequesting]);

  const appendAttachments = (files: FileList | File[]) => {
    const incomingFiles = Array.from(files);
    
    // Validate first
    const newAttachments: PendingAttachment[] = [];
    const existingKeys = new Set(
      pendingAttachments.map((item) => `${item.file.name}_${item.file.size}_${item.file.lastModified}`),
    );

    for (const file of incomingFiles) {
      const kind = getAttachmentKind(file);
      const fileKey = `${file.name}_${file.size}_${file.lastModified}`;

      if (!kind || existingKeys.has(fileKey) || pendingAttachments.length + newAttachments.length >= MAX_ATTACHMENTS) {
        continue;
      }

      newAttachments.push({
        id: `${fileKey}_${Date.now()}`,
        file,
        kind,
        status: 'pending',
      });
      existingKeys.add(fileKey);
    }

    if (newAttachments.length === 0) return;

    // Keep the File object locally until send so image bytes can be passed to
    // the vision model in the same request as the user's question.
    setPendingAttachments((current) => [...current, ...newAttachments]);
  };

  const removeAttachment = (attachmentId: string) => {
    setPendingAttachments((currentAttachments) =>
      currentAttachments.filter((item) => item.id !== attachmentId),
    );
  };

  const removeActiveContextAttachment = (contextFileId: string) => {
    setActiveAttachmentContexts((currentContexts) =>
      currentContexts.filter((item) => item.fileId !== contextFileId),
    );
  };

  const attachmentHeader = pendingAttachments.length ? (
    <div className="scrollbar-hidden flex max-w-full gap-2 overflow-x-auto pb-1">
      {pendingAttachments.map((attachment) => (
        <div
          key={attachment.id}
          className={`flex min-w-[156px] max-w-[220px] shrink-0 items-center gap-2 rounded-2xl border bg-background/88 px-3 py-2 shadow-sm sm:min-w-[180px] sm:max-w-[240px] ${
            attachment.status === 'error' ? 'border-red-200 bg-red-50/50' : 'border-border/70'
          }`}
        >
          <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-foreground sm:h-9 sm:w-9 ${
            attachment.status === 'uploading' ? 'bg-indigo-50 text-indigo-500 animate-pulse' :
            attachment.status === 'error' ? 'bg-red-100 text-red-500' :
            'bg-muted/70'
          }`}>
            {attachment.kind === 'image' ? <FileImageOutlined /> : <FilePdfOutlined />}
          </div>
          <div className="min-w-0 flex-1">
            <div className="truncate text-[13px] font-medium text-foreground sm:text-sm">{attachment.file.name}</div>
            <div className="text-xs flex items-center gap-1">
              <span className="text-muted-foreground">{formatFileSize(attachment.file.size)}</span>
              {attachment.status === 'uploading' && <span className="text-indigo-500">上传中...</span>}
              {attachment.status === 'error' && <span className="text-red-500">上传失败</span>}
              {attachment.status === 'success' && <span className="text-emerald-500">已上传</span>}
            </div>
          </div>
          <button
            type="button"
            onClick={() => removeAttachment(attachment.id)}
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-muted/50"
            aria-label={`移除 ${attachment.file.name}`}
          >
            <DeleteOutlined />
          </button>
        </div>
      ))}
    </div>
  ) : null;

  const activeContextHeader = activeAttachmentContexts.length ? (
    <div className="space-y-1.5 pb-1">
      <div className="px-1 text-[11px] font-medium text-muted-foreground sm:text-xs">当前报告上下文</div>
      <div className="scrollbar-hidden flex max-w-full gap-2 overflow-x-auto">
        {activeAttachmentContexts.map((attachment) => (
          <div
            key={attachment.fileId}
            className="flex min-w-[156px] max-w-[220px] shrink-0 items-center gap-2 rounded-2xl border border-border/70 bg-background/88 px-3 py-2 shadow-sm sm:min-w-[180px] sm:max-w-[240px]"
          >
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted/70 text-foreground sm:h-9 sm:w-9">
              {attachment.kind === 'image' ? <FileImageOutlined /> : <FilePdfOutlined />}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-medium text-foreground sm:text-sm">{attachment.name}</div>
              <div className="text-xs text-muted-foreground">{formatFileSize(attachment.size)}</div>
            </div>
            <button
              type="button"
              onClick={() => removeActiveContextAttachment(attachment.fileId)}
              className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-muted-foreground"
              aria-label={`移除上下文资料 ${attachment.name}`}
            >
              <DeleteOutlined />
            </button>
          </div>
        ))}
      </div>
    </div>
  ) : null;

  const requestAssistantReply = async (
    assistantMessageId: string,
    messageContent: string,
    history: { id: string; message: string }[],
    attachments: PendingAttachment[] = [],
    contextFileIds: string[] = [],
  ) => {
    if (isRequestingRef.current) {
      return;
    }
    isRequestingRef.current = true;
    setIsRequesting(true);

    try {
      const currentContextFileIds = [...contextFileIds];
      const currentAttachments = [...attachments];

      for await (const chunk of fetchChatStream(
        mode,
        messageContent,
        history,
        token,
        isThinking,
        currentAttachments.map((item) => item.file),
        currentContextFileIds,
        consultationProfileId ?? undefined,
      )) {
        if (chunk.type === 'context') {
          setActiveAttachmentContexts((currentContexts) =>
            mergeAttachmentContexts(
              currentContexts,
              attachments.filter((attachment) => attachment.kind === 'pdf'),
              chunk.fileIds ?? currentContextFileIds,
              chunk.newFileIds ?? [],
            ),
          );
          setMessages((currentMessages) =>
            currentMessages.map((item) =>
              item.id === assistantMessageId
                ? {
                  ...item,
                  contextFileIds: chunk.fileIds ?? currentContextFileIds,
                }
                : item,
            ),
          );
          continue;
        }

        if (chunk.type === 'safety' || chunk.type === 'notice') {
          setMessages((currentMessages) => currentMessages.map((item) => item.id === assistantMessageId
            ? { ...item, safety: chunk.type === 'safety' ? chunk : item.safety, notice: chunk.type === 'notice' ? chunk.text : item.notice }
            : item));
          continue;
        }

        setMessages((currentMessages) =>
          currentMessages.map((item) =>
            item.id === assistantMessageId
              ? updateAssistantMessage(item, chunk)
              : item,
          ),
        );
      }

      setMessages((currentMessages) =>
        currentMessages.map((item) =>
          item.id === assistantMessageId
            ? {
              ...item,
              status: 'success',
              loading: false,
            }
            : item,
        ),
      );
    } catch {
      setMessages((currentMessages) =>
        currentMessages.map((item) =>
          item.id === assistantMessageId
            ? {
              ...item,
              content: item.content || '抱歉，回复生成失败，请稍后再试。',
              status: 'error',
              loading: false,
            }
            : item,
        ),
      );
    } finally {
      isRequestingRef.current = false;
      setIsRequesting(false);
    }
  };

  const handleCopyMessage = async (content: string) => {
    const text = stripCardPayload(content);
    const copyText = text.endsWith(AI_COPY_SUFFIX) ? text : `${text}\n\n${AI_COPY_SUFFIX}`;

    if (!text) {
      messageApi.info('当前回复暂无可复制内容');
      return;
    }

    try {
      await navigator.clipboard.writeText(copyText);
      messageApi.success('已复制回复内容');
    } catch {
      messageApi.error('复制失败，请稍后重试');
    }
  };

  const handleSubmitFeedback = async () => {
    if (!feedbackTarget || !token || !feedbackText.trim()) {
      messageApi.warning('请输入反馈内容');
      return;
    }
    const index = messages.findIndex((item) => item.id === feedbackTarget.id);
    const previous = index > 0 ? messages[index - 1] : undefined;
    setFeedbackSubmitting(true);
    try {
      await submitAiFeedback(token, {
        content: feedbackText.trim(),
        question: previous?.role === 'user' ? stripCardPayload(previous.content) : '',
        ai_response: stripCardPayload(feedbackTarget.content),
        session_id: currentSessionId,
        message_id: feedbackTarget.id,
      });
      messageApi.success('感谢您的反馈');
      setFeedbackTarget(null);
      setFeedbackText('');
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : '反馈提交失败');
    } finally {
      setFeedbackSubmitting(false);
    }
  };

  const handleRetryMessage = async (assistantMessageId: string) => {
    if (isRequestingRef.current) {
      messageApi.info('当前正在生成回复，请稍后再试');
      return;
    }

    const latestAssistantMessage = [...messages].reverse().find((item) => item.role === 'ai');

    if (latestAssistantMessage?.id !== assistantMessageId) {
      messageApi.info('暂时仅支持刷新最后一条 AI 回复');
      return;
    }

    const assistantIndex = messages.findIndex((item) => item.id === assistantMessageId);

    if (assistantIndex < 0) {
      return;
    }

    const userIndex = messages.slice(0, assistantIndex).findLastIndex((item) => item.role === 'user');

    if (userIndex < 0) {
      return;
    }

    const userMessage = messages[userIndex];
    const history = buildHistoryPayload(messages.slice(0, userIndex));
    const retryContextFileIds = latestAssistantMessage?.contextFileIds ?? userMessage.contextFileIds ?? [];

    setMessages((currentMessages) =>
      currentMessages.map((item) =>
        item.id === assistantMessageId
          ? {
            ...item,
            content: '',
            reasoning: '',
            status: 'loading',
            loading: true,
          }
          : item,
      ),
    );
    setSavedMessageIds((currentIds) => currentIds.filter((item) => item !== assistantMessageId));

    // For retry, we don't want to re-upload files, we just pass the contextFileIds that already contain the uploaded file IDs
    await requestAssistantReply(
      assistantMessageId,
      userMessage.content,
      history,
      [],
      retryContextFileIds,
    );
  };

  const handleSubmit = async (msg: string) => {
    if (!token) {
      navigate('/login');
      return;
    }

    if (pendingAttachments.some(a => a.status === 'uploading')) {
      messageApi.warning('附件正在上传中，请稍后发送');
      return;
    }

    const hasErrorAttachments = pendingAttachments.some(a => a.status === 'error');
    if (hasErrorAttachments) {
      messageApi.error('存在上传失败的附件，请移除或重新上传后再发送');
      return;
    }

    const trimmedMessage = msg.trim();
    const attachmentSnapshot = pendingAttachments.map((item) => ({ ...item }));
    // If the attachment has a fileId from the pre-upload, add it to contextFileIds
    const uploadedFileIds = attachmentSnapshot.map(a => a.fileId).filter((id): id is string => Boolean(id));
    const contextFileIds = [...activeAttachmentContexts.map((item) => item.fileId), ...uploadedFileIds];
    
    const messageContent = attachmentSnapshot.length
      ? buildMessageContent(trimmedMessage)
      : buildContextDisplayContent(trimmedMessage);

    if ((!trimmedMessage && pendingAttachments.length === 0 && contextFileIds.length === 0) || isRequestingRef.current) {
      return;
    }

    const timestamp = Date.now();
    const userMessage: ChatMessage = {
      id: `user_${timestamp}`,
      role: 'user',
      content: messageContent,
      attachments: attachmentSnapshot,
      contextFileIds,
      status: 'local',
    };
    const assistantMessageId = `ai_${timestamp}`;

    const history = buildHistoryPayload(messages);

    setMessages((currentMessages) => [
      ...currentMessages,
      userMessage,
      {
        id: assistantMessageId,
        role: 'ai',
        content: '',
        reasoning: '',
        status: 'loading',
        loading: true,
      },
    ]);
    setInputValue('');
    setPendingAttachments([]);

    // Update active context with newly uploaded files so they show in "当前报告上下文"
    if (attachmentSnapshot.length > 0) {
      setActiveAttachmentContexts((current) => [
        ...current,
        ...attachmentSnapshot
          .filter((a) => a.fileId)
          .map((a) => ({
            id: a.id,
            fileId: a.fileId as string,
            name: a.file.name,
            kind: a.kind,
            size: a.file.size,
          })),
      ]);
    }

    await requestAssistantReply(assistantMessageId, messageContent, history, attachmentSnapshot, contextFileIds);
  };

  const handlePromptClick = (prompt: string) => {
    if (!token) {
      navigate('/login');
      return;
    }
    setInputValue(prompt);
  };

  const handleStarterPromptClick = (starterPrompt: { category: string; question: string; answer: string }) => {
    if (!token) {
      navigate('/login');
      return;
    }
    if (isRequestingRef.current) {
      messageApi.info('当前正在生成回复，请稍后再试');
      return;
    }

    const timestamp = Date.now();
    const userMessage: ChatMessage = {
      id: `user_${timestamp}`,
      role: 'user',
      content: starterPrompt.question,
      status: 'local',
    };
    const assistantMessage: ChatMessage = {
      id: `ai_${timestamp}`,
      role: 'ai',
      content: starterPrompt.answer,
      status: 'success',
      loading: false,
    };

    setMessages((currentMessages) => [...currentMessages, userMessage, assistantMessage]);
    setInputValue('');
    setPendingAttachments([]);
    setActiveAttachmentContexts([]);
    setIsThinking(false);
  };

  const handleSendClick = () => {
    void handleSubmit(inputValue);
  };

  const handleCardAction = async (messageId: string, actionName: string, cardData: any) => {
    if (actionName === 'fill_input') {
      const optionData = cardData as { optionText: string };
      setInputValue(optionData.optionText);
      return;
    }

    if (actionName === 'finish_consultation') {
      messageApi.success('本次问诊已完成，后续问答会自动参考已保存的健康记录');
      return;
    }

    if (actionName !== 'save_consultation_record') {
      return;
    }

    if (!token) {
      messageApi.info('请先登录后再保存个人问诊记录');
      return;
    }

    if (mode === 'medical' && !consultationProfileId) {
      messageApi.info('请先选择当前咨询人，再保存问诊记录');
      return;
    }

    if (savingMessageId === messageId || savedMessageIds.includes(messageId)) {
      return;
    }

    const assistantIndex = messages.findIndex((item) => item.id === messageId);
    if (assistantIndex < 0) {
      messageApi.error('未找到对应的问诊结果，暂时无法保存');
      return;
    }

    const currentMessage = messages[assistantIndex];
    // 检查此记录是否是从历史记录恢复的 (ID 通常为数字而非新生成的带有前缀的临时ID)
    // 或者是已存在的非临时消息，如果是从历史中点击则阻止重复保存。
    if (currentMessage.id && !currentMessage.id.toString().startsWith('ai_')) {
      setSavedMessageIds((currentIds) => [...new Set([...currentIds, messageId])]);
      messageApi.info('该问诊记录已保存过');
      return;
    }

    const consultationHistory = buildConsultationHistory(messages.slice(0, assistantIndex + 1));

    try {
      setSavingMessageId(messageId);
      await saveConsultationRecord(token, cardData as ConsultationCardData, consultationHistory, consultationProfileId ?? undefined);
      setSavedMessageIds((currentIds) => [...new Set([...currentIds, messageId])]);
      messageApi.success(
        consultationProfileName
          ? `已保存到${consultationProfileName}的个人问诊记录`
          : '已保存到个人问诊记录，后续问答会自动参考这些病例信息',
      );
      await onRecordsChange?.();
    } catch (error: unknown) {
      const errorMessage = error instanceof Error && error.message ? error.message : '保存问诊记录失败';
      messageApi.error(errorMessage);
    } finally {
      setSavingMessageId((currentId) => (currentId === messageId ? null : currentId));
    }
  };

  const latestAssistantMessageId = [...messages].reverse().find((item) => item.role === 'ai')?.id;

  const items: BubbleItemType[] = messages.map((chatMessage) => {
    const canRetry = chatMessage.role === 'ai' && chatMessage.id === latestAssistantMessageId;
    const copyText = stripCardPayload(chatMessage.content);
    const footerItems = chatMessage.role === 'ai'
          ? [
        ...(copyText
          ? [{
            key: 'copy',
            icon: <CopyOutlined />,
            label: '复制',
            onItemClick: () => {
              void handleCopyMessage(chatMessage.content);
            },
          }]
          : []),
        ...(copyText
          ? [{
            key: 'feedback',
            icon: <MessageOutlined />,
            label: '反馈',
            onItemClick: () => {
              setFeedbackTarget(chatMessage);
              setFeedbackText('');
            },
          }]
          : []),
        ...(canRetry
          ? [{
            key: 'retry',
            icon: <RedoOutlined />,
            label: '刷新',
            onItemClick: () => {
              void handleRetryMessage(chatMessage.id);
            },
          }]
          : []),
      ]
      : [];

    return {
      key: chatMessage.id,
      role: chatMessage.role,
      status: chatMessage.status,
      loading: chatMessage.loading,
      header: chatMessage.role === 'user' && chatMessage.attachments && chatMessage.attachments.length > 0 ? (
        <div className="mb-2 flex flex-col gap-2">
          {chatMessage.attachments.map(a => (
            <AttachmentThumbnail
              key={a.id}
              attachment={a}
            />
          ))}
        </div>
      ) : undefined,
      content: (
        <div data-ai-content={chatMessage.role === 'ai' ? 'true' : undefined}>
          <MessageRender
            content={chatMessage.content}
            safety={chatMessage.safety}
            notice={chatMessage.notice}
            reasoning={chatMessage.reasoning}
            role={chatMessage.role}
            status={chatMessage.status}
            saveState={
              savingMessageId === chatMessage.id
                ? 'saving'
                : savedMessageIds.includes(chatMessage.id)
                  ? 'saved'
                  : 'idle'
            }
            onCardAction={(actionName, cardData) => {
              void handleCardAction(chatMessage.id, actionName, cardData);
            }}
          />
        </div>
      ),
      footerPlacement: 'outer-start',
      footer: footerItems.length ? (
        <Actions
          items={footerItems}
          variant="borderless"
          classNames={{
            root: 'gap-2',
            item: 'rounded-full border border-white/70 bg-white/78 px-3 py-1 text-xs text-muted-foreground shadow-sm backdrop-blur-sm transition-colors hover:bg-white hover:text-foreground',
          }}
        />
      ) : null,
    };
  });

  const renderDesktopEmptyState = () => (
    <div className="hidden h-full items-center justify-center px-10 lg:flex" data-chat-stage>
      <div className="grid w-full max-w-5xl grid-cols-[320px_minmax(0,1fr)] items-center gap-12">
        <div className="relative flex justify-center">
          <div className="absolute inset-x-10 inset-y-16 rounded-full bg-[radial-gradient(circle,rgba(129,140,248,0.28),transparent_68%)] blur-3xl" />
          <div className="relative flex h-72 w-72 items-center justify-center rounded-[72px] border border-white/60 bg-[linear-gradient(180deg,rgba(255,255,255,0.92),rgba(237,240,255,0.72))] shadow-[0_32px_90px_rgba(129,140,248,0.18)]">
            <img src={heroImage} alt="三十天时刻智护智能助手" className="w-56 max-w-full drop-shadow-[0_24px_45px_rgba(129,140,248,0.28)]" />
          </div>
        </div>
        <div className="space-y-6">
          <div className="inline-flex items-center rounded-full border border-white/70 bg-white/75 px-4 py-2 text-sm font-medium text-indigo-600 shadow-sm">
            {mode === 'normal' ? '健康问答' : 'AI导诊'}
          </div>
          <div>
            <div className="text-5xl font-semibold leading-[1.1] tracking-tight text-foreground">
              我是时小安
              <br />
              <span className="bg-[linear-gradient(135deg,#4f46e5,#7c3aed)] bg-clip-text text-transparent">
                你的 AI 健康助手
              </span>
            </div>
            <div className="mt-4 max-w-2xl text-base leading-7 text-muted-foreground">
              医学问题、解读报告、检索文献、用药常识，都来问我吧。你也可以上传图片或 PDF 检查报告，让我帮你整理重点。
            </div>
          </div>
          <div className="flex flex-wrap gap-3">
            {SHORTCUTS.map((item) => (
              <button
                key={item.label}
                type="button"
                onClick={() => {
                  if (!token) {
                    navigate('/login');
                    return;
                  }
                  if (item.label === 'AI导诊') {
                    onModeChange?.('medical');
                    handlePromptClick(item.prompt);
                  } else if (item.label === '深度思考') {
                    setIsThinking(!isThinking);
                  } else {
                    handlePromptClick(item.prompt);
                  }
                }}
                className={`flex items-center gap-2 rounded-full border px-4 py-2 text-sm font-medium shadow-sm transition-colors ${
                  item.label === '深度思考' && isThinking
                    ? 'border-indigo-200 bg-indigo-50 text-indigo-700'
                    : 'border-white/70 bg-white/72 text-foreground hover:bg-white'
                }`}
              >
                <span className={`flex h-6 w-6 items-center justify-center rounded-full text-[12px] ${
                  item.label === '深度思考' && isThinking
                    ? 'bg-indigo-200 text-indigo-700'
                    : 'bg-indigo-100 text-indigo-600'
                }`}>
                  {item.icon}
                </span>
                {item.label}
              </button>
            ))}
          </div>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {starterPrompts.slice(0, 6).map((item, index) => (
              <div
                key={index}
                className="group relative flex cursor-pointer flex-col gap-2 rounded-2xl border border-white/60 bg-white/50 p-4 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:border-indigo-200 hover:bg-white hover:shadow-md"
                onClick={() => handleStarterPromptClick(item)}
              >
                <div className="flex items-center gap-2">
                  <span className="flex items-center rounded-md bg-indigo-50 px-2 py-1 text-[11px] font-medium text-indigo-600 transition-colors group-hover:bg-indigo-100">
                    {item.category}
                  </span>
                </div>
                <div className="text-sm font-medium leading-relaxed text-foreground/90 transition-colors group-hover:text-indigo-900">
                  {item.question}
                </div>
                <div className="absolute bottom-4 right-4 flex h-6 w-6 items-center justify-center rounded-full bg-white text-indigo-300 opacity-0 shadow-sm transition-all duration-300 group-hover:opacity-100 group-hover:text-indigo-500">
                  <ArrowRightOutlined className="text-xs" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  const renderMobileEmptyState = () => (
    <div className="space-y-4 px-1 pb-4 pt-2 lg:hidden" data-chat-stage>
      <div className="relative overflow-hidden rounded-[32px] border border-white/65 bg-[linear-gradient(180deg,rgba(255,255,255,0.88),rgba(238,240,255,0.72))] p-5 shadow-[0_24px_60px_rgba(148,163,184,0.16)]">
        <div className="absolute -right-6 bottom-0 h-36 w-36 rounded-full bg-[radial-gradient(circle,rgba(129,140,248,0.22),transparent_70%)] blur-2xl" />
        <div className="relative flex items-start justify-between gap-4">
          <div className="max-w-[62%]">
            <div className="text-sm font-medium text-muted-foreground">你好 ✨</div>
            <div className="mt-2 text-3xl font-semibold leading-tight tracking-tight text-indigo-700">
              愿你岁月静好无忧
            </div>
            <button
              type="button"
              onClick={() => {
                if (!token) {
                  navigate('/login');
                  return;
                }
                handlePromptClick(mode === 'normal' ? '帮我做一次全面的健康问题咨询' : '请开始医疗问诊');
              }}
              className="mt-4 inline-flex items-center rounded-full border border-white/60 bg-white/80 px-4 py-2 text-sm font-medium text-foreground shadow-sm"
            >
              {mode === 'normal' ? '开始咨询' : '继续问诊'}
            </button>
          </div>
          <div className="relative flex h-36 w-32 shrink-0 items-end justify-center">
            <div className="absolute inset-2 rounded-full bg-[radial-gradient(circle,rgba(129,140,248,0.18),transparent_68%)] blur-2xl" />
            <img src={heroImage} alt="三十天时刻智护" className="relative h-32 w-28 object-contain drop-shadow-[0_18px_30px_rgba(129,140,248,0.24)]" />
          </div>
        </div>
      </div>

      <div className="rounded-[28px] border border-white/65 bg-white/72 p-4 shadow-[0_20px_50px_rgba(148,163,184,0.14)]">
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 text-base font-semibold text-foreground">
              <span className="h-4 w-1 rounded-full bg-indigo-500" />
              我的健康
            </div>
            <div className="mt-1 text-xs text-muted-foreground">更新于今日 · 三十天时刻智护持续为你整理重点</div>
          </div>
          <button
            type="button"
            onClick={() => {
              if (!token) {
                navigate('/login');
                return;
              }
              handlePromptClick('帮我生成一份最新健康档案摘要');
            }}
            className="rounded-full bg-indigo-100 px-3 py-1.5 text-xs font-medium text-indigo-700"
          >
            查看详情
          </button>
        </div>
        <div className="mt-4 grid grid-cols-2 divide-x divide-border/60 rounded-[24px] bg-background/80">
          {HEALTH_SNAPSHOT.map((item) => (
            <div key={item.label} className="px-4 py-3">
              <div className="text-2xl font-semibold text-foreground">{item.value}</div>
              <div className="mt-1 text-sm text-muted-foreground">{item.label}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="space-y-3">
        {MOBILE_FEED_CARDS.map((card, index) => (
            <button
              key={card.title}
              type="button"
              onClick={() => {
                if (!token) {
                  navigate('/login');
                  return;
                }
                handlePromptClick(card.prompt);
              }}
              className={`flex w-full items-center justify-between gap-4 rounded-[26px] border p-4 text-left shadow-[0_18px_40px_rgba(148,163,184,0.12)] ${index === 0
                ? 'border-emerald-100 bg-[linear-gradient(135deg,rgba(240,253,250,0.96),rgba(255,255,255,0.92))]'
                : 'border-white/70 bg-white/76'
              }`}
          >
            <div className="min-w-0">
              <div className="text-lg font-semibold leading-8 text-foreground">{card.title}</div>
              <div className="mt-1 text-sm text-muted-foreground">{card.description}</div>
            </div>
            <div className="flex shrink-0 items-center gap-2 rounded-full bg-white/85 px-3 py-2 text-sm font-medium text-foreground">
              {card.action}
              <ArrowRightOutlined />
            </div>
          </button>
        ))}
      </div>
    </div>
  );

  return (
    <>
      <div className="mx-auto flex h-full min-h-0 w-full max-w-[1280px] flex-col gap-3 overflow-hidden px-3 pb-3 sm:px-4 lg:px-0 lg:pb-0" ref={chatRef}>
      <div
        className="rounded-2xl border border-amber-200/60 bg-amber-50/80 px-4 py-2 text-center text-xs text-amber-700 shadow-sm backdrop-blur-sm lg:mx-4"
        data-chat-stage
      >
        免责声明：本平台的分析结果由AI生成，仅供参考，不能替代专业诊断。具体请以医生面诊为准，如有不适请及时线下就医。
      </div>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*,.pdf,application/pdf"
        multiple
        className="hidden"
        onChange={(event) => {
          if (event.target.files?.length) {
            appendAttachments(event.target.files);
          }
          event.target.value = '';
        }}
      />

      <div
        className="relative min-h-0 flex-1 overflow-hidden rounded-[32px]"
        data-chat-stage
      >
        <div className="pointer-events-none absolute inset-x-8 top-0 h-24 bg-[radial-gradient(circle_at_top,rgba(129,140,248,0.16),transparent_72%)]" />
        <div ref={messageViewportRef} className="w-full scrollbar-hidden relative z-10 h-full overflow-y-auto px-0 pb-6 pt-3 sm:px-3 lg:px-5 lg:pb-8 lg:pt-5">
          {messages.length === 0 ? (
            <div className="flex h-full flex-col justify-start lg:justify-center">
              {renderDesktopEmptyState()}
              {renderMobileEmptyState()}
            </div>
          ) : null}
          {messages.length > 0 ? (
            <Bubble.List
              items={items}
              classNames={{
                root: 'space-y-3 sm:space-y-5',
              }}
              role={{
                user: {
                  placement: 'end',
                  avatar: isMobile ? undefined : <Avatar className="h-10 w-10 bg-foreground text-sm text-background shadow-sm">我</Avatar>,
                  variant: 'filled',
                  rootClassName: isMobile ? 'w-full max-w-none gap-0' : 'w-full max-w-none gap-3',
                  classNames: {
                    body: isMobile ? 'max-w-[min(94vw,640px)]' : 'max-w-[min(84vw,560px)]',
                    content: 'rounded-[24px] px-[18px] py-3 text-[14px] leading-6 sm:rounded-[26px] sm:px-5 sm:py-4 sm:text-[15px] sm:leading-7',
                  },
                },
                ai: {
                  placement: 'start',
                  avatar: isMobile ? undefined : (
                    <Avatar className="h-10 w-10 bg-[linear-gradient(135deg,rgba(99,102,241,0.95),rgba(168,85,247,0.85))] text-sm text-white shadow-[0_10px_20px_rgba(99,102,241,0.18)]">
                      安
                    </Avatar>
                  ),
                  variant: 'shadow',
                  rootClassName: isMobile ? 'w-full max-w-none items-start gap-0 !pe-0' : 'w-full max-w-none items-start gap-3 !pe-0',
                  classNames: {
                    body: isMobile ? 'max-w-[min(94vw,640px)]' : 'max-w-[min(84vw,720px)]',
                    content: 'rounded-[26px] border border-white/70 bg-white/78 px-[18px] py-3 text-[14px] leading-6 shadow-[0_16px_34px_rgba(148,163,184,0.10)] backdrop-blur-xl sm:rounded-[30px] sm:px-5 sm:py-4 sm:text-[15px] sm:leading-7 sm:shadow-[0_18px_40px_rgba(148,163,184,0.12)]',
                  },
                },
              }}
            />
          ) : null}
        </div>
      </div>

      <div className="shrink-0 space-y-2 px-1 pb-[max(env(safe-area-inset-bottom),12px)] sm:space-y-3 sm:px-2 lg:px-4" data-chat-stage>
        <div className="scrollbar-hidden hidden gap-2 overflow-x-auto pb-1 lg:flex">
          {SHORTCUTS.map((item) => (
            <button
              key={item.label}
              type="button"
              onClick={() => {
                if (!token) {
                  navigate('/login');
                  return;
                }
                if (item.label === 'AI导诊') {
                  onModeChange?.('medical');
                  handlePromptClick(item.prompt);
                } else if (item.label === '深度思考') {
                  setIsThinking(!isThinking);
                } else {
                  handlePromptClick(item.prompt);
                }
              }}
              className={`flex shrink-0 items-center gap-2 rounded-full border px-4 py-2 text-sm font-medium shadow-sm transition-colors ${
                item.label === '深度思考' && isThinking
                  ? 'border-indigo-200 bg-indigo-50 text-indigo-700'
                  : 'border-white/70 bg-white/76 text-foreground hover:bg-white'
              }`}
            >
              <span className={`flex h-6 w-6 items-center justify-center rounded-full text-[12px] ${
                item.label === '深度思考' && isThinking
                  ? 'bg-indigo-200 text-indigo-700'
                  : 'bg-indigo-100 text-indigo-600'
              }`}>
                {item.icon}
              </span>
              {item.label}
            </button>
          ))}
        </div>

        <div className="scrollbar-hidden flex gap-2 overflow-x-auto px-0.5 pb-1 lg:hidden">
          {SHORTCUTS.map((item) => (
            <button
              key={item.label}
              type="button"
              onClick={() => {
                if (!token) {
                  navigate('/login');
                  return;
                }
                if (item.label === 'AI导诊') {
                  onModeChange?.('medical');
                  handlePromptClick(item.prompt);
                } else if (item.label === '深度思考') {
                  setIsThinking(!isThinking);
                } else {
                  handlePromptClick(item.prompt);
                }
              }}
              className={`flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-2 text-[13px] font-medium shadow-[0_10px_24px_rgba(148,163,184,0.12)] backdrop-blur-sm transition-colors ${
                item.label === '深度思考' && isThinking
                  ? 'border-indigo-200 bg-indigo-50 text-indigo-700'
                  : 'border-white/70 bg-white/82 text-foreground hover:bg-white'
              }`}
            >
              <span className={`flex h-6 w-6 items-center justify-center rounded-full text-[12px] ${
                item.label === '深度思考' && isThinking
                  ? 'bg-indigo-200 text-indigo-700'
                  : 'bg-indigo-100 text-indigo-600'
              }`}>
                {item.icon}
              </span>
              {item.label}
            </button>
          ))}
        </div>

        {/* <div className="rounded-[30px] border border-white/70 bg-white/72 p-2 shadow-[0_24px_60px_rgba(148,163,184,0.16)] backdrop-blur-xl">
          <div className="flex items-end gap-2">
            <Button
              type="text"
              aria-label="语音输入"
              icon={<AudioOutlined />}
              className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-white/65 bg-white/80 text-foreground shadow-sm"
            />
            <div className="min-w-0 flex-1">
              <Sender
                value={inputValue}
                onChange={setInputValue}
                onSubmit={handleSubmit}
                onPasteFile={appendAttachments}
                loading={isRequesting}
                autoSize={{ minRows: 1, maxRows: 4 }}
                prefix={(
                  <Button
                    type="text"
                    aria-label="选择图片或 PDF 报告"
                    icon={<PaperClipOutlined />}
                    onClick={() => fileInputRef.current?.click()}
                    className="flex h-9 w-9 items-center justify-center rounded-full text-muted-foreground"
                  />
                )}
                suffix={(
                  <Button
                    type="text"
                    aria-label="发送消息"
                    icon={<ArrowUpOutlined />}
                    onClick={handleSendClick}
                    disabled={isRequesting || (!inputValue.trim() && pendingAttachments.length === 0)}
                    className="flex h-10 w-10 items-center justify-center rounded-full bg-[linear-gradient(135deg,rgba(99,102,241,0.96),rgba(168,85,247,0.84))] text-white shadow-[0_16px_28px_rgba(99,102,241,0.22)] disabled:bg-muted disabled:text-muted-foreground"
                  />
                )}
                header={senderHeader(activeContextHeader, attachmentHeader)}
                placeholder={mode === 'normal' ? '发送消息或按住说话…' : '描述症状，上传图片 / PDF 检查报告…'}
                className="rounded-[24px] border border-transparent bg-background/82 px-2 shadow-none"
              />
            </div>
            <Button
              type="text"
              aria-label="上传图片"
              icon={<CameraOutlined />}
              onClick={() => fileInputRef.current?.click()}
              className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-white/65 bg-white/80 text-foreground shadow-sm"
            />
          </div>
        </div> */}
        <div className="min-w-0 flex-1 rounded-[28px] border border-white/70 bg-white/76 p-1.5 shadow-[0_20px_48px_rgba(148,163,184,0.15)] backdrop-blur-xl sm:rounded-[30px] sm:p-2">
          <Sender
            value={inputValue}
            onChange={setInputValue}
            onSubmit={handleSubmit}
            onPasteFile={appendAttachments}
            loading={isRequesting}
            autoSize={{ minRows: 1, maxRows: 4 }}
            prefix={(
              <div className="flex items-center gap-1">
                <Button
                  type="text"
                  aria-label="选择图片或 PDF 报告"
                  icon={<PlusCircleOutlined />}
                  onClick={() => {
                    if (!token) {
                      navigate('/login');
                      return;
                    }
                    fileInputRef.current?.click();
                  }}
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo-50 text-indigo-500 sm:h-9 sm:w-9"
                  title="上传附件"
                />
                {mode === 'normal' && (
                  <Button
                    type={isThinking ? "primary" : "text"}
                    aria-label="深度思考"
                    icon={<ExperimentOutlined />}
                    onClick={() => {
                      if (!token) {
                        navigate('/login');
                        return;
                      }
                      setIsThinking(!isThinking);
                    }}
                    className={`flex h-8 w-8 items-center justify-center rounded-full sm:h-9 sm:w-9 transition-colors ${
                      isThinking
                        ? 'bg-indigo-100 text-indigo-700'
                        : 'bg-muted/50 text-muted-foreground hover:bg-muted/80'
                    }`}
                  />
                )}
              </div>
            )}
            suffix={(_, info) => {
              const { SendButton } = info.components;
              return <SendButton 
                type="text"
                aria-label="发送消息"
                icon={<ArrowUpOutlined />}
                onClick={handleSendClick}
                disabled={isRequesting || pendingAttachments.some(a => a.status === 'uploading') || (!inputValue.trim() && pendingAttachments.length === 0 && activeAttachmentContexts.length === 0)}
                className="flex h-9 w-9 items-center justify-center rounded-full bg-[linear-gradient(135deg,rgba(99,102,241,0.96),rgba(168,85,247,0.84))] text-white shadow-[0_14px_24px_rgba(99,102,241,0.22)] disabled:bg-muted disabled:text-muted-foreground sm:h-10 sm:w-10"
              />
            }}
            header={senderHeader(activeContextHeader, attachmentHeader)}
            placeholder={'描述症状持续时间、既往病史，或点击左侧 ➕ 上传图片/PDF报告…'}
            rootClassName="rounded-[24px] sm:rounded-[26px]"
            className="rounded-[24px] border border-transparent bg-background/88 px-2 shadow-none sm:rounded-[26px]"
            classNames={{
              content: 'gap-2',
              prefix: 'self-end pb-1',
              suffix: 'self-end pb-1',
              input: 'text-[14px] leading-6 sm:text-[15px] sm:leading-7',
            }}
          />
        </div>
        <div className="flex flex-col items-center justify-center gap-1.5 px-1 text-center text-[11px] text-muted-foreground sm:gap-2 sm:text-xs lg:flex-row lg:justify-between">
          <span>支持上传图片和 PDF 检查报告，也支持直接粘贴截图</span>
        </div>
      </div>
      </div>
      <Modal
        title="反馈 AI 回复"
        open={Boolean(feedbackTarget)}
        onCancel={() => !feedbackSubmitting && setFeedbackTarget(null)}
        onOk={() => void handleSubmitFeedback()}
        okButtonProps={{ loading: feedbackSubmitting }}
        cancelButtonProps={{ disabled: feedbackSubmitting }}
        destroyOnClose
      >
        <Input.TextArea
          className="mb-4"
          value={feedbackText}
          onChange={(event) => setFeedbackText(event.target.value)}
          placeholder="请描述您对这条 AI 回复的意见或建议"
          rows={5}
          maxLength={5000}
          showCount
        />
      </Modal>
    </>
  );
};

const updateAssistantMessage = (message: ChatMessage, chunk: ChatStreamChunk): ChatMessage => {
  if (chunk.type === 'ai_label') {
    return {
      ...message,
      aiLabelMeta: chunk.meta,
    };
  }

  if (chunk.type === 'reasoning') {
    return {
      ...message,
      reasoning: `${message.reasoning ?? ''}${chunk.content ?? ''}`,
      status: 'updating',
      loading: false,
    };
  }

  return {
    ...message,
    content: `${message.content}${chunk.content ?? ''}`,
    status: 'updating',
    loading: false,
  };
};

export default ChatContainer;
