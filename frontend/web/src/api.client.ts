import axios from 'axios';

export function extractMessage(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const obj = payload as Record<string, unknown>;

  if (typeof obj.message === 'string' && obj.message.trim()) {
    return obj.message;
  }

  if (typeof obj.error === 'string' && obj.error.trim()) {
    return obj.error;
  }

  if (obj.data && typeof obj.data === 'object') {
    const nested = obj.data as Record<string, unknown>;

    if (typeof nested.message === 'string' && nested.message.trim()) {
      return nested.message;
    }
  }

  return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// All services route through Nginx gateway at 13.250.2.132
// Override with environment variables:
//   VITE_API_BASE_URL     → Core API (auth, users, friends)
//   VITE_MESSAGE_API_URL  → Message API (chat, conversations)
//   VITE_MEDIA_API_URL    → Media API (uploads, stickers)
//   VITE_WS_BASE_URL      → WebSocket base (defaults to same origin)
// ──────────────────────────────────────────────────────────────────────────────
const FALLBACK_HOST = typeof window !== 'undefined' ? window.location.hostname : 'localhost';

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? (
  typeof window !== 'undefined'
    ? `${window.location.origin}/api/v1`
    : `http://${FALLBACK_HOST}/api/v1`
);

if (typeof window !== 'undefined') {
  // Store the root origin (without /api/v1) for media resolution
  (window as any).__VNALO_API_ROOT__ = API_BASE_URL.replace(/\/api\/v1\/?$/, '');
}

export const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? API_BASE_URL;

const rawMediaUrl = import.meta.env.VITE_MEDIA_API_URL ?? (
  typeof window !== 'undefined'
    ? `${window.location.origin}/api/v1/media`
    : `http://${FALLBACK_HOST}/api/v1/media`
);

// Robust normalization for Media API URL
const normalizeMediaUrl = (url: string) => {
  let cleaned = url.replace(/\/+$/, ''); // Remove trailing slashes
  if (cleaned.endsWith('/api/v1')) {
    cleaned = `${cleaned}/media`;
  }
  return `${cleaned}/`; // Always end with a single slash to avoid redirects
};

export const MEDIA_API_URL = normalizeMediaUrl(rawMediaUrl);

export const WS_BASE_URL = import.meta.env.VITE_WS_BASE_URL ?? (
  typeof window !== 'undefined'
    ? window.location.origin
    : '/'
);

export const api = axios.create({
  baseURL: API_BASE_URL,
});

export const messageApi = axios.create({
  baseURL: MESSAGE_API_URL,
});

export const mediaApi = axios.create({
  baseURL: MEDIA_API_URL,
});

api.interceptors.request.use(req => {
  console.log('[API-CORE]', req.url);
  return req;
});

messageApi.interceptors.request.use(req => {
  console.log('[API-MSG]', req.url);
  return req;
});

mediaApi.interceptors.request.use(req => {
  console.log('[API-MEDIA]', req.url);
  return req;
});

const globalLogoutHandler = () => {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('vnalo:auth:revoked', {
      detail: { reason: 'token_expired' }
    }));
  }
};

const commonResponseInterceptor = [
  (res: any) => res,
  (err: any) => {
    const status = err.response?.status;
    const isSilenced = status === 404 || status === 403; // Ignore noise for deleted/forbidden content
    
    if (!isSilenced) {
      console.error('[API ERROR]', err.response?.data || err.message);
    } else {
      console.warn(`[API ${status}]`, err.config?.url);
    }

    if (status === 401) {
      globalLogoutHandler();
    }
    return Promise.reject(err);
  }
] as const;

api.interceptors.response.use(...commonResponseInterceptor);
messageApi.interceptors.response.use(...commonResponseInterceptor);
mediaApi.interceptors.response.use(...commonResponseInterceptor);
