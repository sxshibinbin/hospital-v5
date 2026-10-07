import { buildAuthorizationHeader, handleAuthFailure, isAuthError } from '../utils/authToken';

export interface HealthProfile {
  id: number;
  name: string;
  relation: string;
  gender: string;
  age: number;
  medical_history?: string | null;
  allergies?: string | null;
}

export interface HealthProfilePayload {
  name: string;
  relation: string;
  gender: string;
  age: number;
  medical_history?: string | null;
  allergies?: string | null;
}

const API_BASE = import.meta.env.VITE_API_BASE || '';
const CLIENT_TERMINAL = 'pc';

const buildTerminalHeaders = () => ({
  'X-Client-Terminal': CLIENT_TERMINAL,
});

export const fetchHealthProfiles = async (token: string): Promise<HealthProfile[]> => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/profiles`, {
    headers: {
      ...(authorizationHeader ? { Authorization: authorizationHeader } : {}),
      ...buildTerminalHeaders(),
    },
  });

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const err = await response.json().catch(() => ({}));
    throw new Error(err.detail || '获取健康档案失败');
  }

  return response.json();
};

export const createHealthProfile = async (token: string, payload: HealthProfilePayload): Promise<HealthProfile> => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/profiles`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(authorizationHeader ? { Authorization: authorizationHeader } : {}),
      ...buildTerminalHeaders(),
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    if (isAuthError(response.status)) {
      handleAuthFailure();
    }
    const err = await response.json().catch(() => ({}));
    throw new Error(err.detail || '创建健康档案失败');
  }

  return response.json();
};
