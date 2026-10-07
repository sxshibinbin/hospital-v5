import { buildAuthorizationHeader, handleAuthFailure } from '../utils/authToken';

export async function submitAiFeedback(
  token: string,
  payload: { content: string; question: string; ai_response: string; session_id?: number | null; message_id?: string },
) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const authorization = buildAuthorizationHeader(token);
  if (authorization) headers.Authorization = authorization;
  const response = await fetch('/api/feedback', { method: 'POST', headers, body: JSON.stringify(payload) });
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) handleAuthFailure();
    const body = await response.json().catch(() => ({}));
    throw new Error(body.detail || '反馈提交失败');
  }
  return response.json();
}
