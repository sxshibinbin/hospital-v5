import { buildAuthorizationHeader, handleAuthFailure, isAuthError } from '../utils/authToken';
import type { AiLabelMeta } from './chat';

export interface ChatSessionMessage {
  id: string;
  role: 'user' | 'ai';
  content: string;
  reasoning?: string;
  status: 'local' | 'loading' | 'updating' | 'success' | 'error';
  contextFileIds?: string[];
  aiLabelMeta?: AiLabelMeta;
}

export interface ChatSessionSummary {
  id: number;
  title: string;
  mode: 'normal' | 'medical';
  last_message?: string | null;
  created_at: string;
  updated_at: string;
}

export interface ChatSessionDetail extends ChatSessionSummary {
  messages: ChatSessionMessage[];
}

const API_BASE = import.meta.env.VITE_API_BASE || '';

const requestJson = async <T>(url: string, init: RequestInit, fallbackMessage: string): Promise<T> => {
  const response = await fetch(`${API_BASE}${url}`, init);

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const errorBody = await response.json().catch(() => ({}));
    throw new Error(errorBody.detail || fallbackMessage);
  }

  return response.json();
};

export const fetchChatSessions = async (token: string): Promise<ChatSessionSummary[]> => {
  const authorizationHeader = buildAuthorizationHeader(token);

  return requestJson<ChatSessionSummary[]>(
    '/api/chat-sessions',
    {
      method: 'GET',
      headers: authorizationHeader ? { Authorization: authorizationHeader } : {},
    },
    '获取对话历史失败',
  );
};

export const fetchChatSessionDetail = async (token: string, sessionId: number): Promise<ChatSessionDetail> => {
  const authorizationHeader = buildAuthorizationHeader(token);

  return requestJson<ChatSessionDetail>(
    `/api/chat-sessions/${sessionId}`,
    {
      method: 'GET',
      headers: authorizationHeader ? { Authorization: authorizationHeader } : {},
    },
    '获取对话详情失败',
  );
};

export const saveChatSession = async (
  token: string,
  mode: 'normal' | 'medical',
  messages: ChatSessionMessage[],
  sessionId?: number | null,
): Promise<ChatSessionSummary> => {
  const authorizationHeader = buildAuthorizationHeader(token);

  return requestJson<ChatSessionSummary>(
    '/api/chat-sessions',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader ? { Authorization: authorizationHeader } : {}),
      },
      body: JSON.stringify({
        session_id: sessionId ?? null,
        mode,
        messages,
      }),
    },
    '保存对话历史失败',
  );
};

export const deleteChatSession = async (token: string, sessionId: number): Promise<void> => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/chat-sessions/${sessionId}`, {
    method: 'DELETE',
    headers: authorizationHeader ? { Authorization: authorizationHeader } : {},
  });

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const errorBody = await response.json().catch(() => ({}));
    throw new Error(errorBody.detail || '删除对话历史失败');
  }
};
