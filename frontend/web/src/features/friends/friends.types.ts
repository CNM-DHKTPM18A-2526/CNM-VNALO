export type FriendshipSource = 'SEARCH' | 'QR' | 'CONTACT_IMPORT' | 'SUGGESTION' | 'GROUP'

export type FriendRequestStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELED'

export type Friend = {
  friendshipId: string
  friendId: string
  displayName: string | null
  avatarUrl: string | null
  statusMessage: string | null
  nickname: string | null
  source: FriendshipSource | null
  friendsSince: string | null
}

export type FriendRequest = {
  id: string
  fromUserId: string
  fromUserDisplayName: string | null
  fromUserAvatarUrl: string | null
  toUserId: string
  toUserDisplayName: string | null
  toUserAvatarUrl: string | null
  message: string | null
  source: FriendshipSource | null
  status: FriendRequestStatus
  createdAt: string | null
  respondedAt: string | null
}

export type FriendStats = {
  friendCount: number
  pendingRequestCount: number
}

export type UserLookupResult = {
  id: string
  phone: string | null
  email: string | null
  displayName: string | null
  avatarUrl: string | null
  coverUrl: string | null
  bio: string | null
  statusMessage: string | null
}

export type FriendshipStatus = {
  areFriends: boolean
}

export type SendFriendRequestPayload = {
  toUserId: string
  message?: string
  source?: FriendshipSource
}
