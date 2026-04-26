import type {
  Friend,
  FriendRequest,
  FriendStats,
  FriendshipStatus,
  SendFriendRequestPayload,
  UserLookupResult,
} from './friends.types'

// All services route through Nginx gateway at 13.250.2.132
const API_BASE_URL = import.meta.env.VITE_CORE_API_URL ?? 'http://13.250.2.132/api/v1'

type ApiResponse<T> = {
  success?: boolean
  code?: string
  message?: string
  error?: string
  data?: T
}

type PageData<T> = {
  content?: T[]
}

function extractMessage(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const obj = payload as Record<string, unknown>

  if (typeof obj.message === 'string' && obj.message.trim()) {
    return obj.message
  }

  if (typeof obj.error === 'string' && obj.error.trim()) {
    return obj.error
  }

  return null
}

async function parseJson(response: Response): Promise<unknown> {
  return (await response.json().catch(() => null)) as unknown
}

function extractPageContent<T>(payload: unknown): T[] {
  if (!payload || typeof payload !== 'object') {
    return []
  }

  const response = payload as ApiResponse<PageData<T> | T[]>

  if (Array.isArray(response.data)) {
    return response.data
  }

  if (response.data && typeof response.data === 'object') {
    const page = response.data as PageData<T>

    if (Array.isArray(page.content)) {
      return page.content
    }
  }

  return []
}

function extractData<T>(payload: unknown): T | null {
  if (!payload || typeof payload !== 'object') {
    return null
  }

  const response = payload as ApiResponse<T>
  return response.data ?? null
}

function authHeaders(token: string) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  }
}

export async function getFriends(token: string): Promise<Friend[]> {
  const response = await fetch(`${API_BASE_URL}/friends`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot fetch friends list.')
  }

  return extractPageContent<Friend>(json)
}

export async function getIncomingFriendRequests(token: string): Promise<FriendRequest[]> {
  const response = await fetch(`${API_BASE_URL}/friends/requests/incoming`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot fetch incoming friend requests.')
  }

  return extractPageContent<FriendRequest>(json)
}

export async function getSentFriendRequests(token: string): Promise<FriendRequest[]> {
  const response = await fetch(`${API_BASE_URL}/friends/requests/sent`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot fetch sent friend requests.')
  }

  return extractPageContent<FriendRequest>(json)
}

export async function sendFriendRequest(token: string, payload: SendFriendRequestPayload): Promise<FriendRequest> {
  const response = await fetch(`${API_BASE_URL}/friends/requests`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({
      toUserId: payload.toUserId,
      message: payload.message?.trim() || undefined,
      source: payload.source ?? 'SEARCH',
    }),
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot send friend request.')
  }

  const request = extractData<FriendRequest>(json)

  if (!request) {
    throw new Error('Invalid friend request response payload.')
  }

  return request
}

export async function acceptFriendRequest(token: string, requestId: string): Promise<Friend> {
  const response = await fetch(`${API_BASE_URL}/friends/requests/${requestId}/accept`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot accept friend request.')
  }

  const friend = extractData<Friend>(json)

  if (!friend) {
    throw new Error('Invalid accept friend response payload.')
  }

  return friend
}

export async function declineFriendRequest(token: string, requestId: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/friends/requests/${requestId}/decline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot decline friend request.')
  }
}

export async function cancelSentFriendRequest(token: string, requestId: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/friends/requests/${requestId}`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot cancel friend request.')
  }
}

export async function unfriend(token: string, friendId: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/friends/${friendId}`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot unfriend user.')
  }
}

export async function checkFriendshipStatus(token: string, userId: string): Promise<FriendshipStatus> {
  const response = await fetch(`${API_BASE_URL}/friends/${userId}/status`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot check friendship status.')
  }

  const status = extractData<FriendshipStatus>(json)

  if (!status) {
    throw new Error('Invalid friendship status response payload.')
  }

  return status
}

export async function getFriendStats(token: string): Promise<FriendStats> {
  const response = await fetch(`${API_BASE_URL}/friends/stats`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot fetch friend stats.')
  }

  const stats = extractData<FriendStats>(json)

  if (!stats) {
    throw new Error('Invalid friend stats response payload.')
  }

  return stats
}

export async function searchUsers(token: string, keyword: string): Promise<UserLookupResult[]> {
  const response = await fetch(`${API_BASE_URL}/users/search?keyword=${encodeURIComponent(keyword)}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot search users.')
  }

  return extractPageContent<UserLookupResult>(json)
}

export async function getUserByPhone(token: string, phoneNumber: string): Promise<UserLookupResult | null> {
  const response = await fetch(`${API_BASE_URL}/users/phone/${encodeURIComponent(phoneNumber)}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (response.status === 404) {
    return null
  }

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot search user by phone.')
  }

  return extractData<UserLookupResult>(json)
}

export async function getUserById(token: string, userId: string): Promise<UserLookupResult | null> {
  const response = await fetch(`${API_BASE_URL}/users/${encodeURIComponent(userId)}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  const json = await parseJson(response)

  if (response.status === 404) {
    return null
  }

  if (!response.ok) {
    throw new Error(extractMessage(json) ?? 'Cannot get user profile.')
  }

  return extractData<UserLookupResult>(json)
}
