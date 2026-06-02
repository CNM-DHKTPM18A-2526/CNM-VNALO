import type { ConversationSummary } from '../../chat/chat.types'
import type { Friend, UserLookupResult } from '../../friends/friends.types'
import { getAiActionDefinition, getAiActionLabel, getAiActionRisk, type AiActionCommand, type AiActionParams, type AiActionPreview } from './aiActionContract'

export type AiActionIssueCode =
  | 'MISSING_TARGET'
  | 'MISSING_CONTENT'
  | 'MISSING_GROUP_NAME'
  | 'NOT_ENOUGH_GROUP_MEMBERS'
  | 'TARGET_NOT_FOUND'
  | 'TARGET_AMBIGUOUS'
  | 'UNSUPPORTED_ON_WEB'

export type AiActionIssue = {
  code: AiActionIssueCode
  message: string
  targets?: string[]
}

export type AiResolvedConversation = {
  conversation: ConversationSummary
  draft?: string
}

export type AiTargetMatch<T> = {
  value: T
  score: number
}

export type AiCreateGroupResolution = {
  groupName: string
  memberNames: string[]
  memberIds: string[]
  memberLabels: string[]
}

export type AiFriendRequestResolution = {
  targetUser: UserLookupResult
  targetLabel: string
  message?: string
}

