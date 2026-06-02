import React from 'react'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'

import { useAuth } from '../auth/useAuth'
import { useLanguage } from '../../shared/i18n/LanguageContext'
import type {
  AnalyticsOverviewResponse,
  AnalyticsDashboardResponse,
  DailyTrendPointResponse,
  TopActiveUserResponse,
  ActiveUserSummaryResponse,
  MonitoringSummary,
  SessionAudit,
  EventTrendPoint,
  EventPage,
  ServiceProbe,
  ReasonCountResponse,
  MessageTypeCountResponse,
  DateRangePreset,
} from './analytics.types'
import { dateRangeFromPreset } from './analytics.types'
import { analyticsFetchWithTimeout, extractAnalyticsData } from './analytics.client'
import { API_BASE_URL, AI_API_URL, MEDIA_API_URL, MESSAGE_API_URL } from '../../api.client'
import './analytics.css'

// ─── Utility ────────────────────────────────────────────────────────────────────

const FETCH_TIMEOUT = 10000

async function fetchWithTimeout(url: string, token?: string | null) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT)
  try {
    return await fetch(url, {
      signal: controller.signal,
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    })
  } finally {
    clearTimeout(timer)
  }
}

function extractData<T>(payload: unknown): T | null {
  if (!payload || typeof payload !== 'object') return null
  const obj = payload as Record<string, unknown>
  return (obj.data ?? payload) as T
}

function formatNumber(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M'
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K'
  return String(n)
}

function formatDate(iso: string, lang: string): string {
  const d = new Date(iso)
  if (lang === 'vi') {
    return d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' })
  }
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

function toCsv(rows: SessionAudit[]) {
  const headers = ['created_at', 'event_type', 'severity', 'platform', 'device_name', 'detail']
  const escape = (v: string) => `"${(v ?? '').replaceAll('"', '""')}"`
  const body = rows.map(r => [r.createdAt ?? '', r.eventType ?? '', r.severity ?? 'info', r.platform ?? '', r.deviceName ?? '', r.detail ?? ''].map(escape).join(','))
  return [headers.join(','), ...body].join('\n')
}

function downloadCsv(csv: string, filename: string) {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.setAttribute('download', filename)
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(link.href)
}

function SeverityBadge({ value }: { value: string }) {
  const cls = value === 'error' ? 'sev-error' : value === 'warning' ? 'sev-warn' : 'sev-info'
  return <span className={`sev-badge ${cls}`}>{value}</span>
}

function StatusDot({ status }: { status: ServiceProbe['status'] }) {
  return <span className={`status-dot ${status}`} />
}

// ─── Chart Colors ──────────────────────────────────────────────────────────────

const PIE_COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899']

// ─── Reusable KPI Card ─────────────────────────────────────────────────────────

function KpiCard({ label, value, sub, tone }: { label: string; value: string | number; sub?: string; tone?: 'neutral' | 'success' | 'danger' | 'warning' }) {
  return (
    <div className={`kpi-card tone-${tone ?? 'neutral'}`}>
      <span className="kpi-label">{label}</span>
      <strong className="kpi-value">{typeof value === 'number' ? formatNumber(value) : value}</strong>
      {sub && <small className="kpi-sub">{sub}</small>}
    </div>
  )
}

// ─── Custom Tooltip ─────────────────────────────────────────────────────────────

function ChartTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ name: string; value: number; color: string }>; label?: string; lang: string }) {
  if (!active || !payload?.length) return null
  return (
    <div className="chart-tooltip">
      <p className="tooltip-label">{label}</p>
      {payload.map((p, i) => (
        <p key={i} style={{ color: p.color }}>
          {p.name}: <strong>{formatNumber(p.value)}</strong>
        </p>
      ))}
    </div>
  )
}

// ─── Trend Area Chart ────────────────────────────────────────────────────────────

