import React from 'react'

import { API_BASE_URL, AI_API_URL, MEDIA_API_URL, MESSAGE_API_URL } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/admin-monitoring.css'

type MonitorStatus = 'ok' | 'warning' | 'error'
type EventSeverity = 'info' | 'warning' | 'error'

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
  severity?: EventSeverity
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
  consent?: {
    grantedTotal?: number
    termsTotal?: number
    privacyTotal?: number
    termsLast24Hours?: number
    privacyLast24Hours?: number
  }
}

const timeoutMs = 4500
const rangeOptions = [
  { value: 6, label: '6h' },
  { value: 24, label: '24h' },
  { value: 72, label: '72h' },
  { value: 168, label: '7d' },
]
const eventTypeOptions = ['ALL', 'LOGIN_SUCCESS', 'LOGIN_FAILED', 'QR_LOGIN_APPROVED', 'SESSION_REVOKED_LOGOUT', 'SESSION_REVOKED_LOGOUT_ALL']
const platformOptions = ['ALL', 'WEB', 'ANDROID', 'IOS']

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

function buildQuery(filters: { windowHours: number; limit: number; eventType: string; platform: string }) {
  const params = new URLSearchParams({
    windowHours: String(filters.windowHours),
    limit: String(filters.limit),
  })
  if (filters.eventType !== 'ALL') params.set('eventType', filters.eventType)
  if (filters.platform !== 'ALL') params.set('platform', filters.platform)
  return params.toString()
}

