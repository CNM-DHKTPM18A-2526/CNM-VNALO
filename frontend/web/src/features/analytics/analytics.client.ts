import axios from 'axios'

export const ANALYTICS_API_URL = (() => {
  const base = import.meta.env.VITE_ANALYTICS_API_URL
  if (base) return base.replace(/\/+$/, '')
  return `${window.location.origin}/api/v1/analytics`
})()

export const analyticsApi = axios.create({
  baseURL: ANALYTICS_API_URL,
  timeout: 12000,
})

analyticsApi.interceptors.request.use(req => {
  console.log('[API-ANALYTICS]', req.url)
  return req
})

export const ANALYTICS_TIMEOUT = 12000

export async function analyticsFetchWithTimeout<T>(url: string, params?: Record<string, unknown>): Promise<T> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), ANALYTICS_TIMEOUT)
  try {
    const response = await analyticsApi.get<T>(url, {
      params,
      signal: controller.signal,
      headers: getAnalyticsHeaders(),
    })
    return response.data
  } finally {
    clearTimeout(timer)
  }
}

function getAnalyticsHeaders(): Record<string, string> {
  const token = localStorage.getItem('vnalo.accessToken')
  return token ? { Authorization: `Bearer ${token}` } : {}
}

export function extractAnalyticsData<T>(payload: unknown): T | null {
  if (!payload || typeof payload !== 'object') return null
  const obj = payload as Record<string, unknown>
  if (obj.success === false) return null
  return (obj.data ?? payload) as T
}

export function resolveAnalyticsError(response: unknown): string {
  if (!response || typeof response !== 'object') return 'Network error'
  const obj = response as Record<string, unknown>
  if (typeof obj.message === 'string') return obj.message
  if (obj.success === false && typeof obj.errorCode === 'string') return `Error: ${obj.errorCode}`
  return 'Analytics service unavailable'
}
