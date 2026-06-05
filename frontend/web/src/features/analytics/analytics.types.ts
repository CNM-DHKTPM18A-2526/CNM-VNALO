// ──────────────────────────────────────────────────────────────────────────────
// Response DTOs from analytics-service (/api/v1/analytics)
// ──────────────────────────────────────────────────────────────────────────────

export interface AnalyticsOverviewResponse {
  usersRegistered: number
  conversationsCreated: number
  messagesSent: number
  reportsCreated: number
  moderationActionsTaken: number
}

export interface DailyTrendPointResponse {
  date: string   // ISO LocalDate string, e.g. "2026-06-01"
  value: number
}

export interface ActiveUserSummaryResponse {
  dau: number   // Daily Active Users
  wau: number   // Weekly Active Users
  mau: number   // Monthly Active Users
}

export interface TopActiveUserResponse {
  userId: string
  displayName: string
  messageCount: number
}

export interface ReasonCountResponse {
  reason: string
  count: number
}

export interface MessageTypeCountResponse {
  messageType: string
  count: number
}

export interface AnalyticsDashboardResponse {
  overview: AnalyticsOverviewResponse
  activeUsers: ActiveUserSummaryResponse
  messagesPerDay: DailyTrendPointResponse[]
  mediaPerDay: DailyTrendPointResponse[]
  groupsPerDay: DailyTrendPointResponse[]
  topActiveUsers: TopActiveUserResponse[]
}

export interface EventCountResponse {
  key: string
  count: number
}

export interface BehavioralAnalyticsSummaryResponse {
  eventsTotal: number
  activeUsers: number
  sessionsStarted: number
  sessionsEnded: number
  screenViews: number
  featureUses: number
  clientErrors: number
  apiErrors: number
  aiPrompts: number
  aiFailures: number
  faceAuthAttempts: number
  averageSessionDurationMinutes: number
  topEvents: EventCountResponse[]
  topScreens: EventCountResponse[]
  topFeatures: EventCountResponse[]
  hourlyUsage: EventCountResponse[]
}

export interface BackfillJobResponse {
  jobId: string
  fromDate: string
  toDate: string
  status: BackfillJobStatus
  totalDays: number
  processedDays: number
  startedAt: string
  finishedAt: string | null
  errorMessage: string | null
}

export type BackfillJobStatus = 'PENDING' | 'RUNNING' | 'COMPLETED' | 'FAILED'

export interface ApiResponse<T> {
  success: boolean
  message: string
  data: T
  errorCode: string | null
}

// ──────────────────────────────────────────────────────────────────────────────
// Core-service monitoring types (/admin/monitoring)
// ──────────────────────────────────────────────────────────────────────────────

export interface MonitoringSummary {
  generatedAt?: string
  accessMode?: string
  canExport?: boolean
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

export interface SessionAudit {
  auditId?: string
  eventType?: string
  sessionType?: string
  trustLevel?: string
  platform?: string
  deviceName?: string
  deviceIdMasked?: string
  detail?: string
  severity?: 'info' | 'warning' | 'error'
  createdAt?: string
}

export interface EventTrendPoint {
  bucket: string
  total: number
  warning: number
  error: number
}

export interface EventPage {
  page: number
  limit: number
  hasMore: boolean
  items: SessionAudit[]
}

// ──────────────────────────────────────────────────────────────────────────────
// Service health probe
// ──────────────────────────────────────────────────────────────────────────────

export type ServiceStatus = 'ok' | 'warning' | 'error' | 'unknown'

export interface ServiceProbe {
  name: string
  url: string
  status: ServiceStatus
  detail: string
  lastChecked?: string
}

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard date range
// ──────────────────────────────────────────────────────────────────────────────

export type DateRangePreset = '7d' | '14d' | '30d' | '90d'

export function dateRangeFromPreset(preset: DateRangePreset): { from: string; to: string } {
  const to = new Date()
  const from = new Date()
  const days = preset === '7d' ? 7 : preset === '14d' ? 14 : preset === '30d' ? 30 : 90
  from.setDate(from.getDate() - days)
  return {
    from: from.toISOString().split('T')[0],
    to: to.toISOString().split('T')[0],
  }
}