function TrendChart({ data, lang, height = 220 }: { data: DailyTrendPointResponse[]; lang: string; height?: number }) {
  if (!data?.length) return <div className="chart-empty">No data available</div>
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
        <defs>
          <linearGradient id="colorVal" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
            <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
        <XAxis
          dataKey="date"
          tickFormatter={v => formatDate(v, lang)}
          tick={{ fontSize: 11, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
          interval="preserveStartEnd"
        />
        <YAxis
          tick={{ fontSize: 11, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
          tickFormatter={formatNumber}
        />
        <Tooltip content={<ChartTooltip lang={lang} />} />
        <Area
          type="monotone"
          dataKey="value"
          stroke="#3b82f6"
          strokeWidth={2}
          fill="url(#colorVal)"
          dot={false}
          activeDot={{ r: 4, fill: '#3b82f6' }}
        />
      </AreaChart>
    </ResponsiveContainer>
  )
}

// ─── Multi-Series Line Chart ───────────────────────────────────────────────────

function MultiLineChart({
  data,
  lines,
  lang,
  height = 220,
}: {
  data: Record<string, string | number>[]
  lines: { dataKey: string; name: string; color: string }[]
  lang: string
  height?: number
}) {
  if (!data?.length) return <div className="chart-empty">No data available</div>
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
        <XAxis
          dataKey="date"
          tickFormatter={v => formatDate(v, lang)}
          tick={{ fontSize: 11, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
          interval="preserveStartEnd"
        />
        <YAxis
          tick={{ fontSize: 11, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
          tickFormatter={formatNumber}
        />
        <Tooltip content={<ChartTooltip lang={lang} />} />
        <Legend wrapperStyle={{ fontSize: 12 }} />
        {lines.map(l => (
          <Line
            key={l.dataKey}
            type="monotone"
            dataKey={l.dataKey}
            name={l.name}
            stroke={l.color}
            strokeWidth={2}
            dot={false}
            activeDot={{ r: 4 }}
          />
        ))}
      </LineChart>
    </ResponsiveContainer>
  )
}

// ─── Bar Chart ─────────────────────────────────────────────────────────────────

function BarChartComp({
  data,
  lang,
  height = 220,
}: {
  data: ReasonCountResponse[] | MessageTypeCountResponse[]
  lang: string
  height?: number
}) {
  if (!data?.length) return <div className="chart-empty">No data available</div>
  const chartData = data.map(d => ({
    name: (d as ReasonCountResponse).reason ?? (d as MessageTypeCountResponse).messageType ?? 'Unknown',
    count: d.count,
  }))
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={chartData} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
        <XAxis
          dataKey="name"
          tick={{ fontSize: 10, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
        />
        <YAxis
          tick={{ fontSize: 11, fill: '#94a3b8' }}
          tickLine={false}
          axisLine={false}
          tickFormatter={formatNumber}
        />
        <Tooltip content={<ChartTooltip lang={lang} />} />
        <Bar dataKey="count" fill="#3b82f6" radius={[6, 6, 0, 0]} maxBarSize={48} />
      </BarChart>
    </ResponsiveContainer>
  )
}

// ─── Donut Chart ───────────────────────────────────────────────────────────────

function DonutChart({ data }: { data: MessageTypeCountResponse[]; lang: string }) {
  if (!data?.length) return <div className="chart-empty">No data available</div>
  const total = data.reduce((s, d) => s + d.count, 0)
  return (
    <div className="donut-wrapper">
      <ResponsiveContainer width="100%" height={200}>
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={90}
            paddingAngle={3}
            dataKey="count"
            nameKey="messageType"
          >
            {data.map((_, i) => (
              <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
            ))}
          </Pie>
          <Tooltip formatter={(v: unknown) => {
            const n = typeof v === 'number' ? v : 0
            return [`${formatNumber(n)} (${((n / total) * 100).toFixed(1)}%)`, '']
          }} />
        </PieChart>
      </ResponsiveContainer>
      <div className="donut-legend">
        {data.map((d, i) => (
          <div key={i} className="donut-legend-item">
            <span className="donut-legend-dot" style={{ background: PIE_COLORS[i % PIE_COLORS.length] }} />
            <span className="donut-legend-label">{d.messageType}</span>
            <span className="donut-legend-value">{formatNumber(d.count)}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── Activity Sparkline (mini bar) ────────────────────────────────────────────

function ActivitySparkline({ points }: { points: EventTrendPoint[]; lang: string }) {
  if (!points?.length) return null
  const max = Math.max(...points.map(p => p.total), 1)
  return (
    <div className="sparkline">
      {points.map((p, i) => (
        <div
          key={i}
          className="sparkline-bar-wrap"
          title={`${p.bucket}: ${p.total}`}
        >
          <div
            className="sparkline-bar"
            style={{ height: `${Math.max((p.total / max) * 100, 4)}%` }}
          />
        </div>
      ))}
    </div>
  )
}

// ─── Service Health List ───────────────────────────────────────────────────────

function ServiceHealthList({ services, lang }: { services: ServiceProbe[]; lang: string }) {
  return (
    <div className="service-list">
      {services.map(s => (
        <div key={s.name} className="service-row">
          <StatusDot status={s.status} />
          <div className="service-info">
            <strong>{s.name}</strong>
            <code>{s.detail}</code>
          </div>
          <span className={`service-status-text ${s.status}`}>
            {s.status === 'ok' ? (lang === 'vi' ? 'Bình thường' : 'Healthy') :
             s.status === 'warning' ? (lang === 'vi' ? 'Cảnh báo' : 'Warning') :
             s.status === 'error' ? (lang === 'vi' ? 'Lỗi' : 'Error') :
             (lang === 'vi' ? 'Không xác định' : 'Unknown')}
          </span>
        </div>
      ))}
    </div>
  )
}

// ─── Tab Navigation ────────────────────────────────────────────────────────────

type TabId = 'overview' | 'users' | 'health' | 'auth'

function TabNav({ active, onChange, lang }: { active: TabId; onChange: (t: TabId) => void; lang: string }) {
  const tabs: { id: TabId; label: string; labelVi: string }[] = [
    { id: 'overview', label: 'Overview', labelVi: 'Tổng quan' },
    { id: 'users', label: 'User Analytics', labelVi: 'Phân tích người dùng' },
    { id: 'health', label: 'System Health', labelVi: 'Sức khỏe hệ thống' },
    { id: 'auth', label: 'Auth & Events', labelVi: 'Đăng nhập & Sự kiện' },
  ]
  return (
    <nav className="tab-nav">
      {tabs.map(t => (
        <button
          key={t.id}
          className={`tab-btn ${active === t.id ? 'active' : ''}`}
          onClick={() => onChange(t.id)}
          type="button"
        >
          {lang === 'vi' ? t.labelVi : t.label}
        </button>
      ))}
    </nav>
  )
}

// ─── Skeleton Loader ───────────────────────────────────────────────────────────

function Skeleton({ width = '100%', height = 20 }: { width?: string; height?: number }) {
  return <div className="skeleton" style={{ width, height }} />
}

// ─── Date Range Picker ─────────────────────────────────────────────────────────

function DateRangePicker({
  value,
  onChange,
}: {
  value: DateRangePreset
  onChange: (v: DateRangePreset) => void
}) {
  const options: { value: DateRangePreset; label: string; labelVi: string }[] = [
    { value: '7d', label: 'Last 7 days', labelVi: '7 ngày' },
    { value: '14d', label: 'Last 14 days', labelVi: '14 ngày' },
    { value: '30d', label: 'Last 30 days', labelVi: '30 ngày' },
    { value: '90d', label: 'Last 90 days', labelVi: '90 ngày' },
  ]
  const { language } = useLanguage()
  return (
    <div className="date-range-picker">
      {options.map(o => (
        <button
          key={o.value}
          type="button"
          className={`drp-btn ${value === o.value ? 'active' : ''}`}
          onClick={() => onChange(o.value)}
        >
          {language === 'vi' ? o.labelVi : o.label}
        </button>
      ))}
    </div>
  )
}

// ─── MAIN COMPONENT ────────────────────────────────────────────────────────────

export function AdminDashboardPage() {
  const { language } = useLanguage()
  const { accessToken, user } = useAuth()
  const adminMonitoringEmails = (import.meta.env.VITE_ADMIN_MONITORING_ALLOWED_EMAILS ?? '')
    .split(',')
    .map((e: string) => e.trim().toLowerCase())
    .filter(Boolean)

  const L = language === 'vi' ? VI_LABELS : EN_LABELS

  // ─── State ──────────────────────────────────────────────────────────────────
  const [activeTab, setActiveTab] = React.useState<TabId>('overview')
  const [dateRange, setDateRange] = React.useState<DateRangePreset>('30d')
  const [autoRefresh, setAutoRefresh] = React.useState(true)
  const [lastUpdated, setLastUpdated] = React.useState<Date | null>(null)

  // Analytics data
  const [dashboard, setDashboard] = React.useState<AnalyticsDashboardResponse | null>(null)
  const [overview, setOverview] = React.useState<AnalyticsOverviewResponse | null>(null)
  const [activeUsers, setActiveUsers] = React.useState<ActiveUserSummaryResponse | null>(null)
  const [reportReasons, setReportReasons] = React.useState<ReasonCountResponse[]>([])
  const [messageTypes, setMessageTypes] = React.useState<MessageTypeCountResponse[]>([])
  const [userTrend, setUserTrend] = React.useState<DailyTrendPointResponse[]>([])
  const [convTrend, setConvTrend] = React.useState<DailyTrendPointResponse[]>([])
  const [msgTrend, setMsgTrend] = React.useState<DailyTrendPointResponse[]>([])
  const [mediaTrend, setMediaTrend] = React.useState<DailyTrendPointResponse[]>([])
  const [reportTrend, setReportTrend] = React.useState<DailyTrendPointResponse[]>([])
  const [actionTrend, setActionTrend] = React.useState<DailyTrendPointResponse[]>([])

  // Core-service monitoring data
  const [services, setServices] = React.useState<ServiceProbe[]>([])
  const [monitoringSummary, setMonitoringSummary] = React.useState<MonitoringSummary | null>(null)
  const [eventTrend, setEventTrend] = React.useState<EventTrendPoint[]>([])
  const [audits, setAudits] = React.useState<SessionAudit[]>([])
  const [eventPage, setEventPage] = React.useState(0)
  const [hasMore, setHasMore] = React.useState(false)
  const [eventTypeFilter, setEventTypeFilter] = React.useState('ALL')
  const [platformFilter, setPlatformFilter] = React.useState('ALL')

  // Load state
  const [isLoading, setIsLoading] = React.useState(true)
  const [loadError, setLoadError] = React.useState<string | null>(null)

  // ─── Data Fetching ───────────────────────────────────────────────────────────
  const loadAnalytics = React.useCallback(async () => {
    const { from, to } = dateRangeFromPreset(dateRange)
    const params = { from, to }

    // Fetch all analytics data in parallel
    const [dashResult, overviewResult, reasonsResult, typesResult,
           userTResult, convTResult, msgTResult, mediaTResult,
           , reportTResult, actionTResult] = await Promise.allSettled([
      analyticsFetchWithTimeout<AnalyticsDashboardResponse>('/dashboard', params),
      analyticsFetchWithTimeout<AnalyticsOverviewResponse>('/overview', params),
      analyticsFetchWithTimeout<ReasonCountResponse[]>('/reports/reasons', params),
      analyticsFetchWithTimeout<MessageTypeCountResponse[]>('/messages/types', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/users/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/conversations/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/messages/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/media/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/groups/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/reports/trend', params),
      analyticsFetchWithTimeout<DailyTrendPointResponse[]>('/actions/trend', params),
    ])

    const extract = <T,>(r: PromiseSettledResult<unknown> & { status: 'fulfilled'; value: T }): T | null => {
      if (r.status === 'fulfilled') return extractAnalyticsData<T>(r.value)
      return null
    }

    setDashboard(extract<AnalyticsDashboardResponse>(dashResult))
    setOverview(extract<AnalyticsOverviewResponse>(overviewResult))
    setReportReasons(extract<ReasonCountResponse[]>(reasonsResult) ?? [])
    setMessageTypes(extract<MessageTypeCountResponse[]>(typesResult) ?? [])
    setUserTrend(extract<DailyTrendPointResponse[]>(userTResult) ?? [])
    setConvTrend(extract<DailyTrendPointResponse[]>(convTResult) ?? [])
    setMsgTrend(extract<DailyTrendPointResponse[]>(msgTResult) ?? [])
    setMediaTrend(extract<DailyTrendPointResponse[]>(mediaTResult) ?? [])
    setReportTrend(extract<DailyTrendPointResponse[]>(reportTResult) ?? [])
    setActionTrend(extract<DailyTrendPointResponse[]>(actionTResult) ?? [])

    if (dashResult.status === 'fulfilled') {
      const d = extract<AnalyticsDashboardResponse>(dashResult.value)
      if (d?.activeUsers) setActiveUsers(d.activeUsers)
    }
  }, [dateRange])

  const loadCoreService = React.useCallback(async () => {
    // Service health probes
    const serviceProbes = [
      { name: 'core-service', url: `${API_BASE_URL}/actuator/health` },
      { name: 'message-service', url: `${MESSAGE_API_URL}/health` },
      { name: 'media-service', url: `${MEDIA_API_URL}/health` },
      { name: 'ai-service', url: `${AI_API_URL}/health` },
      { name: 'moderation-service', url: `${window.location.origin}/api/v1/actuator/health` },
      { name: 'analytics-service', url: `${window.location.origin}/api/v1/actuator/health` },
    ]

    const probeResults = await Promise.allSettled(
      serviceProbes.map(async (probe): Promise<ServiceProbe> => {
        try {
          const resp = await fetchWithTimeout(probe.url, accessToken)
          const status: ServiceProbe['status'] = resp.ok ? 'ok' : resp.status >= 500 ? 'error' : 'warning'
          let detail = `${resp.status}`
          if (resp.ok) {
            try {
              const j = await resp.json()
              detail = j.status ?? j.version ?? 'ok'
            } catch { /* ignore */ }
          }
          return { name: probe.name, url: probe.url, status, detail, lastChecked: new Date().toISOString() }
        } catch {
          return { name: probe.name, url: probe.url, status: 'error', detail: 'unreachable', lastChecked: new Date().toISOString() }
        }
      })
    )

    setServices(probeResults.map((r, i) =>
      r.status === 'fulfilled' ? r.value : { name: serviceProbes[i].name, url: serviceProbes[i].url, status: 'unknown' as const, detail: 'unknown' }
    ))

    // Monitoring summary & events
    const windowHours = dateRange === '7d' ? 168 : dateRange === '14d' ? 336 : dateRange === '30d' ? 720 : 2160

    const eventParams = new URLSearchParams({
      windowHours: String(windowHours),
      limit: '20',
      page: String(eventPage),
    })
    if (eventTypeFilter !== 'ALL') eventParams.set('eventType', eventTypeFilter)
    if (platformFilter !== 'ALL') eventParams.set('platform', platformFilter)

    const [sumResp, evtResp, trResp] = await Promise.allSettled([
      fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/summary?windowHours=${windowHours}`, accessToken),
      fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events?${eventParams}`, accessToken),
      fetchWithTimeout(`${API_BASE_URL}/admin/monitoring/events/trend?windowHours=${windowHours}${eventTypeFilter !== 'ALL' ? `&eventType=${eventTypeFilter}` : ''}${platformFilter !== 'ALL' ? `&platform=${platformFilter}` : ''}`, accessToken),
    ])

    if (sumResp.status === 'fulfilled' && sumResp.value.ok) {
      const j = await sumResp.value.json()
      setMonitoringSummary(extractData<MonitoringSummary>(j))
    }

    if (evtResp.status === 'fulfilled' && evtResp.value.ok) {
      const j = await evtResp.value.json()
      const ep = extractData<EventPage>(j)
      setAudits(ep?.items ?? [])
      setHasMore(Boolean(ep?.hasMore))
    }

    if (trResp.status === 'fulfilled' && trResp.value.ok) {
      const j = await trResp.value.json()
      setEventTrend((extractData<EventTrendPoint[]>(j) ?? []).slice(-48))
    }
  }, [accessToken, dateRange, eventPage, eventTypeFilter, platformFilter])

  const loadAll = React.useCallback(async () => {
    setIsLoading(true)
    setLoadError(null)
    try {
      await Promise.all([loadAnalytics(), loadCoreService()])
      setLastUpdated(new Date())
    } catch (e) {
      setLoadError(e instanceof Error ? e.message : 'Load failed')
    } finally {
      setIsLoading(false)
    }
  }, [loadAnalytics, loadCoreService])

  // ─── Effects ─────────────────────────────────────────────────────────────────
  React.useEffect(() => { void loadAll() }, [loadAll])

  React.useEffect(() => {
    if (!autoRefresh) return undefined
    const id = setInterval(() => void loadAll(), 30_000)
    return () => clearInterval(id)
  }, [autoRefresh, loadAll])

  React.useEffect(() => { setEventPage(0) }, [dateRange, eventTypeFilter, platformFilter])

  const hasAccess = Boolean(
    user?.email &&
    adminMonitoringEmails.includes(user.email?.toLowerCase() ?? '')
  )

  // ─── Derived ─────────────────────────────────────────────────────────────────
  const okCount = services.filter(s => s.status === 'ok').length
  const warnCount = services.filter(s => s.status === 'warning').length
  const errCount = services.filter(s => s.status === 'error').length

  // Combined multi-line for overview
  const multiLineData = React.useMemo(() => {
    const dates = new Set<string>()
    ;[userTrend, convTrend, msgTrend].forEach(t => t.forEach(p => dates.add(p.date)))
    const sorted = Array.from(dates).sort()
    return sorted.map(d => ({
      date: d,
      Users: userTrend.find(p => p.date === d)?.value ?? 0,
      Conversations: convTrend.find(p => p.date === d)?.value ?? 0,
      Messages: msgTrend.find(p => p.date === d)?.value ?? 0,
    }))
  }, [userTrend, convTrend, msgTrend])

  // ─── Export CSV ───────────────────────────────────────────────────────────────
  const handleExport = () => {
    if (!audits.length) return
    const csv = toCsv(audits)
    const stamp = new Date().toISOString().replaceAll(':', '-')
    downloadCsv(csv, `auth-events-${eventPage + 1}-${stamp}.csv`)
  }

  // ─── Render ───────────────────────────────────────────────────────────────────
  return (
    <div className="adm-page">
      {/* ── Header ── */}
      <header className="adm-header">
        <div className="adm-header-left">
          <p className="adm-eyebrow">VNALO Enterprise</p>
          <h1 className="adm-title">{L.dashboardTitle}</h1>
          <p className="adm-subtitle">{L.dashboardSubtitle}</p>
        </div>
        <div className="adm-header-right">
          <label className="adm-toggle">
            <input type="checkbox" checked={autoRefresh} onChange={e => setAutoRefresh(e.target.checked)} />
            <span>{L.autoRefresh}</span>
          </label>
          <div className="adm-header-btns">
            <button type="button" onClick={handleExport} disabled={!audits.length}>{L.exportCsv}</button>
            <button type="button" onClick={() => void loadAll()} disabled={isLoading}>
              {isLoading ? L.refreshing : L.refresh}
            </button>
          </div>
        </div>
      </header>

      {!hasAccess && (
        <div className="adm-note adm-note--warn">{L.accessNote}</div>
      )}
      {loadError && (
        <div className="adm-note adm-note--error">{loadError}</div>
      )}

      {/* ── Controls ── */}
      <div className="adm-controls">
        <DateRangePicker value={dateRange} onChange={setDateRange} />
        {lastUpdated && (
          <span className="adm-last-updated">
            {L.lastUpdated}: {lastUpdated.toLocaleTimeString()}
          </span>
        )}
      </div>

      {/* ── Tab Nav ── */}
      <TabNav active={activeTab} onChange={setActiveTab} lang={language} />

      {/* ── TAB: OVERVIEW ── */}
      {activeTab === 'overview' && (
        <div className="adm-tab-content">
          {/* KPI Row */}
          <div className="adm-kpi-grid">
            {isLoading ? (
              <>
                <Skeleton height={80} />
                <Skeleton height={80} />
                <Skeleton height={80} />
                <Skeleton height={80} />
                <Skeleton height={80} />
                <Skeleton height={80} />
              </>
            ) : (
              <>
                <KpiCard
                  label={L.totalUsers}
                  value={overview?.usersRegistered ?? 0}
                  sub={L.registeredInPeriod}
                  tone="success"
                />
                <KpiCard
                  label={L.totalConversations}
                  value={overview?.conversationsCreated ?? 0}
                  tone="neutral"
                />
                <KpiCard
                  label={L.totalMessages}
                  value={overview?.messagesSent ?? 0}
                  tone="neutral"
                />
                <KpiCard
                  label={L.activeUsers}
                  value={activeUsers?.dau ?? 0}
                  sub={`${L.dauLabel} • ${L.wauLabel}: ${formatNumber(activeUsers?.wau ?? 0)}`}
                  tone="success"
                />
                <KpiCard
                  label={L.reportsFiled}
                  value={overview?.reportsCreated ?? 0}
                  tone={Number(overview?.reportsCreated) > 0 ? 'warning' : 'neutral'}
                />
                <KpiCard
                  label={L.actionsTaken}
                  value={overview?.moderationActionsTaken ?? 0}
                  tone="neutral"
                />
              </>
            )}
          </div>

          {/* Main Chart: Growth Overview */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.growthOverview}</h2>
              <span>{dateRangeFromPreset(dateRange).from} — {dateRangeFromPreset(dateRange).to}</span>
            </div>
            {isLoading ? <Skeleton height={220} /> : (
              <MultiLineChart
                data={multiLineData}
                lines={[
                  { dataKey: 'Users', name: L.users, color: '#3b82f6' },
                  { dataKey: 'Conversations', name: L.conversations, color: '#10b981' },
                  { dataKey: 'Messages', name: L.messages, color: '#f59e0b' },
                ]}
                lang={language}
                height={260}
              />
            )}
          </section>

          {/* 2-col: Messages & Media Trends */}
          <div className="adm-2col">
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.messagesOverTime}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <TrendChart data={msgTrend} lang={language} height={200} />
              )}
            </section>
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.mediaUploads}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <TrendChart data={mediaTrend} lang={language} height={200} />
              )}
            </section>
          </div>

          {/* 2-col: Report & Action Trends */}
          <div className="adm-2col">
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.reportsTrend}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <TrendChart data={reportTrend} lang={language} height={200} />
              )}
            </section>
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.moderationActions}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <TrendChart data={actionTrend} lang={language} height={200} />
              )}
            </section>
          </div>
        </div>
      )}

      {/* ── TAB: USER ANALYTICS ── */}
      {activeTab === 'users' && (
        <div className="adm-tab-content">
          {/* DAU/WAU/MAU */}
          <div className="adm-kpi-grid">
            {isLoading ? (
              <><Skeleton height={80} /><Skeleton height={80} /><Skeleton height={80} /></>
            ) : (
              <>
                <KpiCard label={L.dau} value={activeUsers?.dau ?? 0} sub={L.dauDesc} tone="success" />
                <KpiCard label={L.wau} value={activeUsers?.wau ?? 0} sub={L.wauDesc} tone="neutral" />
                <KpiCard label={L.mau} value={activeUsers?.mau ?? 0} sub={L.mauDesc} tone="neutral" />
              </>
            )}
          </div>

          <div className="adm-2col">
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.userRegistrations}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <TrendChart data={userTrend} lang={language} height={220} />
              )}
            </section>
            <section className="adm-panel">
              <div className="adm-panel-header">
                <h2>{L.messageTypes}</h2>
              </div>
              {isLoading ? <Skeleton height={220} /> : (
                <DonutChart data={messageTypes} lang={language} />
              )}
            </section>
          </div>

          {/* Top Users */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.topActiveUsers}</h2>
            </div>
            {isLoading ? <Skeleton height={120} /> : (
              <div className="adm-table-wrap">
                <table className="adm-table">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>{L.userName}</th>
                      <th>{L.messageCount}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(dashboard?.topActiveUsers ?? []).map((u: TopActiveUserResponse, i: number) => (
                      <tr key={u.userId}>
                        <td>{i + 1}</td>
                        <td>{u.displayName}</td>
                        <td>{formatNumber(u.messageCount)}</td>
                      </tr>
                    ))}
                    {!(dashboard?.topActiveUsers?.length) && (
                      <tr><td colSpan={3} className="td-empty">{L.noData}</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          {/* Message Type Breakdown */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.messageTypeBreakdown}</h2>
            </div>
            {isLoading ? <Skeleton height={220} /> : (
              <BarChartComp data={messageTypes} lang={language} />
            )}
          </section>
        </div>
      )}

      {/* ── TAB: SYSTEM HEALTH ── */}
      {activeTab === 'health' && (
        <div className="adm-tab-content">
          {/* Service Health KPIs */}
          <div className="adm-kpi-grid">
            <KpiCard label={L.healthyServices} value={`${okCount}/${services.length || 5}`} tone="success" />
            <KpiCard label={L.warningServices} value={warnCount} tone="warning" />
            <KpiCard label={L.errorServices} value={errCount} tone="danger" />
            <KpiCard label={L.totalServices} value={services.length || 5} tone="neutral" />
          </div>

          {/* Service Health List */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.serviceHealthStatus}</h2>
            </div>
            {isLoading ? (
              <div className="service-list">
                {[1, 2, 3, 4].map(i => <Skeleton key={i} height={52} />)}
              </div>
            ) : (
              <ServiceHealthList services={services} lang={language} />
            )}
          </section>

          {/* Moderation KPIs */}
          <div className="adm-kpi-grid">
            <KpiCard
              label={L.reportsReceived}
              value={overview?.reportsCreated ?? 0}
              tone={(overview?.reportsCreated ?? 0) > 0 ? 'warning' : 'neutral'}
            />
            <KpiCard label={L.moderationActions} value={overview?.moderationActionsTaken ?? 0} tone="neutral" />
            <KpiCard label={L.pendingReports} value={monitoringSummary?.qr?.pendingNow ?? 0} tone="warning" />
            <KpiCard label={L.sessionsActive} value={monitoringSummary?.sessions?.activeRefreshTokens ?? 0} tone="success" />
          </div>

          {/* Report Reasons Breakdown */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.reportReasons}</h2>
            </div>
            {isLoading ? <Skeleton height={220} /> : (
              <BarChartComp data={reportReasons} lang={language} height={240} />
            )}
          </section>
        </div>
      )}

      {/* ── TAB: AUTH & EVENTS ── */}
      {activeTab === 'auth' && (
        <div className="adm-tab-content">
          {/* Auth KPIs */}
          <div className="adm-kpi-grid">
            <KpiCard label={L.totalAccounts} value={monitoringSummary?.accounts?.total ?? 0} tone="neutral" />
            <KpiCard label={L.activeAccounts} value={monitoringSummary?.accounts?.active ?? 0} tone="success" />
            <KpiCard label={L.lockedAccounts} value={monitoringSummary?.accounts?.locked ?? 0} tone="danger" />
            <KpiCard label={L.failedLogins} value={monitoringSummary?.audits?.loginFailureLast24Hours ?? 0} tone="danger" />
            <KpiCard label={L.otpVerified} value={monitoringSummary?.otp?.verifiedLast24Hours ?? 0} tone="neutral" />
            <KpiCard label={L.qrApproved} value={monitoringSummary?.qr?.approvedLast24Hours ?? 0} tone="neutral" />
            <KpiCard label={L.aiMessages} value={monitoringSummary?.ai?.messagesLast24Hours ?? 0} tone="neutral" />
            <KpiCard label={L.activeTokens} value={monitoringSummary?.sessions?.activeRefreshTokens ?? 0} tone="success" />
          </div>

          {/* Event Trend */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.eventActivity}</h2>
            </div>
            {isLoading ? <Skeleton height={220} /> : (
              <div className="event-sparkline-wrap">
                <ActivitySparkline points={eventTrend} lang={language} />
                <div className="event-sparkline-meta">
                  <span>
                    {eventTrend.length > 0
                      ? `${formatDate(eventTrend[0].bucket, language)} — ${formatDate(eventTrend[eventTrend.length - 1].bucket, language)}`
                      : L.noData}
                  </span>
                </div>
              </div>
            )}
          </section>

          {/* Filters */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.eventFilters}</h2>
            </div>
            <div className="adm-filters">
              <label>
                <span>{L.eventType}</span>
                <select value={eventTypeFilter} onChange={e => setEventTypeFilter(e.target.value)}>
                  {EVENT_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
                </select>
              </label>
              <label>
                <span>{L.platform}</span>
                <select value={platformFilter} onChange={e => setPlatformFilter(e.target.value)}>
                  {PLATFORMS.map(p => <option key={p} value={p}>{p}</option>)}
                </select>
              </label>
            </div>
          </section>

          {/* Auth Events Table */}
          <section className="adm-panel">
            <div className="adm-panel-header">
              <h2>{L.recentEvents}</h2>
              <span>{audits.length} {L.eventsShown}</span>
            </div>
            {isLoading ? (
              <Skeleton height={200} />
            ) : audits.length === 0 ? (
              <p className="adm-empty">{L.noEvents}</p>
            ) : (
              <div className="adm-table-wrap">
                <table className="adm-table">
                  <thead>
                    <tr>
                      <th>{L.colTime}</th>
                      <th>{L.colEvent}</th>
                      <th>{L.colSeverity}</th>
                      <th>{L.colPlatform}</th>
                      <th>{L.colDevice}</th>
                      <th>{L.colDetail}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {audits.map((a, i) => (
                      <tr key={a.auditId ?? i}>
                        <td className="td-time">
                          {a.createdAt ? (
                            <>
                              <span className="td-date">{formatDate(a.createdAt, language)}</span>
                              <span className="td-clock">{formatTime(a.createdAt)}</span>
                            </>
                          ) : '—'}
                        </td>
                        <td><code className="event-type">{a.eventType ?? 'SESSION_EVENT'}</code></td>
                        <td><SeverityBadge value={a.severity ?? 'info'} /></td>
                        <td>{a.platform ?? 'WEB'}</td>
                        <td>{a.deviceName ?? 'Unknown device'}</td>
                        <td className="td-detail">{a.detail ?? ''}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* Pagination */}
            <div className="adm-pagination">
              <button
                type="button"
                onClick={() => setEventPage(p => Math.max(0, p - 1))}
                disabled={eventPage === 0 || isLoading}
              >
                {L.prevPage}
              </button>
              <span>{L.page} {eventPage + 1}</span>
              <button
                type="button"
                onClick={() => setEventPage(p => p + 1)}
                disabled={!hasMore || isLoading}
              >
                {L.nextPage}
              </button>
            </div>
          </section>
        </div>
      )}

      {/* ── Footer ── */}
      <footer className="adm-footer">
        <p>{L.footerNote}</p>
      </footer>
    </div>
  )
}

// ─── Labels ────────────────────────────────────────────────────────────────────

const EN_LABELS = {
  dashboardTitle: 'Operations Dashboard',
  dashboardSubtitle: 'Real-time analytics, user insights, and system health monitoring for VNALO enterprise.',
  autoRefresh: 'Auto-refresh 30s',
  refresh: 'Refresh',
  refreshing: 'Refreshing...',
  exportCsv: 'Export CSV',
  lastUpdated: 'Updated',
  accessNote: 'This page requires backend allowlist access. The UI hint is not a security boundary.',
  // KPIs
  totalUsers: 'Users Registered',
  registeredInPeriod: 'in selected period',
  totalConversations: 'Conversations Created',
  totalMessages: 'Messages Sent',
  activeUsers: 'Daily Active Users',
  reportsFiled: 'Reports Filed',
  actionsTaken: 'Moderation Actions',
  // Overview charts
  growthOverview: 'Growth Overview',
  users: 'Users',
  conversations: 'Conversations',
  messages: 'Messages',
  messagesOverTime: 'Messages Over Time',
  mediaUploads: 'Media Uploads',
  reportsTrend: 'Reports Trend',
  moderationActions: 'Moderation Actions',
  // Users tab
  dau: 'DAU',
  dauDesc: 'Daily active users',
  dauLabel: 'DAU',
  wau: 'WAU',
  wauDesc: 'Weekly active users',
  wauLabel: 'WAU',
  mau: 'MAU',
  mauDesc: 'Monthly active users',
  userRegistrations: 'User Registrations',
  messageTypes: 'Message Types',
  topActiveUsers: 'Top Active Users',
  userName: 'Display Name',
  messageCount: 'Messages',
  messageTypeBreakdown: 'Message Type Breakdown',
  // Health tab
  healthyServices: 'Healthy Services',
  warningServices: 'Warning',
  errorServices: 'Errors',
  totalServices: 'Total Services',
  serviceHealthStatus: 'Service Health Status',
  reportsReceived: 'Reports Received',
  moderationActions2: 'Moderation Actions',
  pendingReports: 'Pending Reports',
  sessionsActive: 'Active Sessions',
  reportReasons: 'Report Reasons Breakdown',
  // Auth tab
  totalAccounts: 'Total Accounts',
  activeAccounts: 'Active Accounts',
  lockedAccounts: 'Locked Accounts',
  failedLogins: 'Failed Logins (24h)',
  otpVerified: 'OTP Verified (24h)',
  qrApproved: 'QR Approved (24h)',
  aiMessages: 'AI Messages (24h)',
  activeTokens: 'Active Tokens',
  eventActivity: 'Event Activity',
  eventFilters: 'Filters',
  eventType: 'Event Type',
  platform: 'Platform',
  recentEvents: 'Recent Auth Events',
  eventsShown: 'events shown',
  noEvents: 'No events match the current filters.',
  colTime: 'Time',
  colEvent: 'Event',
  colSeverity: 'Severity',
  colPlatform: 'Platform',
  colDevice: 'Device',
  colDetail: 'Detail',
  prevPage: 'Previous',
  nextPage: 'Next',
  page: 'Page',
  // Common
  noData: 'No data available',
  footerNote: 'VNALO Admin Dashboard — data is for operational monitoring only. Sensitive information is never exposed.',
}

const VI_LABELS = {
  dashboardTitle: 'Bảng điều khiển vận hành',
  dashboardSubtitle: 'Phân tích thời gian thực, insight người dùng và giám sát sức khỏe hệ thống cho VNALO enterprise.',
  autoRefresh: 'Tự động làm mới 30s',
  refresh: 'Làm mới',
  refreshing: 'Đang tải...',
  exportCsv: 'Xuất CSV',
  lastUpdated: 'Cập nhật lúc',
  accessNote: 'Trang này yêu cầu quyền truy cập từ backend allowlist. UI chỉ là gợi ý; backend mới là lớp kiểm soát thực sự.',
  // KPIs
  totalUsers: 'Người dùng đăng ký',
  registeredInPeriod: 'trong kỳ đã chọn',
  totalConversations: 'Hội thoại tạo mới',
  totalMessages: 'Tin nhắn gửi đi',
  activeUsers: 'Người dùng hàng ngày',
  reportsFiled: 'Báo cáo đã gửi',
  actionsTaken: 'Hành động kiểm duyệt',
  // Overview charts
  growthOverview: 'Tổng quan tăng trưởng',
  users: 'Người dùng',
  conversations: 'Hội thoại',
  messages: 'Tin nhắn',
  messagesOverTime: 'Tin nhắn theo thời gian',
  mediaUploads: 'Tải lên media',
  reportsTrend: 'Xu hướng báo cáo',
  moderationActions: 'Hành động kiểm duyệt',
  // Users tab
  dau: 'DAU',
  dauDesc: 'Người dùng hoạt động hàng ngày',
  dauLabel: 'DAU',
  wau: 'WAU',
  wauDesc: 'Người dùng hoạt động hàng tuần',
  wauLabel: 'WAU',
  mau: 'MAU',
  mauDesc: 'Người dùng hoạt động hàng tháng',
  userRegistrations: 'Đăng ký người dùng',
  messageTypes: 'Loại tin nhắn',
  topActiveUsers: 'Người dùng tích cực nhất',
  userName: 'Tên hiển thị',
  messageCount: 'Tin nhắn',
  messageTypeBreakdown: 'Phân bổ loại tin nhắn',
  // Health tab
  healthyServices: 'Dịch vụ bình thường',
  warningServices: 'Cảnh báo',
  errorServices: 'Lỗi',
  totalServices: 'Tổng dịch vụ',
  serviceHealthStatus: 'Trạng thái sức khỏe dịch vụ',
  reportsReceived: 'Báo cáo nhận được',
  moderationActions2: 'Hành động kiểm duyệt',
  pendingReports: 'Báo cáo chờ xử lý',
  sessionsActive: 'Phiên hoạt động',
  reportReasons: 'Lý do báo cáo',
  // Auth tab
  totalAccounts: 'Tổng tài khoản',
  activeAccounts: 'Tài khoản hoạt động',
  lockedAccounts: 'Tài khoản bị khóa',
  failedLogins: 'Đăng nhập lỗi (24h)',
  otpVerified: 'OTP xác thực (24h)',
  qrApproved: 'QR duyệt (24h)',
  aiMessages: 'Tin nhắn AI (24h)',
  activeTokens: 'Token hoạt động',
  eventActivity: 'Hoạt động sự kiện',
  eventFilters: 'Bộ lọc',
  eventType: 'Loại sự kiện',
  platform: 'Nền tảng',
  recentEvents: 'Sự kiện đăng nhập gần đây',
  eventsShown: 'sự kiện hiển thị',
  noEvents: 'Không có sự kiện phù hợp với bộ lọc hiện tại.',
  colTime: 'Thời gian',
  colEvent: 'Sự kiện',
  colSeverity: 'Mức độ',
  colPlatform: 'Nền tảng',
  colDevice: 'Thiết bị',
  colDetail: 'Chi tiết',
  prevPage: 'Trước',
  nextPage: 'Sau',
  page: 'Trang',
  // Common
  noData: 'Chưa có dữ liệu',
  footerNote: 'VNALO Admin Dashboard — dữ liệu chỉ phục vụ giám sát vận hành. Thông tin nhạy cảm không bao giờ được hiển thị.',
}

const EVENT_TYPES = ['ALL', 'LOGIN_SUCCESS', 'LOGIN_FAILED', 'QR_LOGIN_APPROVED', 'SESSION_REVOKED_LOGOUT', 'SESSION_REVOKED_LOGOUT_ALL', 'OTP_REQUESTED', 'PASSWORD_CHANGED']
const PLATFORMS = ['ALL', 'WEB', 'ANDROID', 'IOS']