function formatWindowLabel(hours: number, language: string) {
  if (language === 'vi') {
    if (hours === 168) return '7 ngày gần nhất'
    return `${hours} giờ gần nhất`
  }
  if (hours === 168) return 'Last 7 days'
  return `Last ${hours} hours`
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
  const [windowHours, setWindowHours] = React.useState(24)
  const [selectedEventType, setSelectedEventType] = React.useState('ALL')
  const [selectedPlatform, setSelectedPlatform] = React.useState('ALL')
  const [autoRefresh, setAutoRefresh] = React.useState(true)

  const labels = language === 'vi'
    ? {
        title: 'Giám sát vận hành',
        subtitle: 'Theo dõi sức khỏe dịch vụ, hành vi đăng nhập và tín hiệu rủi ro mà không lộ dữ liệu nhạy cảm.',
        accessNote: 'Trang này yêu cầu email nằm trong allowlist admin ở backend. UI chỉ là gợi ý; backend mới là lớp kiểm soát thực sự.',
        refresh: 'Làm mới',
        refreshing: 'Đang tải...',
        serviceHealth: 'Trạng thái dịch vụ',
        sessionAudits: 'Sự kiện gần đây',
        summary: 'Tổng quan',
        dataGuard: 'Nguyên tắc dữ liệu an toàn',
        healthyServices: 'Dịch vụ khỏe mạnh',
        needsAttention: 'Cần chú ý',
        sessionEvents: 'Sự kiện đang hiển thị',
        updated: 'Cập nhật',
        noAudits: 'Chưa có sự kiện phù hợp với bộ lọc hiện tại.',
        totalAccounts: 'Tài khoản toàn hệ thống',
        failedLoginCount: 'Tổng số lần đăng nhập lỗi',
        failedLoginDetail: 'Theo dõi rủi ro brute-force và lockout',
        qrApproved: 'QR được duyệt',
        qrApprovedDetail: 'Số phiên QR duyệt trong khung thời gian đã chọn',
        consentFresh: 'Consent mới',
        activeAccounts: 'Tài khoản hoạt động',
        activeRefreshTokens: 'Refresh token hoạt động',
        loginFailures: 'Login lỗi',
        otpVerified: 'OTP xác thực',
        consentGranted: 'Consent đã cấp',
        filters: 'Bộ lọc',
        range: 'Khung thời gian',
        eventType: 'Loại sự kiện',
        platform: 'Nền tảng',
        autoRefresh: 'Tự làm mới 30s',
        accessMode: 'Chế độ truy cập',
        keySignals: 'Tín hiệu chính',
        serviceSummary: 'Tóm tắt dịch vụ',
        eventSummary: 'Tóm tắt sự kiện',
      }
    : {
        title: 'Operations Monitoring',
        subtitle: 'Track service health, sign-in behavior, and operational risk signals without exposing sensitive data.',
        accessNote: 'This page requires backend allowlist access. The UI hint is not a security boundary; the backend remains authoritative.',
        refresh: 'Refresh',
        refreshing: 'Refreshing...',
        serviceHealth: 'Service health',
        sessionAudits: 'Recent events',
        summary: 'Overview',
        dataGuard: 'Safe data guardrails',
        healthyServices: 'Healthy services',
        needsAttention: 'Needs attention',
        sessionEvents: 'Displayed events',
        updated: 'Updated',
        noAudits: 'No events match the current filters.',
        totalAccounts: 'Total accounts',
        failedLoginCount: 'Failed login attempts',
        failedLoginDetail: 'Watch brute-force and lockout pressure',
        qrApproved: 'QR approvals',
        qrApprovedDetail: 'QR sessions approved in the selected window',
        consentFresh: 'Fresh consent',
        activeAccounts: 'Active accounts',
        activeRefreshTokens: 'Active refresh tokens',
        loginFailures: 'Failed logins',
        otpVerified: 'Verified OTPs',
        consentGranted: 'Granted consent',
        filters: 'Filters',
        range: 'Time window',
        eventType: 'Event type',
        platform: 'Platform',
        autoRefresh: 'Auto-refresh every 30s',
        accessMode: 'Access mode',
        keySignals: 'Key signals',
        serviceSummary: 'Service summary',
        eventSummary: 'Event summary',
      }

  const load = React.useCallback(async () => {
    setIsLoading(true)
    setMonitoringError(null)

    const probes: ServiceProbe[] = [
      { name: 'core-service', url: `${API_BASE_URL}/actuator/health`, status: 'warning', detail: 'pending' },
      { name: 'message-service', url: `${MESSAGE_API_URL}/health`, status: 'warning', detail: 'pending' },
      { name: 'media-service', url: `${MEDIA_API_URL}/health`, status: 'warning', detail: 'pending' },
      { name: 'ai-service', url: `${AI_API_URL}/health`, status: 'warning', detail: 'pending' },
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
      const query = buildQuery({
        windowHours,
        limit: 20,
        eventType: selectedEventType,
        platform: selectedPlatform,
      })
      const [summaryResponse, eventsResponse] = await Promise.all([
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/summary?windowHours=${windowHours}`, accessToken),
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events?${query}`, accessToken),
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
  }, [accessToken, selectedEventType, selectedPlatform, windowHours])

  React.useEffect(() => {
    void load()
  }, [load])

  React.useEffect(() => {
    if (!autoRefresh) return undefined
    const timer = window.setInterval(() => {
      void load()
    }, 30000)
    return () => window.clearInterval(timer)
  }, [autoRefresh, load])

  const okCount = services.filter((service) => service.status === 'ok').length
  const issueCount = services.filter((service) => service.status !== 'ok').length
  const warningCount = audits.filter((audit) => audit.severity === 'warning').length
  const errorCount = audits.filter((audit) => audit.severity === 'error').length
  const summaryCards = [
    { label: labels.activeAccounts, value: summary?.accounts?.active ?? 0, tone: 'neutral' },
    { label: labels.activeRefreshTokens, value: summary?.sessions?.activeRefreshTokens ?? 0, tone: 'neutral' },
    { label: 'AI messages', value: summary?.ai?.messagesLast24Hours ?? 0, tone: 'neutral' },
    { label: labels.loginFailures, value: summary?.audits?.loginFailureLast24Hours ?? 0, tone: 'danger' },
    { label: labels.otpVerified, value: summary?.otp?.verifiedLast24Hours ?? 0, tone: 'neutral' },
    { label: labels.consentGranted, value: summary?.consent?.grantedTotal ?? 0, tone: 'neutral' },
    { label: 'QR pending', value: summary?.qr?.pendingNow ?? 0, tone: 'warning' },
  ]

  return (
    <div className='admin-monitoring-page'>
      <header className='admin-monitoring-hero'>
        <div>
          <p className='admin-monitoring-eyebrow'>VNALO Admin</p>
          <h1>{labels.title}</h1>
          <p>{labels.subtitle}</p>
        </div>
        <div className='admin-monitoring-hero-actions'>
          <label className='admin-monitoring-toggle'>
            <input type='checkbox' checked={autoRefresh} onChange={(event) => setAutoRefresh(event.target.checked)} />
            <span>{labels.autoRefresh}</span>
          </label>
          <button type='button' onClick={() => void load()} disabled={isLoading}>{isLoading ? labels.refreshing : labels.refresh}</button>
        </div>
      </header>

      {!hasUiHintAccess ? <div className='admin-monitoring-note admin-monitoring-denied'>{labels.accessNote}</div> : null}
      {monitoringError ? <div className='admin-monitoring-note admin-monitoring-error'>{monitoringError}</div> : null}

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.filters}</h2>
          <span>{formatWindowLabel(windowHours, language)}</span>
        </div>
        <div className='admin-monitoring-filters'>
          <label>
            <span>{labels.range}</span>
            <select value={windowHours} onChange={(event) => setWindowHours(Number(event.target.value))}>
              {rangeOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>
          <label>
            <span>{labels.eventType}</span>
            <select value={selectedEventType} onChange={(event) => setSelectedEventType(event.target.value)}>
              {eventTypeOptions.map((option) => <option key={option} value={option}>{option}</option>)}
            </select>
          </label>
          <label>
            <span>{labels.platform}</span>
            <select value={selectedPlatform} onChange={(event) => setSelectedPlatform(event.target.value)}>
              {platformOptions.map((option) => <option key={option} value={option}>{option}</option>)}
            </select>
          </label>
        </div>
      </section>

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
        <article className='admin-monitoring-card'>
          <span>Warnings</span>
          <strong>{warningCount}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>Errors</span>
          <strong>{errorCount}</strong>
        </article>
        <article className='admin-monitoring-card'>
          <span>{labels.accessMode}</span>
          <strong>{summary?.accessMode ?? 'N/A'}</strong>
        </article>
      </section>

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.keySignals}</h2>
          {lastUpdated ? <span>{labels.updated}: {lastUpdated.toLocaleTimeString()}</span> : null}
        </div>
        <div className='admin-monitoring-grid compact'>
          {summaryCards.map((card) => (
            <article className={`admin-monitoring-card tone-${card.tone}`} key={card.label}>
              <span>{card.label}</span>
              <strong>{card.value}</strong>
            </article>
          ))}
        </div>
      </section>

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.serviceHealth}</h2>
          <span>{labels.serviceSummary}</span>
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
            <time>{`${summary?.accounts?.active ?? 0} / ${summary?.accounts?.locked ?? 0} / ${summary?.accounts?.disabled ?? 0} / ${summary?.accounts?.pendingVerification ?? 0}`}</time>
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
          <div className='admin-monitoring-event-row'>
            <strong>{labels.consentFresh}</strong>
            <span>Terms / Privacy</span>
            <time>{`${summary?.consent?.termsLast24Hours ?? 0} / ${summary?.consent?.privacyLast24Hours ?? 0}`}</time>
          </div>
        </div>
      </section>

      <section className='admin-monitoring-panel'>
        <div className='admin-monitoring-panel-title'>
          <h2>{labels.sessionAudits}</h2>
          <span>{labels.eventSummary}</span>
        </div>
        {audits.length === 0 ? (
          <p className='admin-monitoring-empty'>{labels.noAudits}</p>
        ) : (
          <div className='admin-monitoring-event-list'>
            {audits.map((audit, index) => (
              <div className='admin-monitoring-event-row admin-monitoring-event-rich' key={audit.auditId ?? index}>
                <div className='admin-monitoring-event-main'>
                  <div className='admin-monitoring-event-heading'>
                    <strong>{audit.eventType ?? 'SESSION_EVENT'}</strong>
                    <span className={`admin-monitoring-severity ${audit.severity ?? 'info'}`}>{audit.severity ?? 'info'}</span>
                  </div>
                  <span>{audit.platform ?? 'WEB'} • {audit.deviceName ?? 'Unknown device'} • {audit.detail ?? 'session update'}</span>
                </div>
                <div className='admin-monitoring-event-meta'>
                  <small>{audit.deviceIdMasked ?? 'N/A'}</small>
                  <time>{audit.createdAt ? new Date(audit.createdAt).toLocaleString() : '-'}</time>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className='admin-monitoring-panel'>
        <h2>{labels.dataGuard}</h2>
        <ul className='admin-monitoring-guardrails'>
          <li>{language === 'vi' ? 'Không hiển thị mật khẩu, OTP, token, nội dung riêng tư hoặc embedding khuôn mặt.' : 'Do not expose passwords, OTPs, tokens, private content, or face embeddings.'}</li>
          <li>{language === 'vi' ? 'Chỉ hiển thị metadata tối thiểu phục vụ vận hành, bảo mật và điều tra lỗi.' : 'Expose only the minimum metadata needed for operations, security, and incident analysis.'}</li>
          <li>{language === 'vi' ? 'Phân quyền production phải tiếp tục được kiểm soát ở backend thay vì chỉ ẩn UI.' : 'Production authorization must remain backend-enforced instead of being UI-only.'}</li>
        </ul>
      </section>
    </div>
  )
}
