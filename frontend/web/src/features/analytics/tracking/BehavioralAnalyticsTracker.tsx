import React from 'react'
import { useLocation } from 'react-router-dom'

import { ANALYTICS_API_URL } from '../analytics.client'
import { useAuth } from '../../auth/useAuth'

type BehavioralEventType =
  | 'APP_SESSION_STARTED'
  | 'APP_SESSION_HEARTBEAT'
  | 'APP_SESSION_ENDED'
  | 'SCREEN_VIEWED'
  | 'FEATURE_USED'
  | 'CLIENT_ERROR'

type BehavioralEventPayload = {
  eventType: BehavioralEventType
  sessionId: string
  platform: 'WEB'
  screenName?: string
  featureName?: string
  durationMs?: number
  occurredAt: string
  appVersion?: string
  locale?: string
  timezone?: string
  metadata?: Record<string, string | number | boolean>
}

const HEARTBEAT_MS = 30000
const SESSION_KEY = 'vnalo.analytics.sessionId'
const CONSENT_KEY = 'vnalo.analyticsConsent'
const START_KEY = 'vnalo.analytics.sessionStartedAt'

function getOrCreateSessionId() {
  const existing = sessionStorage.getItem(SESSION_KEY)
  if (existing) return existing
  const id = crypto.randomUUID?.() ?? `web-${Date.now()}-${Math.random().toString(16).slice(2)}`
  sessionStorage.setItem(SESSION_KEY, id)
  return id
}

function hasAnalyticsConsent() {
  return localStorage.getItem(CONSENT_KEY) !== 'false'
}

function normalizeScreen(pathname: string) {
  if (pathname.startsWith('/chat/')) return '/chat/:conversationId'
  if (pathname.startsWith('/stories/')) return '/stories/:storyId'
  if (pathname.startsWith('/admin/')) return pathname.replace(/\/\d+|\/[0-9a-f-]{16,}/gi, '/:id')
  return pathname || '/'
}

function safeFeatureName(target: Element | null) {
  const element = target?.closest('[data-analytics-feature], button, a, [role="button"]') as HTMLElement | null
  if (!element) return null
  const explicit = element.dataset.analyticsFeature
  if (explicit) return explicit.slice(0, 120)
  const role = element.getAttribute('role') || element.tagName.toLowerCase()
  const label = element.getAttribute('aria-label') || element.getAttribute('title') || element.dataset.testid || ''
  return `${role}${label ? `:${label}` : ''}`.slice(0, 120)
}

export function BehavioralAnalyticsTracker() {
  const location = useLocation()
  const { accessToken, isAuthenticated } = useAuth()
  const sessionIdRef = React.useRef(getOrCreateSessionId())
  const accessTokenRef = React.useRef(accessToken)

  React.useEffect(() => {
    accessTokenRef.current = accessToken
  }, [accessToken])

  const sendEvent = React.useCallback((event: Omit<BehavioralEventPayload, 'sessionId' | 'platform' | 'occurredAt' | 'locale' | 'timezone'>, keepalive = false) => {
    const token = accessTokenRef.current
    if (!token || !hasAnalyticsConsent()) return

    const payload: BehavioralEventPayload = {
      ...event,
      sessionId: sessionIdRef.current,
      platform: 'WEB',
      occurredAt: new Date().toISOString(),
      locale: navigator.language,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      appVersion: import.meta.env.VITE_APP_VERSION,
    }

    void fetch(`${ANALYTICS_API_URL}/events`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      keepalive,
    }).catch(() => undefined)
  }, [])

  React.useEffect(() => {
    if (!isAuthenticated || !accessToken || !hasAnalyticsConsent()) return
    const startedAt = Date.now()
    sessionStorage.setItem(START_KEY, String(startedAt))
    sendEvent({ eventType: 'APP_SESSION_STARTED', screenName: normalizeScreen(window.location.pathname), metadata: { visibility: document.visibilityState } })

    const heartbeat = window.setInterval(() => {
      if (document.visibilityState === 'visible') {
        sendEvent({ eventType: 'APP_SESSION_HEARTBEAT', screenName: normalizeScreen(window.location.pathname) })
      }
    }, HEARTBEAT_MS)

    const endSession = () => {
      const start = Number(sessionStorage.getItem(START_KEY) || startedAt)
      sendEvent({ eventType: 'APP_SESSION_ENDED', screenName: normalizeScreen(window.location.pathname), durationMs: Math.max(0, Date.now() - start) }, true)
    }

    window.addEventListener('pagehide', endSession)
    return () => {
      window.clearInterval(heartbeat)
      window.removeEventListener('pagehide', endSession)
      endSession()
    }
  }, [accessToken, isAuthenticated, sendEvent])

  React.useEffect(() => {
    if (!isAuthenticated) return
    sendEvent({ eventType: 'SCREEN_VIEWED', screenName: normalizeScreen(location.pathname), metadata: { search: Boolean(location.search) } })
  }, [isAuthenticated, location.pathname, location.search, sendEvent])

  React.useEffect(() => {
    if (!isAuthenticated) return
    const onPointerDown = (event: PointerEvent) => {
      const featureName = safeFeatureName(event.target as Element | null)
      if (!featureName) return
      sendEvent({ eventType: 'FEATURE_USED', screenName: normalizeScreen(window.location.pathname), featureName })
    }
    document.addEventListener('pointerdown', onPointerDown, { capture: true })
    return () => document.removeEventListener('pointerdown', onPointerDown, { capture: true })
  }, [isAuthenticated, sendEvent])

  React.useEffect(() => {
    if (!isAuthenticated) return
    const onError = (event: ErrorEvent) => {
      sendEvent({
        eventType: 'CLIENT_ERROR',
        screenName: normalizeScreen(window.location.pathname),
        metadata: {
          name: event.error?.name || 'Error',
          source: event.filename ? new URL(event.filename, window.location.origin).pathname : 'unknown',
        },
      })
    }
    const onUnhandled = () => {
      sendEvent({ eventType: 'CLIENT_ERROR', screenName: normalizeScreen(window.location.pathname), metadata: { name: 'UnhandledPromiseRejection' } })
    }
    window.addEventListener('error', onError)
    window.addEventListener('unhandledrejection', onUnhandled)
    return () => {
      window.removeEventListener('error', onError)
      window.removeEventListener('unhandledrejection', onUnhandled)
    }
  }, [isAuthenticated, sendEvent])

  return null
}