export function normalizeLookupText(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function tokenizeLookupText(value: string) {
  return normalizeLookupText(value).split(' ').filter(Boolean)
}

export function computeTargetMatchScore(candidate: string, target: string) {
  const normalizedCandidate = normalizeLookupText(candidate)
  const normalizedTarget = normalizeLookupText(target)
  if (!normalizedCandidate || !normalizedTarget) return -1
  if (normalizedCandidate === normalizedTarget) return 1000
  if (normalizedCandidate.includes(normalizedTarget)) return 850 - Math.max(0, normalizedCandidate.length - normalizedTarget.length)
  if (normalizedTarget.includes(normalizedCandidate)) return 700 - Math.max(0, normalizedTarget.length - normalizedCandidate.length)

  const candidateTokens = tokenizeLookupText(normalizedCandidate)
  const targetTokens = tokenizeLookupText(normalizedTarget)
  if (targetTokens.length === 0) return -1
  if (!targetTokens.every((token) => candidateTokens.some((candidateToken) => candidateToken.startsWith(token)))) return -1

  let score = 500
  let cursor = 0
  for (const token of targetTokens) {
    const foundIndex = candidateTokens.findIndex((candidateToken, index) => index >= cursor && candidateToken.startsWith(token))
    if (foundIndex < 0) return -1
    score -= (foundIndex - cursor) * 8
    cursor = foundIndex + 1
  }
  if (candidateTokens[0] === targetTokens[0]) score += 30
  if (candidateTokens[candidateTokens.length - 1] === targetTokens[targetTokens.length - 1]) score += 45
  score -= Math.max(0, candidateTokens.length - targetTokens.length) * 6
  return score
}

function uniqueStrings(values: string[]) {
  const seen = new Set<string>()
  return values.filter((value) => {
    const key = normalizeLookupText(value)
    if (!key || seen.has(key)) return false
    seen.add(key)
    return true
  })
}

export function extractActionTarget(params?: AiActionParams | null) {
  if (!params) return ''
  const raw = params.target ?? params.recipient ?? params.contactName ?? params.displayName ?? params.conversationName ?? params.groupName ?? params.groupTitle ?? params.chatName ?? params.name ?? ''
  return String(raw).trim()
}

export function extractComposeContent(params?: AiActionParams | null) {
  if (!params) return ''
  return String(params.content ?? params.messageText ?? params.prefilledText ?? '').trim()
}

export function extractGroupName(params?: AiActionParams | null) {
  if (!params) return ''
  return String(params.title ?? params.groupName ?? params.name ?? '').trim()
}

export function extractGroupTargets(params?: AiActionParams | null) {
  if (!params) return []
  const rawCandidates = [
    params.members,
    params.memberNames,
    params.participants,
    params.participantNames,
    params.users,
    params.userNames,
    params.recipients,
    params.recipientNames,
    params.contacts,
    params.contactNames,
    params.target,
  ]

  return uniqueStrings(rawCandidates.flatMap((raw) => {
    if (!raw) return []
    if (Array.isArray(raw)) return raw.map((item) => String(item).trim())
    return String(raw)
      .split(/[,;\n]|\s+và\s+|\s+va\s+|\s+and\s+/i)
      .map((item) => item.trim())
  }).filter(Boolean))
}

export function extractCreateGroupIntentTargets(text: string) {
  const normalized = normalizeLookupText(text)
  if (!normalized.includes('tao nhom')) return []
  const source = text.trim()
  const match = source.match(/tạo\s+nhóm\s+(?:với|cùng|cho|gồm)?\s*(.+)$/i)
    ?? source.match(/tao\s+nhom\s+(?:voi|cung|cho|gom)?\s*(.+)$/i)
  const rawTarget = match?.[1]?.trim()
  if (!rawTarget) return []
  return uniqueStrings(rawTarget
    .replace(/^với\s+/i, '')
    .replace(/^voi\s+/i, '')
    .replace(/[.!?]+$/g, '')
    .split(/[,;\n]|\s+và\s+|\s+va\s+|\s+and\s+/i)
    .map((item) => item.trim())
    .filter(Boolean))
}

export function getFriendDisplayName(friend: Friend) {
  return friend.nickname?.trim() || friend.displayName?.trim() || ''
}

export function getLookupDisplayName(user: UserLookupResult) {
  return user.displayName?.trim() || user.phone?.trim() || user.email?.trim() || ''
}

const AMBIGUOUS_SCORE_DELTA = 24

export function findBestMatches<T>(items: T[], target: string, getLabel: (item: T) => string): AiTargetMatch<T>[] {
  return items
    .map((value) => ({ value, score: computeTargetMatchScore(getLabel(value), target) }))
    .filter((item) => item.score >= 0)
    .sort((left, right) => right.score - left.score)
}

export function validateCreateGroupTargets(friends: Friend[], requestedTargets: string[]) {
  const missingTargets: string[] = []
  const ambiguousTargets: string[] = []
  const memberIds: string[] = []
  const memberLabels: string[] = []

  uniqueStrings(requestedTargets).forEach((target) => {
    const matches = findBestMatches(friends, target, getFriendDisplayName)
    if (matches.length === 0) {
      missingTargets.push(target)
      return
    }
    const bestScore = matches[0]?.score ?? -1
    const closeMatches = matches.filter((item) => bestScore - item.score <= AMBIGUOUS_SCORE_DELTA)
    if (closeMatches.length > 1) {
      ambiguousTargets.push(target)
      return
    }
    const friend = matches[0].value
    const friendId = String(friend.friendId ?? '').trim()
    if (!friendId) {
      missingTargets.push(target)
      return
    }
    memberIds.push(friendId)
    memberLabels.push(getFriendDisplayName(friend) || target)
  })

  return { missingTargets, ambiguousTargets, memberIds: uniqueStrings(memberIds), memberLabels }
}

export function resolveCreateGroupAction(params: AiActionParams | null | undefined, friends: Friend[]): { resolution?: AiCreateGroupResolution; issues: AiActionIssue[] } {
  const groupName = extractGroupName(params)
  const memberNames = extractGroupTargets(params)
  const issues: AiActionIssue[] = []

  if (!groupName) {
    issues.push({ code: 'MISSING_GROUP_NAME', message: 'Cần tên nhóm trước khi tạo nhóm.' })
  }
  if (memberNames.length < 2) {
    issues.push({ code: 'NOT_ENOUGH_GROUP_MEMBERS', message: 'Cần ít nhất 2 thành viên khác ngoài bạn để tạo nhóm.', targets: memberNames })
  }

  const validation = validateCreateGroupTargets(friends, memberNames)
  if (validation.missingTargets.length > 0) {
    issues.push({ code: 'TARGET_NOT_FOUND', message: `Không tìm thấy ${validation.missingTargets.map((target) => `"${target}"`).join(', ')} trong danh bạ.`, targets: validation.missingTargets })
  }
  if (validation.ambiguousTargets.length > 0) {
    issues.push({ code: 'TARGET_AMBIGUOUS', message: `Có nhiều liên hệ khớp với ${validation.ambiguousTargets.map((target) => `"${target}"`).join(', ')}. Hãy nói rõ họ tên.`, targets: validation.ambiguousTargets })
  }

  if (validation.memberIds.length < 2) {
    issues.push({ code: 'NOT_ENOUGH_GROUP_MEMBERS', message: 'Can resolve fewer than 2 distinct friends for this group.', targets: memberNames })
  }

  if (issues.length > 0) return { issues }
  return {
    issues: [],
    resolution: {
      groupName,
      memberNames,
      memberIds: validation.memberIds,
      memberLabels: validation.memberLabels,
    },
  }
}

export function resolveConversationAction(command: AiActionCommand, params: AiActionParams | null | undefined, conversations: ConversationSummary[]): { resolution?: AiResolvedConversation; issues: AiActionIssue[] } {
  const target = extractActionTarget(params)
  if (!target) {
    return { issues: [{ code: 'MISSING_TARGET', message: `Cần tên người hoặc cuộc trò chuyện cho thao tác ${getAiActionLabel(command)}.` }] }
  }

  const matches = findBestMatches(conversations, target, (conversation) => conversation.name)
  if (matches.length === 0) {
    return { issues: [{ code: 'TARGET_NOT_FOUND', message: `Không tìm thấy "${target}" trong danh sách trò chuyện hoặc danh bạ.`, targets: [target] }] }
  }
  const bestScore = matches[0].score
  const closeMatches = matches.filter((item) => bestScore - item.score <= AMBIGUOUS_SCORE_DELTA)
  if (closeMatches.length > 1) {
    return { issues: [{ code: 'TARGET_AMBIGUOUS', message: `Co nhieu cuoc tro chuyen khop voi "${target}". Hay chon thu cong de tranh nham.`, targets: [target] }] }
  }

  if (command === 'START_CALL' && matches[0].value.isGroup) {
    return { issues: [{ code: 'UNSUPPORTED_ON_WEB', message: 'Trợ lý chỉ hỗ trợ chuẩn bị cuộc gọi 1-1 trong luồng này.' }] }
  }

  const draft = command === 'COMPOSE_MESSAGE' ? extractComposeContent(params) : ''
  if (command === 'COMPOSE_MESSAGE' && !draft) {
    return { issues: [{ code: 'MISSING_CONTENT', message: 'Cần nội dung nháp trước khi mở chat để soạn tin.' }] }
  }

  return { issues: [], resolution: { conversation: matches[0].value, draft } }
}

export function resolveFriendRequestAction(params: AiActionParams | null | undefined, users: UserLookupResult[]): { resolution?: AiFriendRequestResolution; issues: AiActionIssue[] } {
  const target = extractActionTarget(params)
  if (!target) {
    return { issues: [{ code: 'MISSING_TARGET', message: 'Cần tên hoặc số điện thoại người nhận lời mời kết bạn.' }] }
  }
  const matches = findBestMatches(users, target, getLookupDisplayName)
  if (matches.length === 0) {
    return { issues: [{ code: 'TARGET_NOT_FOUND', message: `Không tìm thấy người dùng "${target}".`, targets: [target] }] }
  }
  const bestScore = matches[0].score
  const closeMatches = matches.filter((item) => bestScore - item.score <= AMBIGUOUS_SCORE_DELTA)
  if (closeMatches.length > 1) {
    return { issues: [{ code: 'TARGET_AMBIGUOUS', message: `Co nhieu nguoi dung khop voi "${target}". Hay noi ro hon.`, targets: [target] }] }
  }
  return {
    issues: [],
    resolution: {
      targetUser: matches[0].value,
      targetLabel: getLookupDisplayName(matches[0].value) || target,
      message: String(params?.message ?? '').trim() || undefined,
    },
  }
}

export function buildActionPreview(command: AiActionCommand, params?: AiActionParams | null): AiActionPreview {
  return {
    targetLabel: extractActionTarget(params) || extractGroupName(params) || undefined,
    draft: extractComposeContent(params) || undefined,
    risk: getAiActionRisk(command),
  }
}

export function buildUnsupportedActionIssue(command: AiActionCommand): AiActionIssue {
  const definition = getAiActionDefinition(command)
  return {
    code: 'UNSUPPORTED_ON_WEB',
    message: `Web hiện chưa thực thi trực tiếp thao tác "${definition.label}". Hãy mở màn hình liên quan và xác nhận thủ công để đảm bảo an toàn.`,
  }
}
