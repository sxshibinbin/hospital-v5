export const normalizeAuthToken = (token?: string | null) => {
  if (!token) {
    return '';
  }

  const trimmedToken = token.trim().replace(/^['"]|['"]$/g, '');
  const normalizedToken = trimmedToken.replace(/^Bearer\s+/i, '').trim();

  return normalizedToken;
};

export const buildAuthorizationHeader = (token?: string | null) => {
  const normalizedToken = normalizeAuthToken(token);

  if (!normalizedToken) {
    return undefined;
  }

  return `Bearer ${normalizedToken}`;
};

/**
 * 统一处理 401：清除本地 token 并跳转登录页（带 expired 标记）。
 * 在 Flutter WebView 内不主动跳转，token 由原生层重新注入。
 */
export const handleAuthFailure = () => {
  if (typeof window === 'undefined') {
    return;
  }

  localStorage.removeItem('token');

  if (typeof window.FlutterBridge !== 'undefined') {
    return;
  }

  const currentPath = window.location.pathname;
  if (currentPath !== '/login') {
    window.location.assign('/login?expired=1');
  }
};

export const isAuthError = (status: number) => status === 401;
