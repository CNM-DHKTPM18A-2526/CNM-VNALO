import React from 'react'

import { API_BASE_URL, AI_API_URL, MEDIA_API_URL, MESSAGE_API_URL } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/admin-monitoring.css'

type MonitorStatus = 'ok' | 'warning' | 'error'

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

function resolveApiError(response: Response, fallback: string) {
  if (response.status === 401) return 'Authentication required. Please sign in again.'
  if (response.status === 403) return 'Access denied by backend allowlist. Check ADMIN_MONITORING_ALLOWED_EMAILS.'
  return `${fallback} (${response.status})`
}

export function AdminMonitoringPage() {
  const { language } = useLanguage()
  const { user, accessToken } = useAuth()
  const adminMonitoringEmails = (import.meta.env.VITE_ADMIN_MONITORING_ALLOWED_EMAILS ?? '')
    .split(',')
    .map((email: string) => email.trim().toLowerCase())
    .filter(Boolean)
  const hasUiHintAccess = Boolean(user?.email && adminMonitoringEmails.includes(user.email.toLowerCase()))
  const [services, setServices] = React.useState<ServiceProbe[]>([])
  const [summary, setSummary] = React.useState<MonitoringSummary | null>(null)
  const [audits, setAudits] = React.useState<SessionAudit[]>([])
  const [isLoading, setIsLoading] = React.useState(true)
  const [lastUpdated, setLastUpdated] = React.useState<Date | null>(null)
  const [monitoringError, setMonitoringError] = React.useState<string | null>(null)
  const labels = language === 'vi'
    ? {
        title: 'Giám sát vận hành',
        subtitle: 'Theo dõi trạng thái dịch vụ, sự kiện phiên đăng nhập và rủi ro vận hành mà không hiển thị dữ liệu nhạy cảm.',
        accessNote: 'Trang này yêu cầu email nằm trong allowlist admin ở backend. UI chỉ là gợi ý, backend vẫn là lớp kiểm soát chính.',
        refresh: 'Làm mới',
        serviceHealth: 'Trạng thái dịch vụ',
        sessionAudits: 'Sự kiện phiên gần đây',
        summary: 'Tổng quan 24 giờ',
        dataGuard: 'Nguyên tắc dữ liệu an toàn',
        noAudits: 'Chưa có sự kiện phiên hoặc API chưa trả dữ liệu.',
        updated: 'Cập nhật',
        healthyServices: 'Dịch vụ OK',
        needsAttention: 'Cần kiểm tra',
        sessionEvents: 'Sự kiện phiên',
        totalAccounts: 'Tổng tài khoản',
        failedLoginCount: 'Failed login count',
        failedLoginDetail: 'Tổng failed_login_count hiện tại',
        qrApproved: 'QR approved 24h',
        qrApprovedDetail: 'Lượt QR approval gần đây',
        activeAccounts: 'Tài khoản hoạt động',
        activeRefreshTokens: 'Refresh token còn hiệu lực',
        loginFailures: 'Login fail 24h',
        otpVerified: 'OTP xác thực 24h',
      }
    : {
        title: 'Operations Monitoring',
        subtitle: 'Monitor service status, session events, and operational risks without exposing sensitive user data.',
        accessNote: 'This page requires backend admin allowlist access. The UI hint is not the security boundary; the backend is authoritative.',
        refresh: 'Refresh',
        serviceHealth: 'Service health',
        sessionAudits: 'Recent session events',
        summary: '24-hour summary',
        dataGuard: 'Safe data guardrails',
        noAudits: 'No session events yet or the API returned no data.',
        updated: 'Updated',
        healthyServices: 'Healthy services',
        needsAttention: 'Needs attention',
        sessionEvents: 'Session events',
        totalAccounts: 'Total accounts',
        failedLoginCount: 'Failed login count',
        failedLoginDetail: 'Current accumulated failed_login_count',
        qrApproved: 'QR approved 24h',
        qrApprovedDetail: 'Recent QR approvals',
        activeAccounts: 'Active accounts',
        activeRefreshTokens: 'Active refresh tokens',
        loginFailures: 'Login failures 24h',
        otpVerified: 'OTP verified 24h',
      }

  const load = React.useCallback(async () => {
    if (!accessToken) {
      setServices([])
      setSummary(null)
      setAudits([])
      setLastUpdated(null)
      setMonitoringError(null)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setMonitoringError(null)
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
      if (!summaryResponse.ok) throw new Error(resolveApiError(summaryResponse, 'Monitoring summary failed'))
      if (!eventsResponse.ok) throw new Error(resolveApiError(eventsResponse, 'Monitoring events failed'))

      const summaryPayload = (await summaryResponse.json().catch(() => null)) as unknown
      const eventsPayload = (await eventsResponse.json().catch(() => null)) as unknown
      setSummary(extractData<MonitoringSummary>(summaryPayload))
      setAudits(extractArray(eventsPayload) as SessionAudit[])
    } catch (error) {
      setSummary(null)
      setAudits([])
      setMonitoringError(error instanceof Error ? error.message : 'Monitoring API unavailable')
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
  const summaryCards = [
    { label: labels.activeAccounts, value: summary?.accounts?.active ?? 0 },
    { label: labels.activeRefreshTokens, value: summary?.sessions?.activeRefreshTokens ?? 0 },
    { label: 'AI messages 24h', value: summary?.ai?.messagesLast24Hours ?? 0 },
    { label: labels.loginFailures, value: summary?.audits?.loginFailureLast24Hours ?? 0 },
    { label: labels.otpVerified, value: summary?.otp?.verifiedLast24Hours ?? 0 },
    { label: 'QR pending', value: summary?.qr?.pendingNow ?? 0 },
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

      {!hasUiHintAccess ? <div className='admin-monitoring-note admin-monitoring-denied'>{labels.accessNote}</div> : null}
      {monitoringError ? <div className='admin-monitoring-note admin-monitoring-error'>{monitoringError}</div> : null}
      {summary?.accessMode ? <div className='admin-monitoring-note'>Access mode: {summary.accessMode}</div> : null}

      <section className='admin-monitoring-grid'>
        <article className='admin-monitoring-card'>
          <span>{labels.healthyServices}</span>
          <strong>{okCount}/{services.length || 4}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>{labels.needsAttention}</span>
          <strong>{issueCount}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>{labels.sessionEvents}</span>
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
            <strong>{labels.totalAccounts}</strong>
            <span>Active / locked / disabled / pending</span>
            <time>{summary?.accounts?.total ?? 0}</time>
          </div>
          <div className='admin-monitoring-event-row'>
            <strong>{labels.failedLoginCount}</strong>
            <span>{labels.failedLoginDetail}</span>
            <time>{summary?.accounts?.failedLoginAttemptsTotal ?? 0}</time>
          </div>
          <div className='admin-monitoring-event-row'>
            <strong>{labels.qrApproved}</strong>
            <span>{labels.qrApprovedDetail}</span>
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
                <span>{audit.platform ?? 'WEB'} - {audit.deviceName ?? 'Unknown device'} - {audit.detail ?? 'session update'}</span>
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
          <li>{language === 'vi' ? 'API admin production phải kiểm tra quyền ở backend, không chỉ ẩn UI.' : 'Production admin APIs must enforce roles on the backend, not only hide UI.'}</li>
        </ul>
      </section>
    </div>
  )
}