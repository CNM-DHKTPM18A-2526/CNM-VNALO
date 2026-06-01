import React from 'react'

import { API_BASE_URL, AI_API_URL, MEDIA_API_URL, MESSAGE_API_URL } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/admin-monitoring.css'

type MonitorStatus = 'ok' | 'warning' | 'error' | 'checking'

type ServiceProbe = {
  name: string
  url: string
  status: MonitorStatus
  detail: string
}

type SessionAudit = {
  auditId?: string
  eventType?: string
  fromStatus?: string
  toStatus?: string
  deviceId?: string
  platform?: string
  reason?: string
  createdAt?: string
}

const timeoutMs = 4500

async function fetchWithTimeout(url: string, token?: string | null) {
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, {
      signal: controller.signal,
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    })
  } finally {
    window.clearTimeout(timer)
  }
}

function extractArray(payload: unknown): unknown[] {
  if (Array.isArray(payload)) return payload
  if (!payload || typeof payload !== 'object') return []
  const obj = payload as Record<string, unknown>
  if (Array.isArray(obj.data)) return obj.data
  if (obj.data && typeof obj.data === 'object') {
    const nested = obj.data as Record<string, unknown>
    if (Array.isArray(nested.items)) return nested.items
    if (Array.isArray(nested.content)) return nested.content
  }
  return []
}

function isLikelyAdmin(email?: string | null) {
  if (!email) return false
  return /(^admin@|\.admin@|@admin\.)/i.test(email)
}

