import { fetchEventSource } from '@microsoft/fetch-event-source';
import { buildAuthorizationHeader, handleAuthFailure, isAuthError } from '../utils/authToken';

interface ChatHistoryItem {
  id: string;
  message: string;
}

export interface AiLabelMeta {
  aiGenerated: boolean;
  serviceProviderCode: string;
  contentId: string;
  generateTimestamp: number;
  packageName: string;
  reserved: string;
}

export interface ChatStreamChunk {
  type: 'content' | 'reasoning' | 'context' | 'ai_label' | 'safety' | 'notice';
  content?: string;
  text?: string;
  phase?: string;
  action?: string;
  riskLevel?: string;
  intent?: string;
  aborted?: boolean;
  decisionId?: string;
  fileIds?: string[];
  newFileIds?: string[];
  meta?: AiLabelMeta;
}

export async function uploadChatAttachments(files: File[], token?: string) {
  const finalUrl = import.meta.env.VITE_API_URL ? import.meta.env.VITE_API_URL.replace('/chat', '/chat/uploads') : '/api/chat/uploads';
  const body = new FormData();
  files.forEach((file) => {
    body.append('files', file);
  });

  const headers: Record<string, string> = {};
  const authorizationHeader = buildAuthorizationHeader(token);
  if (authorizationHeader) {
    headers.Authorization = authorizationHeader;
  }

  const response = await fetch(finalUrl, {
    method: 'POST',
    headers,
    body,
  });

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const errorBody = await response.json().catch(() => ({}));
    throw new Error(errorBody.detail || '上传文件失败');
  }

  return response.json();
}

export async function* fetchChatStream(
  mode: 'normal' | 'medical',
  message: string,
  history: ChatHistoryItem[],
  token?: string,
  isThinking?: boolean,
  files: File[] = [],
  contextFileIds: string[] = [],
  consultationProfileId?: number,
): AsyncGenerator<ChatStreamChunk, void, unknown> {
  const controller = new AbortController();

  const formattedHistory = history.map((item) => ({
    role: item.id.startsWith('user') ? 'user' : 'assistant',
    content: item.message,
  }));

  // Determine base API URL
  let finalUrl = import.meta.env.VITE_API_URL;
  if (!finalUrl) {
    finalUrl = '/api/chat';
  }

  if (typeof window !== 'undefined' && window.location.hostname === '10.0.2.2' && finalUrl.includes('localhost')) {
    finalUrl = finalUrl.replace('localhost', '10.0.2.2');
  }

  // const body = JSON.stringify({ mode, message, history: formattedHistory, thinking: isThinking });
  const body = new FormData();
  body.append('mode', mode);
  body.append('message', message);
  body.append('history', JSON.stringify(formattedHistory));
  body.append('thinking', String(Boolean(isThinking)));
  body.append('terminal', 'web');
  
  if (contextFileIds && contextFileIds.length > 0) {
    body.append('context_file_ids', JSON.stringify(contextFileIds));
  }
  
  if (consultationProfileId !== undefined) {
    body.append('consultation_profile_id', String(consultationProfileId));
  }
  
  if (files && files.length > 0) {
    files.forEach((file) => {
      body.append('files', file);
    });
  }

  const headers: Record<string, string> = {
    Accept: 'text/event-stream',
  };

  const authorizationHeader = buildAuthorizationHeader(token);
  if (authorizationHeader) {
    headers.Authorization = authorizationHeader;
  }

  const stream = new ReadableStream<ChatStreamChunk>({
    start(controllerStream) {
      let isSettled = false;

      const closeStream = () => {
        if (isSettled) {
          return;
        }

        isSettled = true;
        controllerStream.close();
      };

      const errorStream = (error: unknown) => {
        if (isSettled) {
          return;
        }

        isSettled = true;
        controllerStream.error(error);
      };

      fetchEventSource(finalUrl, {
        method: 'POST',
        headers,
        body,
        signal: controller.signal,
        async onopen(response) {
          if (response.ok) {
            return;
          }
          if (isAuthError(response.status)) {
            handleAuthFailure();
          }
          let errorMessage = '请求失败，请稍后重试';
          try {
            const errorPayload = await response.json();
            if (typeof errorPayload?.detail === 'string' && errorPayload.detail) {
              errorMessage = errorPayload.detail;
            }
          } catch {
            // ignore
          }
          throw new Error(errorMessage);
        },
        onmessage(ev) {
          if (ev.data === '[DONE]') {
            closeStream();
            return;
          }
          try {
            const data = JSON.parse(ev.data);
            if (data.error) {
              errorStream(new Error(data.error));
            } else if (data.type === 'ai_label' && data.meta && typeof data.meta === 'object') {
              controllerStream.enqueue({
                type: 'ai_label',
                meta: data.meta as AiLabelMeta,
              });
            } else if (data.type === 'context' && Array.isArray(data.fileIds)) {
              controllerStream.enqueue({
                type: 'context',
                fileIds: data.fileIds.filter((item: unknown): item is string => typeof item === 'string'),
                newFileIds: Array.isArray(data.newFileIds)
                  ? data.newFileIds.filter((item: unknown): item is string => typeof item === 'string')
                  : [],
              });
            } else if (data.type === 'safety') {
              controllerStream.enqueue({ type: 'safety', phase: data.phase, action: data.action, riskLevel: data.riskLevel, intent: data.intent, aborted: data.aborted, decisionId: data.decisionId });
            } else if (data.type === 'notice' && typeof data.text === 'string') {
              controllerStream.enqueue({ type: 'notice', text: data.text });
            } else if (
              (data.type === 'content' || data.type === 'reasoning') &&
              typeof data.content === 'string' &&
              data.content.length > 0
            ) {
              controllerStream.enqueue({
                type: data.type,
                content: data.content,
              });
            } else if (typeof data.content === 'string' && data.content.length > 0) {
              controllerStream.enqueue({
                type: 'content',
                content: data.content,
              });
            }
          } catch (e) {
            console.error('Failed to parse SSE data', e);
          }
        },
        onerror(err) {
          errorStream(err);
          throw err;
        },
        onclose() {
          closeStream();
        },
      });
    },
  });

  const reader = stream.getReader();
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) yield value;
    }
  } finally {
    controller.abort();
    reader.releaseLock();
  }
}
