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
  sessionType?: string
  trustLevel?: string
  platform?: string
  deviceName?: string
  deviceIdMasked?: string
  detail?: string
  createdAt?: string
}

type MonitoringSummary = {
  generatedAt?: string
  accessMode?: string
  accounts?: {
    total?: number
    active?: number
    locked?: number
    disabled?: number
    pendingVerification?: number
    withFailedLogins?: number
    failedLoginAttemptsTotal?: number
  }
  sessions?: {
    activeRefreshTokens?: number
    revokedLast24Hours?: number
    activeMobileSessions?: number
  }
  audits?: {
    totalEvents?: number
    last24Hours?: number
    loginSuccessLast24Hours?: number
    loginFailureLast24Hours?: number
    logoutLast24Hours?: number
    qrApprovalLast24Hours?: number
  }
  otp?: {
    last24Hours?: number
    registerLast24Hours?: number
    resetPasswordLast24Hours?: number
    verifiedLast24Hours?: number
  }
  ai?: {
    messagesLast24Hours?: number
    userPromptsLast24Hours?: number
    assistantRepliesLast24Hours?: number
    distinctActiveUsersLast24Hours?: number
  }
  qr?: {
    createdLast24Hours?: number
    pendingNow?: number
    approvedLast24Hours?: number
    consumedLast24Hours?: number
    rejectedTotal?: number
  }
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

function extractData<T>(payload: unknown): T | null {
  if (!payload || typeof payload !== 'object') return null
  const obj = payload as Record<string, unknown>
  return (obj.data ?? payload) as T
}


export function AdminMonitoringPage() {
  const { language } = useLanguage()
  const { user, accessToken } = useAuth()
  const adminMonitoringEmails = (import.meta.env.VITE_ADMIN_MONITORING_ALLOWED_EMAILS ?? '')
    .split(',')
    .map((email: string) => email.trim().toLowerCase())
    .filter(Boolean)
  const canRequestMonitoring = Boolean(user?.email && adminMonitoringEmails.includes(user.email.toLowerCase()))
  const [services, setServices] = React.useState<ServiceProbe[]>([])
  const [summary, setSummary] = React.useState<MonitoringSummary | null>(null)
  const [audits, setAudits] = React.useState<SessionAudit[]>([])
  const [isLoading, setIsLoading] = React.useState(true)
  const [lastUpdated, setLastUpdated] = React.useState<Date | null>(null)
  const labels = language === 'vi'
    ? {
        title: 'Giám sát vận hành',
        subtitle: 'Theo dõi trạng thái dịch vụ, sự kiện phiên đăng nhập và các rủi ro cần kiểm tra mà không hiển thị dữ liệu nhạy cảm.',
        accessNote: 'Trang này yêu cầu quyền admin allowlist phía backend và chỉ hiển thị metadata.',
        refresh: 'Làm mới',
        serviceHealth: 'Trạng thái dịch vụ',
        sessionAudits: 'Sự kiện phiên gần đây',
        summary: 'Tổng quan 24 giờ',
        dataGuard: 'Nguyên tắc dữ liệu an toàn',
        noAudits: 'Chưa có sự kiện phiên hoặc API chưa trả dữ liệu.',
        updated: 'Cập nhật',
      }
    : {
        title: 'Operations Monitoring',
        subtitle: 'Monitor service status, session events, and risks without exposing sensitive user data.',
        accessNote: 'This dashboard requires backend admin allowlist access and only displays metadata.',
        refresh: 'Refresh',
        serviceHealth: 'Service health',
        sessionAudits: 'Recent session events',
        summary: '24-hour summary',
        dataGuard: 'Safe data guardrails',
        noAudits: 'No session events yet or the API returned no data.',
        updated: 'Updated',
      }

  const load = React.useCallback(async () => {
    if (!canRequestMonitoring) {
      setServices([])
      setSummary(null)
      setAudits([])
      setLastUpdated(null)
      setIsLoading(false)
      return
    }

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
          if (response.ok) return { ...probe, status: 'ok', detail: `${response.status}` }
          return { ...probe, status: response.status >= 500 ? 'error' : 'warning', detail: `${response.status}` }
        } catch (error) {
          return { ...probe, status: 'error', detail: error instanceof Error ? error.message : 'unreachable' }
        }
      }),
    )

    try {
      const [summaryResponse, eventsResponse] = await Promise.all([
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/summary`, accessToken),
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events?limit=12`, accessToken),
      ])
      const summaryPayload = (await summaryResponse.json().catch(() => null)) as unknown
      const eventsPayload = (await eventsResponse.json().catch(() => null)) as unknown
      setSummary(extractData<MonitoringSummary>(summaryPayload))
      setAudits(extractArray(eventsPayload) as SessionAudit[])
    } catch {
      setSummary(null)
      setAudits([])
    }

    setServices(serviceResults)
    setLastUpdated(new Date())
    setIsLoading(false)
  }, [accessToken, canRequestMonitoring])

  React.useEffect(() => {
    void load()
  }, [load])

  const okCount = services.filter((service) => service.status === 'ok').length
  const issueCount = services.filter((service) => service.status !== 'ok').length
  const summaryCards = [
    { label: language === 'vi' ? 'Tài khoản hoạt động' : 'Active accounts', value: summary?.accounts?.active ?? 0 },
    { label: language === 'vi' ? 'Refresh token còn hiệu lực' : 'Active refresh tokens', value: summary?.sessions?.activeRefreshTokens ?? 0 },
    { label: language === 'vi' ? 'AI messages 24h' : 'AI messages 24h', value: summary?.ai?.messagesLast24Hours ?? 0 },
    { label: language === 'vi' ? 'Login fail 24h' : 'Login failures 24h', value: summary?.audits?.loginFailureLast24Hours ?? 0 },
    { label: language === 'vi' ? 'OTP xác thực 24h' : 'OTP verified 24h', value: summary?.otp?.verifiedLast24Hours ?? 0 },
    { label: language === 'vi' ? 'QR pending' : 'QR pending', value: summary?.qr?.pendingNow ?? 0 },
  ]

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

      {!canRequestMonitoring ? <div className='admin-monitoring-note admin-monitoring-denied'>{labels.accessNote}</div> : null}
      {summary?.accessMode ? <div className='admin-monitoring-note'>Access mode: {summary.accessMode}</div> : null}

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

      <section className='admin-monitoring-grid'>
        {summaryCards.map((card) => (
          <article className='admin-monitoring-card' key={card.label}>
            <span>{card.label}</span>
            <strong>{card.value}</strong>
          </article>
        ))}
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
          <h2>{labels.summary}</h2>
          {summary?.generatedAt ? <span>{new Date(summary.generatedAt).toLocaleString()}</span> : null}
        </div>
        <div className='admin-monitoring-event-list'>
          <div className='admin-monitoring-event-row'>
            <strong>{language === 'vi' ? 'Tổng tài khoản' : 'Total accounts'}</strong>
            <span>{language === 'vi' ? 'Active / locked / disabled / pending' : 'Active / locked / disabled / pending'}</span>
            <time>{summary?.accounts?.total ?? 0}</time>
          </div>
          <div className='admin-monitoring-event-row'>
            <strong>{language === 'vi' ? 'Failed login count' : 'Failed login count'}</strong>
            <span>{language === 'vi' ? 'Tổng failed_login_count hiện tại' : 'Current accumulated failed_login_count'}</span>
            <time>{summary?.accounts?.failedLoginAttemptsTotal ?? 0}</time>
          </div>
          <div className='admin-monitoring-event-row'>
            <strong>{language === 'vi' ? 'QR approved 24h' : 'QR approved 24h'}</strong>
            <span>{language === 'vi' ? 'Lượt QR approval gần đây' : 'Recent QR approvals'}</span>
            <time>{summary?.qr?.approvedLast24Hours ?? 0}</time>
          </div>
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
                <strong>{audit.eventType ?? 'SESSION_EVENT'}</strong>
                <span>{audit.platform ?? 'WEB'} · {audit.deviceName ?? 'Unknown device'} · {audit.detail ?? 'session update'}</span>
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
