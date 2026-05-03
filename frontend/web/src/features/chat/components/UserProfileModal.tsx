import { useEffect, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  checkFriendshipStatus,
  getIncomingFriendRequests,
  getSentFriendRequests,
  getUserById,
  sendFriendRequest,
} from '../../friends/friends.api'
import type { UserLookupResult } from '../../friends/friends.types'
import { Modal } from '../../../shared/components/ui/Modal'
import { LoadingState } from '../../../shared/components/LoadingState'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { EmptyState } from '../../../shared/components/EmptyState'
import { Button } from '../../../shared/components/ui/Button'
import { useUserStore } from '../context/UserStoreContext'
import { useAuth } from '../../auth/useAuth'

type RelationState = 'none' | 'already-friend' | 'incoming' | 'sent' | 'self'

interface UserProfileModalProps {
  isOpen: boolean
  onClose: () => void
  userId: string | null
  accessToken: string | null
  initialUser?: {
    displayName: string
    avatarUrl: string | null
    bio?: string | null
    phone?: string | null
    email?: string | null
    gender?: string | null
    dob?: string | null
    coverUrl?: string | null
    statusMessage?: string | null
  }
  onMessage?: (user: UserLookupResult) => void
  onCall?: (user: UserLookupResult, type: 'audio' | 'video') => void | Promise<void>
  onCompleted?: () => void | Promise<void>
}

