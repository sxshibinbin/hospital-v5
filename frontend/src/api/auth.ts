import { buildAuthorizationHeader, handleAuthFailure, isAuthError } from '../utils/authToken';

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface QrSessionResponse {
  session_id: string;
  qr_payload: string;
  pc_secret: string;
  expires_at: string;
  poll_interval_seconds: number;
}

export interface QrSessionStatus {
  status: 'pending' | 'scanned' | 'confirmed' | 'rejected' | 'cancelled' | 'expired' | 'consumed';
  expires_at?: string;
  scanned_at?: string;
  access_token?: string;
  token_type?: string;
}

export interface CurrentUserResponse {
  id: number;
  phone: string;
  display_name: string;
  default_profile_name?: string | null;
}

const API_BASE = import.meta.env.VITE_API_BASE || '';
const CLIENT_TERMINAL = 'pc';

const buildTerminalHeaders = () => ({
  'X-Client-Terminal': CLIENT_TERMINAL,
});

export const sendSmsCode = async (phone: string) => {
  const response = await fetch(`${API_BASE}/api/auth/send_code`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildTerminalHeaders(),
    },
    body: JSON.stringify({ phone: phone.trim() }),
  });
  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.detail || '发送验证码失败');
  }
  return response.json();
};

export const loginWithSms = async (phone: string, code: string): Promise<LoginResponse> => {
  const response = await fetch(`${API_BASE}/api/auth/login/sms`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildTerminalHeaders(),
    },
    body: JSON.stringify({ phone: phone.trim(), code: code.trim().replace(/[０-９]/g, (digit) => String.fromCharCode(digit.charCodeAt(0) - 0xfee0)) }),
  });
  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.detail || '登录失败');
  }
  return response.json();
};

const parseAuthError = async (response: Response, fallback: string) => {
  const err = await response.json().catch(() => ({}));
  return new Error(err.detail || fallback);
};

export const createQrLoginSession = async (): Promise<QrSessionResponse> => {
  const response = await fetch(`${API_BASE}/api/auth/qr/session`, {
    method: 'POST',
    headers: {
      ...buildTerminalHeaders(),
    },
  });
  if (!response.ok) throw await parseAuthError(response, '创建二维码失败');
  return response.json();
};

export const fetchQrLoginStatus = async (
  sessionId: string,
  pcSecret: string,
): Promise<QrSessionStatus> => {
  const response = await fetch(`${API_BASE}/api/auth/qr/session/${encodeURIComponent(sessionId)}/status`, {
    headers: {
      ...buildTerminalHeaders(),
      'X-QR-PC-Secret': pcSecret,
    },
  });
  if (!response.ok) throw await parseAuthError(response, '查询扫码状态失败');
  return response.json();
};

export const cancelQrLoginSession = async (sessionId: string, pcSecret: string) => {
  const response = await fetch(`${API_BASE}/api/auth/qr/session/${encodeURIComponent(sessionId)}/cancel`, {
    method: 'POST',
    headers: {
      ...buildTerminalHeaders(),
      'X-QR-PC-Secret': pcSecret,
    },
  });
  if (!response.ok) throw await parseAuthError(response, '取消二维码失败');
  return response.json();
};

export const logout = async (token: string) => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/auth/logout`, {
    method: 'POST',
    headers: {
      ...(authorizationHeader ? { Authorization: authorizationHeader } : {}),
      ...buildTerminalHeaders(),
    },
  });

  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    throw new Error(err.detail || '退出失败');
  }

  return response.json();
};

export const fetchCurrentUser = async (token: string): Promise<CurrentUserResponse> => {
  const authorizationHeader = buildAuthorizationHeader(token);
  const response = await fetch(`${API_BASE}/api/auth/me`, {
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
    throw new Error(err.detail || '获取用户信息失败');
  }

  return response.json();
};
