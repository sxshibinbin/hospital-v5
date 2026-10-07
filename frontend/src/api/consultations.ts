import { buildAuthorizationHeader, handleAuthFailure, isAuthError } from '../utils/authToken';
import type { AiLabelMeta } from './chat';

export interface ConsultationCardData {
  summary?: string;
  analysis?: string;
  recommended_department?: string;
  hospital_suggestion?: string;
}

export interface ConsultationChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface SavedConsultationRecord {
  id: number;
  profile_id: number;
  profile_name: string;
  relation: string;
  summary?: string;
  analysis?: string;
  recommended_department?: string;
  hospital_suggestion?: string;
  created_at: string;
  ai_label_meta?: AiLabelMeta | null;
}

const API_BASE = import.meta.env.VITE_API_BASE || '';

const requestJson = async <T>(url: string, init: RequestInit, fallbackMessage: string): Promise<T> => {
  const response = await fetch(`${API_BASE}${url}`, init);

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }

    let errorMessage = fallbackMessage;

    try {
      const errorPayload = await response.json();
      if (typeof errorPayload?.detail === 'string' && errorPayload.detail) {
        errorMessage = errorPayload.detail;
      }
    } catch {
      errorMessage = fallbackMessage;
    }

    throw new Error(errorMessage);
  }

  return response.json() as Promise<T>;
};

export const saveConsultationRecord = async (
  token: string,
  cardData: ConsultationCardData,
  chatHistory: ConsultationChatTurn[],
  profileId?: number,
): Promise<SavedConsultationRecord> => {
  const authorizationHeader = buildAuthorizationHeader(token);

  return requestJson<SavedConsultationRecord>(
    '/api/consultations/save-card',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader ? { Authorization: authorizationHeader } : {}),
      },
      body: JSON.stringify({
        profile_id: profileId,
        card_data: cardData,
        chat_history: chatHistory,
      }),
    },
    '保存问诊记录失败',
  );
};

export const fetchConsultationRecords = async (token: string): Promise<SavedConsultationRecord[]> => {
  const authorizationHeader = buildAuthorizationHeader(token);

  return requestJson<SavedConsultationRecord[]>(
    '/api/consultations/records',
    {
      method: 'GET',
      headers: authorizationHeader ? { Authorization: authorizationHeader } : {},
    },
    '获取问诊记录失败',
  );
};

export const deleteConsultationRecord = async (token: string, recordId: number): Promise<void> => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/consultations/records/${recordId}`, {
    method: 'DELETE',
    headers: authorizationHeader ? { Authorization: authorizationHeader } : {},
  });

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const errorBody = await response.json().catch(() => ({}));
    throw new Error(errorBody.detail || '删除问诊记录失败');
  }
};
