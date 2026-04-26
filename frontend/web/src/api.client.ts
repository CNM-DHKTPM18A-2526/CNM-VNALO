import axios from 'axios';

export function extractMessage(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const obj = payload as Record<string, unknown>

  if (typeof obj.message === 'string' && obj.message.trim()) {
    return obj.message
  }

  if (typeof obj.error === 'string' && obj.error.trim()) {
    return obj.error
  }

  if (obj.data && typeof obj.data === 'object') {
    const nested = obj.data as Record<string, unknown>

    if (typeof nested.message === 'string' && nested.message.trim()) {
      return nested.message
    }
  }

  return null
}

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? (
  typeof window !== 'undefined'
    ? `${window.location.origin}/api/v1`
    : '/api/v1'
);

export const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? API_BASE_URL;

export const MEDIA_API_URL = import.meta.env.VITE_MEDIA_API_URL ?? (
  typeof window !== 'undefined' && window.location.port !== '80'
    ? `http://${window.location.hostname}:8083/api/v1`
    : API_BASE_URL
);

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

const commonResponseInterceptor = [
  (res: any) => res,
  (err: any) => {
    console.error('[API ERROR]', err.response?.data || err.message);
    return Promise.reject(err);
  }
] as const;

api.interceptors.response.use(...commonResponseInterceptor);
messageApi.interceptors.response.use(...commonResponseInterceptor);
mediaApi.interceptors.response.use(...commonResponseInterceptor);
