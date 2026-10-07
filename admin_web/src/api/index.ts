import axios from 'axios';

// BASE_URL 可能带或不带末尾斜杠（如 /admin_web），统一剥掉后再拼子路径
const BASE_PATH = import.meta.env.BASE_URL.replace(/\/$/, '');

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '',
  timeout: 10000,
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`);
  }
  config.headers.set('X-Client-Terminal', 'admin_web');
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 || error.response?.status === 403) {
      localStorage.removeItem('admin_token');
      window.location.href = `${BASE_PATH}/login`;
    }
    return Promise.reject(error);
  }
);

export const login = async (phone: string, password: string) => {
  const params = new URLSearchParams();
  params.append('username', phone);
  params.append('password', password);
  
  const response = await api.post('/api/auth/login', params, {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Client-Terminal': 'admin_web',
    },
  });
  
  localStorage.setItem('admin_token', response.data.access_token);
  return response.data;
};

export const logout = async () => {
  try {
    await api.post('/api/auth/logout');
  } catch (error) {
    console.warn('Admin logout request failed:', error);
  } finally {
    localStorage.removeItem('admin_token');
    window.location.href = `${BASE_PATH}/login`;
  }
};

export const checkAdmin = async () => {
  const response = await api.get('/api/auth/check-admin');
  return response.data as { has_admin: boolean };
};

export const setupAdmin = async (phone: string, password: string, displayName: string) => {
  const response = await api.post('/api/auth/setup', {
    phone,
    password,
    display_name: displayName,
  });
  localStorage.setItem('admin_token', response.data.access_token);
  return response.data;
};

export interface User {
  id: number;
  phone: string;
  display_name: string;
  is_admin: boolean;
  is_active: boolean;
  is_deactivated: boolean;
  created_at: string;
  profile_count: number;
  session_count: number;
}

export interface DashboardStats {
  total_users: number;
  total_sessions: number;
  total_consultations: number;
  total_questions: number;
  recent_users: {
    id: number;
    phone: string;
    display_name: string;
    created_at: string;
  }[];
  recent_consultations: {
    id: number;
    department: string;
    created_at: string;
  }[];
}

export const getDashboardStats = async () => {
  const response = await api.get<DashboardStats>('/api/admin/dashboard/stats');
  return response.data;
};

export const getUsers = async () => {
  const response = await api.get<User[]>('/api/admin/users');
  return response.data;
};

export const updateUserStatus = async (userId: number, isActive: boolean) => {
  const response = await api.put(`/api/admin/users/${userId}/status`, { is_active: isActive });
  return response.data;
};

export interface ChatSessionMessagePayload {
  id: string;
  role: 'user' | 'ai';
  content: string;
  reasoning?: string;
  status: 'local' | 'loading' | 'updating' | 'success' | 'error';
  contextFileIds?: string[];
}

export interface ChatSessionSummary {
  id: number;
  title: string;
  mode: 'normal' | 'medical';
  last_message?: string;
  created_at: string;
  updated_at: string;
}

export interface ChatSessionDetail extends ChatSessionSummary {
  messages: ChatSessionMessagePayload[];
}

export const getUserChatSessions = async (userId: number) => {
  const response = await api.get<ChatSessionSummary[]>(`/api/admin/users/${userId}/chat-sessions`);
  return response.data;
};

export const getAdminChatSessionDetail = async (sessionId: number) => {
  const response = await api.get<ChatSessionDetail>(`/api/admin/chat-sessions/${sessionId}`);
  return response.data;
};

export interface Config {
  key: string;
  value: string;
  description: string;
  updated_at: string;
}

export interface AuditLog {
  id: number;
  admin_name: string;
  action: string;
  target_id: string;
  details: string;
  created_at: string;
}

export interface OperationLog {
  id: number;
  created_at: string;
  module?: string | null;
  action: string;
  terminal?: string | null;
  result?: string | null;
  actor_type?: string | null;
  actor_name?: string | null;
  actor_phone_masked?: string | null;
  target_type?: string | null;
  target_id?: string | null;
  ip_address?: string | null;
  details?: string | null;
  request_id?: string | null;
  user_agent?: string | null;
  metadata?: Record<string, unknown> | null;
}

export interface OperationLogPage {
  total: number;
  page: number;
  page_size: number;
  items: OperationLog[];
}

export interface OperationLogQueryParams {
  page?: number;
  page_size?: number;
  start_time?: string;
  end_time?: string;
  module?: string;
  action?: string;
  result?: string;
  actor_type?: string;
  target_type?: string;
  terminal?: string;
  keyword?: string;
}

export const getSettings = async () => {
  const response = await api.get<Config[]>('/api/admin/settings');
  return response.data;
};

export const updateSettings = async (configs: { key: string, value: string }[]) => {
  const response = await api.put('/api/admin/settings', { configs });
  return response.data;
};

export const updatePassword = async (oldPassword: string, newPassword: string) => {
  const response = await api.put('/api/admin/password', {
    old_password: oldPassword,
    new_password: newPassword,
  });
  return response.data;
};

export const getAuditLogs = async () => {
  const response = await api.get<AuditLog[]>('/api/admin/audit-logs');
  return response.data;
};

export const getOperationLogs = async (params: OperationLogQueryParams = {}) => {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.set(key, String(value));
    }
  });

  const queryString = searchParams.toString();
  const response = await api.get<OperationLogPage>(
    queryString ? `/api/admin/logs?${queryString}` : '/api/admin/logs',
  );
  return response.data;
};

export interface Question {
  id: number;
  question: string;
  answer_template: string;
  category?: string;
  is_top: boolean;
  status: 'draft' | 'published' | 'disabled';
  sort_weight: number;
  click_count: number;
  created_at: string;
  updated_at: string;
}

export interface QuestionCreate {
  question: string;
  answer_template: string;
  category?: string;
  is_top: boolean;
  status: string;
  sort_weight: number;
}

export const getQuestions = async () => {
  const response = await api.get<Question[]>('/api/admin/questions');
  return response.data;
};

export const createQuestion = async (data: QuestionCreate) => {
  const response = await api.post<Question>('/api/admin/questions', data);
  return response.data;
};

export const updateQuestion = async (id: number, data: QuestionCreate) => {
  const response = await api.put<Question>(`/api/admin/questions/${id}`, data);
  return response.data;
};

export const deleteQuestion = async (id: number) => {
  const response = await api.delete(`/api/admin/questions/${id}`);
  return response.data;
};

export const publishQuestion = async (id: number) => {
  const response = await api.put<Question>(`/api/admin/questions/${id}/publish`);
  return response.data;
};

export interface Agreement {
  id: number;
  type: string;
  title: string;
  content: string;
  updated_at: string;
}

export const getAgreements = async () => {
  const response = await api.get<Agreement[]>('/api/admin/agreements');
  return response.data;
};

export const updateAgreement = async (type: string, title: string, content: string) => {
  const response = await api.put(`/api/admin/agreements/${type}`, { title, content });
  return response.data;
};

export interface AiFeedback {
  id: number;
  feedback_user: string;
  question: string;
  ai_response: string;
  content: string;
  session_id?: number | null;
  created_at: string;
}

export const getAiFeedback = async (params: { keyword?: string; page?: number; page_size?: number } = {}) => {
  const response = await api.get<{ items: AiFeedback[]; total: number; page: number; page_size: number }>('/api/feedback/admin', { params });
  return response.data;
};

export const checkAiSafety = async (text: string) => {
  const response = await api.post('/api/admin/ai-safety/check', { text });
  return response.data;
};

export const getAiSafetyEvents = async (params: { page?: number; page_size?: number } = {}) => {
  const response = await api.get<{ items: any[]; total: number; page: number; page_size: number }>('/api/admin/ai-safety/events', { params });
  return response.data;
};

export type AiStatus = 'enabled' | 'disabled';
export type AiRiskLevel = 'low' | 'medium' | 'high' | 'critical';

export interface AiIntentRule {
  id: number;
  scene_name: string;
  intent_code: string;
  risk_level: AiRiskLevel;
  triggers: string;
  match_mode: string;
  reply_template?: string | null;
  action: string;
  scope: string;
  priority: number;
  status: AiStatus;
  hit_count: number;
  remark?: string | null;
  created_at?: string;
  updated_at?: string;
}

export type AiIntentRulePayload = Omit<AiIntentRule, 'id' | 'hit_count' | 'created_at' | 'updated_at'>;

export const getAiIntentRules = async (params: Record<string, string> = {}) => {
  const response = await api.get<{ items: AiIntentRule[]; total: number }>('/api/admin/ai-safety/intent-rules', { params });
  return response.data;
};
export const createAiIntentRule = async (data: AiIntentRulePayload) => (await api.post<AiIntentRule>('/api/admin/ai-safety/intent-rules', data)).data;
export const updateAiIntentRule = async (id: number, data: Partial<AiIntentRulePayload>) => (await api.put<AiIntentRule>(`/api/admin/ai-safety/intent-rules/${id}`, data)).data;
export const deleteAiIntentRule = async (id: number) => (await api.delete(`/api/admin/ai-safety/intent-rules/${id}`)).data;

export interface AiSensitiveWord {
  id: number;
  category: string;
  content: string;
  match_mode: string;
  action: string;
  reply_template?: string | null;
  apply_phase: string;
  scope: string;
  risk_level: AiRiskLevel;
  whitelist_context?: string | null;
  priority: number;
  status: AiStatus;
  hit_count: number;
  source_version?: string | null;
  created_at?: string;
  updated_at?: string;
}
export type AiSensitiveWordPayload = Omit<AiSensitiveWord, 'id' | 'hit_count' | 'created_at' | 'updated_at'>;
export const getAiSensitiveWords = async (params: Record<string, string> = {}) => (await api.get<{ items: AiSensitiveWord[]; total: number }>('/api/admin/ai-safety/words', { params })).data;
export const createAiSensitiveWord = async (data: AiSensitiveWordPayload) => (await api.post<AiSensitiveWord>('/api/admin/ai-safety/words', data)).data;
export const updateAiSensitiveWord = async (id: number, data: Partial<AiSensitiveWordPayload>) => (await api.put<AiSensitiveWord>(`/api/admin/ai-safety/words/${id}`, data)).data;
export const deleteAiSensitiveWord = async (id: number) => (await api.delete(`/api/admin/ai-safety/words/${id}`)).data;
export const batchUpdateAiSensitiveWordStatus = async (ids: number[], status: AiStatus) => (await api.post('/api/admin/ai-safety/words/batch-status', { ids, status })).data;
export const importAiSensitiveWords = async (file: File) => {
  const form = new FormData();
  form.append('file', file);
  return (await api.post('/api/admin/ai-safety/words/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })).data;
};
export const exportAiSensitiveWords = async () => (await api.get('/api/admin/ai-safety/words/export', { responseType: 'blob' })).data;