export function UserProfileModal({
  isOpen,
  onClose,
  userId,
  accessToken,
  initialUser,
  onMessage,
  onCall,
  onCompleted,
}: UserProfileModalProps) {
  const { user: currentUser } = useAuth()
  const { upsertUser } = useUserStore()
  const navigate = useNavigate()

  const [profile, setProfile] = useState<Partial<UserLookupResult> | null>(null)
  const [relation, setRelation] = useState<RelationState>('none')
  const [isLoading, setIsLoading] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  
  const [isComposingFriendRequest, setIsComposingFriendRequest] = useState(false)
  const [requestMessage, setRequestMessage] = useState('Xin chào, mình muốn kết bạn với bạn.')
  const [isCallMenuOpen, setIsCallMenuOpen] = useState(false)

  // 1. Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setProfile(null)
      setRelation('none')
      setError(null)
      setIsLoading(false)
      setIsComposingFriendRequest(false)
      setRequestMessage('Xin chào, mình muốn kết bạn với bạn.')
      setIsCallMenuOpen(false)
    }
  }, [isOpen])

  const getRelationForUser = useCallback(async (targetUserId: string): Promise<RelationState> => {
    if (!accessToken) {
      return 'none'
    }

    if (currentUser?.id === targetUserId) {
      return 'self'
    }

    try {
      const [friendshipStatus, incomingRequests, sentRequests] = await Promise.all([
        checkFriendshipStatus(accessToken, targetUserId),
        getIncomingFriendRequests(accessToken),
        getSentFriendRequests(accessToken),
      ])

      if (friendshipStatus.areFriends) {
        return 'already-friend'
      }

      const incoming = incomingRequests.find((item) => item.fromUserId === targetUserId && item.status === 'PENDING')
      if (incoming) {
        return 'incoming'
      }

      const sent = sentRequests.find((item) => item.toUserId === targetUserId && item.status === 'PENDING')
      if (sent) {
        return 'sent'
      }

      return 'none'
    } catch (err) {
      console.error('[ProfileModal] Failed to check relation:', err)
      return 'none'
    }
  }, [accessToken, currentUser?.id])

  const resolveRelationship = useCallback(async (targetUserId: string) => {
    const relationState = await getRelationForUser(targetUserId)
    setRelation(relationState)
  }, [getRelationForUser])

  // 2. Initialize profile and check relation
  useEffect(() => {
    if (!isOpen || !userId) return

    setProfile({
      id: userId,
      displayName: initialUser?.displayName || 'Người dùng',
      avatarUrl: initialUser?.avatarUrl || null,
      bio: initialUser?.bio || initialUser?.statusMessage,
      phone: initialUser?.phone,
      email: initialUser?.email,
      gender: initialUser?.gender,
      dob: initialUser?.dob,
      coverUrl: initialUser?.coverUrl,
    })

    void resolveRelationship(userId)
  }, [isOpen, userId, initialUser, resolveRelationship])

  // 3. Trigger fetch if details are missing
  useEffect(() => {
    if (!isOpen || !userId || !accessToken) return

    const hasFullInfo = !!(initialUser?.phone && initialUser?.email)
    if (!hasFullInfo) {
      void fetchProfile(accessToken, userId)
    }
  }, [isOpen, userId, accessToken, initialUser])

  const fetchProfile = async (token: string, id: string) => {
    setIsLoading(true)
    setError(null)
    try {
      const data = await getUserById(token, id)
      if (data) {
        const mappedData: Partial<UserLookupResult> = {
          ...data,
          dob: data.dob || (data as any).dateOfBirth || null,
          bio: data.bio || data.statusMessage || null,
        }

        setProfile((prev) => ({
          ...prev,
          ...mappedData,
        }))
        
        upsertUser(id, {
          displayName: data.displayName?.trim() || data.phone || data.email || 'Người dùng',
          avatarUrl: data.avatarUrl ?? null,
        })
      }
    } catch (err) {
      setError('Không thể tải thông tin người dùng')
    } finally {
      setIsLoading(false)
    }
  }

  const handleCall = (type: 'audio' | 'video') => {
    if (profile?.id) {
      void onCall?.(profile as UserLookupResult, type)
      setIsCallMenuOpen(false)
      return
    }

    if (profile?.phone) {
      window.location.href = `tel:${profile.phone}`
    }
    setIsCallMenuOpen(false)
  }

  const handleMessage = () => {
    if (profile && profile.id) {
      onMessage?.(profile as UserLookupResult)
      onClose()
    }
  }

  const handleSendFriendRequest = async () => {
    if (!accessToken || !profile?.id) return

    setIsSubmitting(true)
    setError(null)

    try {
      await sendFriendRequest(accessToken, {
        toUserId: profile.id,
        message: requestMessage,
        source: 'SEARCH',
      })

      setRelation('sent')
      setIsComposingFriendRequest(false)
      if (onCompleted) {
        await onCompleted()
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không thể gửi lời mời kết bạn')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Thông tin tài khoản"
    >
      {isLoading && !profile?.displayName ? (
        <div className="py-10">
          <LoadingState label="Đang tải hồ sơ..." />
        </div>
      ) : profile ? (
        <div className="contacts-profile-modal">
          <div 
            className={`contacts-profile-cover${profile.coverUrl ? ' contacts-profile-cover-image' : ''}`}
            style={profile.coverUrl ? { backgroundImage: `url(${profile.coverUrl})` } : undefined}
          >
            {!profile.coverUrl && <div className="contacts-profile-cover-fallback" />}
          </div>
          
          <div className="contacts-profile-head">
            <div className="contacts-profile-avatar-wrap">
              <UserAvatar
                imageUrl={profile.avatarUrl}
                name={profile.displayName ?? 'Người dùng'}
                size="lg"
              />
            </div>
            <div className="contacts-profile-name-row">
              <h4>{profile.displayName ?? 'Người dùng'}</h4>
            </div>
          </div>

          <div className="contacts-profile-actions" style={{ display: 'flex', gap: '8px' }}>
            {relation === 'already-friend' ? (
              <>
                <div style={{ position: 'relative', flex: 1 }}>
                  <button 
                    type="button" 
                    className="contacts-profile-action-btn" 
                    onClick={() => setIsCallMenuOpen(!isCallMenuOpen)}
                    disabled={false}
                    style={{ width: '100%' }}
                  >
                    Gọi điện
                  </button>
                  {isCallMenuOpen && (
                    <div style={{
                      position: 'absolute',
                      top: '100%',
                      left: 0,
                      marginTop: '4px',
                      backgroundColor: 'white',
                      border: '1px solid #e5e7eb',
                      borderRadius: '6px',
                      boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
                      minWidth: '140px',
                      zIndex: 1000,
                    }}>
                      <button
                        type="button"
                        style={{
                          display: 'block',
                          width: '100%',
                          padding: '8px 12px',
                          textAlign: 'left',
                          backgroundColor: 'transparent',
                          border: 'none',
                          cursor: 'pointer',
                          fontSize: '14px',
                          color: '#1f2937',
                          borderBottom: '1px solid #e5e7eb',
                        }}
                        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#f3f4f6')}
                        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                        onClick={() => handleCall('audio')}
                      >
                        Gọi thoại
                      </button>
                      <button
                        type="button"
                        style={{
                          display: 'block',
                          width: '100%',
                          padding: '8px 12px',
                          textAlign: 'left',
                          backgroundColor: 'transparent',
                          border: 'none',
                          cursor: 'pointer',
                          fontSize: '14px',
                          color: '#1f2937',
                        }}
                        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#f3f4f6')}
                        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                        onClick={() => handleCall('video')}
                      >
                        Gọi video
                      </button>
                    </div>
                  )}
                </div>
                <button
                  type="button"
                  className="contacts-profile-action-btn contacts-profile-action-btn-primary"
                  onClick={handleMessage}
                  style={{ flex: 1 }}
                >
                  Nhắn tin
                </button>
              </>
            ) : relation === 'self' ? (
              <button
                type="button"
                className="contacts-profile-action-btn contacts-profile-action-btn-primary w-full"
                onClick={() => navigate('/settings/profile')}
              >
                Chỉnh sửa hồ sơ
              </button>
            ) : (
              <>
                <button
                  type="button"
                  className="contacts-profile-action-btn"
                  onClick={handleMessage}
                  style={{ flex: 1 }}
                >
                  Nhắn tin
                </button>
                <button
                  type="button"
                  className="contacts-profile-action-btn contacts-profile-action-btn-primary"
                  disabled={relation !== 'none' || isSubmitting}
                  onClick={() => setIsComposingFriendRequest(true)}
                  style={{ flex: 1 }}
                >
                  {relation === 'sent' ? 'Đã gửi lời mời' : relation === 'incoming' ? 'Phản hồi lời mời' : 'Kết bạn'}
                </button>
              </>
            )}
          </div>

          {isComposingFriendRequest && (
            <div className="add-friend-request-box mt-4 p-4 bg-slate-50 dark:bg-slate-900 rounded-lg">
              <label className="text-xs font-semibold text-slate-500 mb-2 block">Tin nhắn kết bạn</label>
              <textarea
                className="w-full border rounded p-2 text-sm bg-white dark:bg-slate-800"
                maxLength={240}
                onChange={(e) => setRequestMessage(e.target.value)}
                rows={3}
                value={requestMessage}
              />
              <div className="flex justify-end gap-2 mt-3">
                <Button variant="subtle" onClick={() => setIsComposingFriendRequest(false)}>
                  Hủy
                </Button>
                <Button variant="primary" disabled={isSubmitting} onClick={handleSendFriendRequest}>
                  {isSubmitting ? 'Đang gửi...' : 'Gửi lời mời'}
                </Button>
              </div>
            </div>
          )}

          <div className="contacts-profile-info">
            <h5>Thông tin cá nhân</h5>
            <div className="contacts-profile-info-grid">
              <div className="contacts-profile-info-label">Bio</div>
              <div className="contacts-profile-info-value truncate-2-lines">
                {profile.bio?.trim() || profile.statusMessage?.trim() || 'Chưa cập nhật'}
              </div>

              <div className="contacts-profile-info-label">Giới tính</div>
              <div className="contacts-profile-info-value">
                {profile.gender === 'MALE' ? 'Nam' : profile.gender === 'FEMALE' ? 'Nữ' : 'Chưa cập nhật'}
              </div>
              <div className="contacts-profile-info-label">Ngày sinh</div>
              <div className="contacts-profile-info-value">
                {profile.dob || 'Chưa cập nhật'}
              </div>

              <div className="contacts-profile-info-label">Điện thoại</div>
              <div className="contacts-profile-info-value">
                {profile.phone || 'Chưa cập nhật'}
              </div>

              <div className="contacts-profile-info-label">Email</div>
              <div className="contacts-profile-info-value">
                {profile.email || 'Chưa cập nhật'}
              </div>
            </div>
          </div>
        </div>
      ) : (
        <EmptyState title="Không có dữ liệu" description="Không thể tìm thấy thông tin người dùng" />
      )}
      
      {error && <p className="text-red-500 text-xs text-center mt-2">{error}</p>}
    </Modal>
  )
}
