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

type EventTrendPoint = {
  bucket: string
  total: number
  warning: number
  error: number
}

type EventPage = {
  page: number
  limit: number
  hasMore: boolean
  items: SessionAudit[]
}

type AdminRoleAssignment = {
  accountId?: string
  email: string
  roleCode: string
  grantedAt?: string
  grantedBy?: string
  expiresAt?: string | null
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
const roleOptions = ['SUPER_ADMIN', 'ADMIN_MONITORING', 'ADMIN_RBAC_MANAGER']

async function fetchWithTimeout(url: string, token?: string | null, init: RequestInit = {}) {
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), timeoutMs)
  const headers = new Headers(init.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  try {
    return await fetch(url, {
      ...init,
      signal: controller.signal,
      headers,
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
  if (response.status === 403) return 'Access denied by backend RBAC. Check admin role/permission assignments.'
  return `${fallback} (${response.status})`
}

function buildEventsQuery(filters: { windowHours: number; limit: number; page: number; eventType: string; platform: string }) {
  const params = new URLSearchParams({
    windowHours: String(filters.windowHours),
    limit: String(filters.limit),
    page: String(filters.page),
  })
  if (filters.eventType !== 'ALL') params.set('eventType', filters.eventType)
  if (filters.platform !== 'ALL') params.set('platform', filters.platform)
  return params.toString()
}

function buildTrendQuery(filters: { windowHours: number; eventType: string; platform: string }) {
  const params = new URLSearchParams({ windowHours: String(filters.windowHours) })
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

function formatBucketLabel(value: string, language: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  return language === 'vi'
    ? date.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' })
    : date.toLocaleString('en-US', { hour: '2-digit', minute: '2-digit', month: '2-digit', day: '2-digit' })
}

function toCsv(rows: SessionAudit[]) {
  const headers = ['created_at', 'event_type', 'severity', 'platform', 'device_name', 'device_id_masked', 'detail']
  const escape = (input: string) => `"${input.replaceAll('"', '""')}"`
  const body = rows.map((row) => [
    row.createdAt ?? '',
    row.eventType ?? '',
    row.severity ?? 'info',
    row.platform ?? '',
    row.deviceName ?? '',
    row.deviceIdMasked ?? '',
    row.detail ?? '',
  ].map((value) => escape(value)).join(','))
  return [headers.join(','), ...body].join('\n')
}

function downloadCsv(csv: string, filename: string) {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const link = document.createElement('a')
  const url = URL.createObjectURL(blob)
  link.href = url
  link.setAttribute('download', filename)
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

function TrendBars({ points, language }: { points: EventTrendPoint[]; language: string }) {
  if (points.length === 0) return <p className='admin-monitoring-empty'>{language === 'vi' ? 'Chưa có dữ liệu trend.' : 'No trend data yet.'}</p>
  const maxValue = Math.max(...points.map((point) => point.total), 1)

  return (
    <div className='admin-monitoring-trend-list'>
      {points.map((point, index) => {
        const height = Math.max((point.total / maxValue) * 100, 4)
        return (
          <div className='admin-monitoring-trend-item' key={`${point.bucket}-${index}`}>
            <div className='admin-monitoring-trend-bar-wrap'>
              <div className='admin-monitoring-trend-bar' style={{ height: `${height}%` }} />
            </div>
            <strong>{point.total}</strong>
            <small>{formatBucketLabel(point.bucket, language)}</small>
          </div>
        )
      })}
    </div>
  )
}

export function AdminMonitoringPage() {
  const { language } = useLanguage()
  const { user, accessToken } = useAuth()
  const hasUiHintAccess = Boolean(user?.email)

  const [services, setServices] = React.useState<ServiceProbe[]>([])
  const [summary, setSummary] = React.useState<MonitoringSummary | null>(null)
  const [audits, setAudits] = React.useState<SessionAudit[]>([])
  const [trend, setTrend] = React.useState<EventTrendPoint[]>([])
  const [isLoading, setIsLoading] = React.useState(true)
  const [lastUpdated, setLastUpdated] = React.useState<Date | null>(null)
  const [monitoringError, setMonitoringError] = React.useState<string | null>(null)
  const [windowHours, setWindowHours] = React.useState(24)
  const [selectedEventType, setSelectedEventType] = React.useState('ALL')
  const [selectedPlatform, setSelectedPlatform] = React.useState('ALL')
  const [autoRefresh, setAutoRefresh] = React.useState(true)
  const [page, setPage] = React.useState(0)
  const [hasMore, setHasMore] = React.useState(false)
  const [pageLimit] = React.useState(20)
  const [roleAssignments, setRoleAssignments] = React.useState<AdminRoleAssignment[]>([])
  const [isRbacLoading, setIsRbacLoading] = React.useState(false)
  const [rbacError, setRbacError] = React.useState<string | null>(null)
  const [rbacMessage, setRbacMessage] = React.useState<string | null>(null)
  const [rbacEmail, setRbacEmail] = React.useState('')
  const [rbacRole, setRbacRole] = React.useState('ADMIN_MONITORING')
  const [rbacExpiresAt, setRbacExpiresAt] = React.useState('')

  const labels = language === 'vi'
    ? {
        title: 'Giám sát vận hành',
        subtitle: 'Theo dõi sức khỏe dịch vụ, hành vi đăng nhập và tín hiệu rủi ro bằng metadata an toàn.',
        accessNote: 'Trang này yêu cầu quyền ADMIN_MONITORING_VIEW trong RBAC. Backend là lớp kiểm soát quyền bắt buộc.',
        refresh: 'Làm mới',
        refreshing: 'Đang tải...',
        exportCsv: 'Xuất CSV',
        serviceHealth: 'Trạng thái dịch vụ',
        sessionAudits: 'Sự kiện gần đây',
        summary: 'Tổng quan',
        trend: 'Xu hướng sự kiện',
        dataGuard: 'Nguyên tắc dữ liệu an toàn',
        healthyServices: 'Dịch vụ ổn định',
        needsAttention: 'Cần chú ý',
        sessionEvents: 'Sự kiện đăng nhập',
        updated: 'Cập nhật',
        noAudits: 'Chưa có sự kiện phù hợp với bộ lọc hiện tại.',
        totalAccounts: 'Tổng tài khoản',
        failedLoginCount: 'Tổng số lần đăng nhập lỗi',
        failedLoginDetail: 'Theo dõi rủi ro brute-force và lockout',
        qrApproved: 'QR được duyệt',
        qrApprovedDetail: 'Số phiên QR được duyệt trong khung thời gian đã chọn',
        consentFresh: 'Consent mới',
        activeAccounts: 'Tài khoản hoạt động',
        activeRefreshTokens: 'Refresh token hoạt động',
        loginFailures: 'Đăng nhập lỗi',
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
        previousPage: 'Trang trước',
        nextPage: 'Trang sau',
        page: 'Trang',
        rbacTitle: 'Quản trị quyền admin',
        rbacSubtitle: 'Cấp hoặc thu hồi vai trò vận hành bằng RBAC ở backend.',
        rbacEmail: 'Email tài khoản',
        rbacRole: 'Vai trò',
        rbacExpiresAt: 'Hết hạn (tùy chọn)',
        grantRole: 'Cấp quyền',
        revokeRole: 'Thu hồi',
        activeAssignments: 'Phân quyền hiện tại',
        noAssignments: 'Chưa có phân quyền admin nào.',
        expiresNever: 'Không hết hạn',
        grantedAt: 'Cấp lúc',
      }
    : {
        title: 'Operations Monitoring',
        subtitle: 'Track service health, sign-in behavior, and operational risk signals without exposing sensitive data.',
        accessNote: 'This page requires ADMIN_MONITORING_VIEW in backend RBAC. Authorization is enforced by the API, not by the UI.',
        refresh: 'Refresh',
        refreshing: 'Refreshing...',
        exportCsv: 'Export CSV',
        serviceHealth: 'Service health',
        sessionAudits: 'Recent events',
        summary: 'Overview',
        trend: 'Event trend',
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
        previousPage: 'Previous page',
        nextPage: 'Next page',
        page: 'Page',
        rbacTitle: 'Admin access control',
        rbacSubtitle: 'Grant or revoke operational roles through backend RBAC.',
        rbacEmail: 'Account email',
        rbacRole: 'Role',
        rbacExpiresAt: 'Expires at (optional)',
        grantRole: 'Grant role',
        revokeRole: 'Revoke',
        activeAssignments: 'Active assignments',
        noAssignments: 'No admin assignments yet.',
        expiresNever: 'Never expires',
        grantedAt: 'Granted at',
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
      const eventsQuery = buildEventsQuery({
        windowHours,
        limit: pageLimit,
        page,
        eventType: selectedEventType,
        platform: selectedPlatform,
      })
      const trendQuery = buildTrendQuery({
        windowHours,
        eventType: selectedEventType,
        platform: selectedPlatform,
      })

      const [summaryResponse, eventsResponse, trendResponse] = await Promise.all([
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/summary?windowHours=${windowHours}`, accessToken),
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events?${eventsQuery}`, accessToken),
        fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events/trend?${trendQuery}`, accessToken),
      ])
      if (!summaryResponse.ok) throw new Error(resolveApiError(summaryResponse, 'Monitoring summary failed'))
      if (!eventsResponse.ok) throw new Error(resolveApiError(eventsResponse, 'Monitoring events failed'))
      if (!trendResponse.ok) throw new Error(resolveApiError(trendResponse, 'Monitoring trend failed'))

      const summaryPayload = (await summaryResponse.json().catch(() => null)) as unknown
      const eventsPayload = (await eventsResponse.json().catch(() => null)) as unknown
      const trendPayload = (await trendResponse.json().catch(() => null)) as unknown

      const eventPage = extractData<EventPage>(eventsPayload)
      setSummary(extractData<MonitoringSummary>(summaryPayload))
      setAudits(eventPage?.items ?? (extractArray(eventsPayload) as SessionAudit[]))
      setHasMore(Boolean(eventPage?.hasMore))
      setTrend((extractArray(trendPayload) as EventTrendPoint[]).slice(-24))
    } catch (error) {
      setSummary(null)
      setAudits([])
      setTrend([])
      setHasMore(false)
      setMonitoringError(error instanceof Error ? error.message : 'Monitoring API unavailable')
    }

    setServices(serviceResults)
    setLastUpdated(new Date())
    setIsLoading(false)
  }, [accessToken, page, pageLimit, selectedEventType, selectedPlatform, windowHours])
  const loadRbacAssignments = React.useCallback(async () => {
    setIsRbacLoading(true)
    setRbacError(null)
    try {
      const response = await fetchWithTimeout(`${API_BASE_URL}/admin/rbac/assignments`, accessToken)
      const payload = (await response.json().catch(() => null)) as unknown
      if (!response.ok) throw new Error(resolveApiError(response, 'RBAC assignments failed'))
      setRoleAssignments(extractArray(payload) as AdminRoleAssignment[])
    } catch (error) {
      setRoleAssignments([])
      setRbacError(error instanceof Error ? error.message : 'RBAC API unavailable')
    } finally {
      setIsRbacLoading(false)
    }
  }, [accessToken])

  const handleGrantRole = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsRbacLoading(true)
    setRbacError(null)
    setRbacMessage(null)
    try {
      const response = await fetchWithTimeout(`${API_BASE_URL}/admin/rbac/assignments`, accessToken, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: rbacEmail.trim(),
          roleCode: rbacRole,
          expiresAt: rbacExpiresAt ? new Date(rbacExpiresAt).toISOString() : null,
        }),
      })
      if (!response.ok) throw new Error(resolveApiError(response, 'Grant role failed'))
      setRbacMessage(language === 'vi' ? 'Đã cập nhật phân quyền.' : 'Role assignment updated.')
      setRbacEmail('')
      setRbacExpiresAt('')
      await loadRbacAssignments()
    } catch (error) {
      setRbacError(error instanceof Error ? error.message : 'Grant role failed')
    } finally {
      setIsRbacLoading(false)
    }
  }

  const handleRevokeRole = async (assignment: AdminRoleAssignment) => {
    setIsRbacLoading(true)
    setRbacError(null)
    setRbacMessage(null)
    try {
      const response = await fetchWithTimeout(`${API_BASE_URL}/admin/rbac/assignments`, accessToken, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: assignment.email, roleCode: assignment.roleCode }),
      })
      if (!response.ok) throw new Error(resolveApiError(response, 'Revoke role failed'))
      setRbacMessage(language === 'vi' ? 'Đã thu hồi phân quyền.' : 'Role assignment revoked.')
      await loadRbacAssignments()
    } catch (error) {
      setRbacError(error instanceof Error ? error.message : 'Revoke role failed')
    } finally {
      setIsRbacLoading(false)
    }
  }

  React.useEffect(() => {
    void load()
  }, [load])

  React.useEffect(() => {
    void loadRbacAssignments()
  }, [loadRbacAssignments])

  React.useEffect(() => {
    if (!autoRefresh) return undefined
    const timer = window.setInterval(() => {
      void load()
    }, 30000)
    return () => window.clearInterval(timer)
  }, [autoRefresh, load])

  React.useEffect(() => {
    setPage(0)
  }, [windowHours, selectedEventType, selectedPlatform])

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

  const handleExportCsv = () => {
    if (audits.length === 0) return
    const csv = toCsv(audits)
    const stamp = new Date().toISOString().replaceAll(':', '-')
    downloadCsv(csv, `monitoring-events-page-${page + 1}-${stamp}.csv`)
  }

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
          <div className='admin-monitoring-action-row'>
            <button type='button' onClick={handleExportCsv} disabled={audits.length === 0}>{labels.exportCsv}</button>
            <button type='button' onClick={() => void load()} disabled={isLoading}>{isLoading ? labels.refreshing : labels.refresh}</button>
          </div>
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

      <section className='admin-monitoring-panel admin-monitoring-rbac-panel'>
        <div className='admin-monitoring-panel-title'>
          <div>
            <h2>{labels.rbacTitle}</h2>
            <span>{labels.rbacSubtitle}</span>
          </div>
          <button className='admin-monitoring-secondary-button' type='button' onClick={() => void loadRbacAssignments()} disabled={isRbacLoading}>
            {isRbacLoading ? labels.refreshing : labels.refresh}
          </button>
        </div>
        {rbacError ? <div className='admin-monitoring-note admin-monitoring-error'>{rbacError}</div> : null}
        {rbacMessage ? <div className='admin-monitoring-note admin-monitoring-success'>{rbacMessage}</div> : null}
        <form className='admin-monitoring-rbac-form' onSubmit={handleGrantRole}>
          <label>
            <span>{labels.rbacEmail}</span>
            <input type='email' value={rbacEmail} onChange={(event) => setRbacEmail(event.target.value)} placeholder='admin@vnalo.fit' required />
          </label>
          <label>
            <span>{labels.rbacRole}</span>
            <select value={rbacRole} onChange={(event) => setRbacRole(event.target.value)}>
              {roleOptions.map((role) => <option key={role} value={role}>{role}</option>)}
            </select>
          </label>
          <label>
            <span>{labels.rbacExpiresAt}</span>
            <input type='datetime-local' value={rbacExpiresAt} onChange={(event) => setRbacExpiresAt(event.target.value)} />
          </label>
          <button type='submit' disabled={isRbacLoading || !rbacEmail.trim()}>{labels.grantRole}</button>
        </form>
        <div className='admin-monitoring-rbac-list' aria-label={labels.activeAssignments}>
          {roleAssignments.length === 0 ? (
            <p className='admin-monitoring-empty'>{labels.noAssignments}</p>
          ) : roleAssignments.map((assignment) => (
            <article className='admin-monitoring-rbac-row' key={`${assignment.email}-${assignment.roleCode}`}>
              <div>
                <strong>{assignment.email}</strong>
                <span>{assignment.roleCode}</span>
              </div>
              <div>
                <small>{labels.grantedAt}</small>
                <time>{assignment.grantedAt ? new Date(assignment.grantedAt).toLocaleString() : '-'}</time>
              </div>
              <div>
                <small>{labels.rbacExpiresAt}</small>
                <time>{assignment.expiresAt ? new Date(assignment.expiresAt).toLocaleString() : labels.expiresNever}</time>
              </div>
              <button type='button' onClick={() => void handleRevokeRole(assignment)} disabled={isRbacLoading}>{labels.revokeRole}</button>
            </article>
          ))}
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
          <h2>{labels.trend}</h2>
          <span>{formatWindowLabel(windowHours, language)}</span>
        </div>
        <TrendBars points={trend} language={language} />
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
                  <span>{[audit.platform ?? 'WEB', audit.deviceName ?? 'Unknown device', audit.detail ?? 'session update'].join(' · ')}</span>
                </div>
                <div className='admin-monitoring-event-meta'>
                  <small>{audit.deviceIdMasked ?? 'N/A'}</small>
                  <time>{audit.createdAt ? new Date(audit.createdAt).toLocaleString() : '-'}</time>
                </div>
              </div>
            ))}
          </div>
        )}
        <div className='admin-monitoring-pagination'>
          <button type='button' onClick={() => setPage((value) => Math.max(0, value - 1))} disabled={page === 0 || isLoading}>{labels.previousPage}</button>
          <span>{labels.page} {page + 1}</span>
          <button type='button' onClick={() => setPage((value) => value + 1)} disabled={!hasMore || isLoading}>{labels.nextPage}</button>
        </div>
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