export function AdminMonitoringPage() {
  const { language } = useLanguage()
  const { user, accessToken } = useAuth()
  const [services, setServices] = React.useState<ServiceProbe[]>([])
  const [audits, setAudits] = React.useState<SessionAudit[]>([])
  const [isLoading, setIsLoading] = React.useState(true)
  const [lastUpdated, setLastUpdated] = React.useState<Date | null>(null)
  const labels = language === 'vi'
    ? {
        title: 'Giám sát vận hành',
        subtitle: 'Theo dõi trạng thái dịch vụ, sự kiện phiên đăng nhập và các rủi ro cần kiểm tra mà không hiển thị dữ liệu nhạy cảm.',
        accessNote: 'Trang này là dashboard MVP. Backend cần bổ sung role admin/API tổng hợp để khóa quyền nghiêm ngặt ở production.',
        refresh: 'Làm mới',
        serviceHealth: 'Trạng thái dịch vụ',
        sessionAudits: 'Sự kiện phiên gần đây',
        dataGuard: 'Nguyên tắc dữ liệu an toàn',
        noAudits: 'Chưa có sự kiện phiên hoặc API chưa trả dữ liệu.',
        updated: 'Cập nhật',
      }
    : {
        title: 'Operations Monitoring',
        subtitle: 'Monitor service status, session events, and risks without exposing sensitive user data.',
        accessNote: 'This is an MVP dashboard. Backend admin roles/summary APIs should enforce strict production access.',
        refresh: 'Refresh',
        serviceHealth: 'Service health',
        sessionAudits: 'Recent session events',
        dataGuard: 'Safe data guardrails',
        noAudits: 'No session events yet or the API returned no data.',
        updated: 'Updated',
      }

  const load = React.useCallback(async () => {
    setIsLoading(true)
    const probes = [
      { name: 'core-service', url: `${API_BASE_URL}/actuator/health` },
      { name: 'message-service', url: `${MESSAGE_API_URL}/health` },
      { name: 'media-service', url: MEDIA_API_URL.replace(/\/media\/?$/, '/media/actuator/health') },
      { name: 'ai-service', url: `${AI_API_URL}/actuator/health` },
    ]

    const serviceResults = await Promise.all(
      probes.map(async (probe): Promise<ServiceProbe> => {
        try {
          const response = await fetchWithTimeout(probe.url, accessToken)
          if (response.ok) {
            return { ...probe, status: 'ok', detail: `${response.status}` }
          }
          return { ...probe, status: response.status >= 500 ? 'error' : 'warning', detail: `${response.status}` }
        } catch (error) {
          return { ...probe, status: 'error', detail: error instanceof Error ? error.message : 'unreachable' }
        }
      }),
    )

    try {
      const response = await fetchWithTimeout(`${API_BASE_URL}/auth/session-audit?limit=12`, accessToken)
      const payload = (await response.json().catch(() => null)) as unknown
      setAudits(extractArray(payload) as SessionAudit[])
    } catch {
      setAudits([])
    }

    setServices(serviceResults)
    setLastUpdated(new Date())
    setIsLoading(false)
  }, [accessToken])

  React.useEffect(() => {
    void load()
  }, [load])

  const okCount = services.filter((service) => service.status === 'ok').length
  const issueCount = services.filter((service) => service.status !== 'ok').length

  return (
    <div className='admin-monitoring-page'>
      <header className='admin-monitoring-hero'>
        <div>
          <p className='admin-monitoring-eyebrow'>VNALO Admin</p>
          <h1>{labels.title}</h1>
          <p>{labels.subtitle}</p>
        </div>
        <button type='button' onClick={() => void load()} disabled={isLoading}>{isLoading ? '...' : labels.refresh}</button>
      </header>

      {!isLikelyAdmin(user?.email) ? <div className='admin-monitoring-note'>{labels.accessNote}</div> : null}

      <section className='admin-monitoring-grid'>
        <article className='admin-monitoring-card'>
          <span>{language === 'vi' ? 'Dịch vụ OK' : 'Healthy services'}</span>
          <strong>{okCount}/{services.length || 4}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>{language === 'vi' ? 'Cần kiểm tra' : 'Needs attention'}</span>
          <strong>{issueCount}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>{language === 'vi' ? 'Sự kiện phiên' : 'Session events'}</span>
          <strong>{audits.length}</strong>
        </article>
      </section>

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.serviceHealth}</h2>
          {lastUpdated ? <span>{labels.updated}: {lastUpdated.toLocaleTimeString()}</span> : null}
        </div>
        <div className='admin-monitoring-service-list'>
          {services.map((service) => (
            <div className='admin-monitoring-service-row' key={service.name}>
              <span className={`admin-monitoring-dot ${service.status}`} />
              <div>
                <strong>{service.name}</strong>
                <small>{service.url}</small>
              </div>
              <code>{service.detail}</code>
            </div>
          ))}
        </div>
      </section>

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.sessionAudits}</h2>
        </div>
        {audits.length === 0 ? (
          <p className='admin-monitoring-empty'>{labels.noAudits}</p>
        ) : (
          <div className='admin-monitoring-event-list'>
            {audits.map((audit, index) => (
              <div className='admin-monitoring-event-row' key={audit.auditId ?? index}>
                <strong>{audit.eventType ?? `${audit.fromStatus ?? '-'} → ${audit.toStatus ?? '-'}`}</strong>
                <span>{audit.platform ?? 'WEB'} · {audit.reason ?? 'session update'}</span>
                <time>{audit.createdAt ? new Date(audit.createdAt).toLocaleString() : '-'}</time>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className='admin-monitoring-panel'>
        <h2>{labels.dataGuard}</h2>
        <ul className='admin-monitoring-guardrails'>
          <li>{language === 'vi' ? 'Không hiển thị mật khẩu, OTP, token, nội dung tin nhắn riêng tư hoặc embedding khuôn mặt.' : 'Do not expose passwords, OTPs, tokens, private message content, or face embeddings.'}</li>
          <li>{language === 'vi' ? 'Chỉ log metadata tối thiểu cần cho vận hành, bảo mật và điều tra lỗi.' : 'Log only the minimum metadata needed for operations, security, and debugging.'}</li>
          <li>{language === 'vi' ? 'Các API admin production cần kiểm tra role phía backend, không chỉ ẩn UI.' : 'Production admin APIs must enforce roles on the backend, not only hide UI.'}</li>
        </ul>
      </section>
    </div>
  )
}
