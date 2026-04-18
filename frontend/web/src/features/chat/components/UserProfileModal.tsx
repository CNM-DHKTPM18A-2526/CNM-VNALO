import { useEffect, useState } from 'react'
import { getUserById } from '../../friends/friends.api'
import type { UserLookupResult } from '../../friends/friends.types'
import { Modal } from '../../../shared/components/ui/Modal'
import { LoadingState } from '../../../shared/components/LoadingState'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { EmptyState } from '../../../shared/components/EmptyState'
import { useUserStore } from '../context/UserStoreContext'

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
  }
  onMessage?: (user: UserLookupResult) => void
}

export function UserProfileModal({
  isOpen,
  onClose,
  userId,
  accessToken,
  initialUser,
  onMessage,
}: UserProfileModalProps) {
  const { upsertUser } = useUserStore()
  const [profile, setProfile] = useState<Partial<UserLookupResult> | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // 1. Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setProfile(null)
      setError(null)
      setIsLoading(false)
    }
  }, [isOpen])

  // 2. Initialize profile when userId or initialUser changes
  useEffect(() => {
    if (!isOpen || !userId) return

    setProfile({
      id: userId,
      displayName: initialUser?.displayName || 'Người dùng',
      avatarUrl: initialUser?.avatarUrl || null,
      bio: initialUser?.bio,
      phone: initialUser?.phone,
      email: initialUser?.email,
      gender: initialUser?.gender,
      dob: initialUser?.dob,
    })
  }, [isOpen, userId, initialUser])

  // 3. Trigger fetch if full details (bio, phone, email) are missing
  useEffect(() => {
    if (!isOpen || !userId || !accessToken) return

    // Trigger fetch if ANY extended field is missing
    const hasExtendedInfo = !!(initialUser?.bio || initialUser?.phone || initialUser?.email)

    if (!hasExtendedInfo) {
      void fetchProfile(accessToken, userId)
    }
  }, [isOpen, userId, accessToken, initialUser])

  const fetchProfile = async (token: string, id: string) => {
    setIsLoading(true)
    setError(null)
    try {
      const data = await getUserById(token, id)
      console.log('[ProfileModal] API response:', data)
      if (data) {
        // Handle field name mismatches between backend and frontend
        const mappedData: Partial<UserLookupResult> = {
          ...data,
          dob: data.dob || (data as any).dateOfBirth || null,
          bio: data.bio || data.statusMessage || null,
        }

        setProfile((prev) => ({
          ...prev,
          ...mappedData,
        }))
        
        // Sync back to global user cache
        upsertUser(id, {
          displayName: data.displayName?.trim() || data.phone || data.email || 'Người dùng',
          avatarUrl: data.avatarUrl ?? null,
        })
      }
    } catch (err) {
      console.error('[UserProfileModal] Fetch failed:', err)
      setError('Không thể tải thông tin người dùng')
    } finally {
      setIsLoading(false)
    }
  }

  const handleCall = () => {
    if (profile?.phone) {
      window.location.href = `tel:${profile.phone}`
    }
  }

  const handleMessage = () => {
    if (profile && profile.id) {
      onMessage?.(profile as UserLookupResult)
      onClose()
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
          {profile.coverUrl ? (
            <img 
              alt={profile.displayName ?? 'Người dùng'} 
              className="contacts-profile-cover" 
              src={profile.coverUrl} 
            />
          ) : (
            <div className="contacts-profile-cover-fallback" />
          )}
          
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

          <div className="contacts-profile-actions">
            <button 
              type="button" 
              className="contacts-profile-action-btn" 
              onClick={handleCall}
              disabled={!profile.phone}
            >
              Gọi điện
            </button>
            <button
              type="button"
              className="contacts-profile-action-btn contacts-profile-action-btn-primary"
              onClick={handleMessage}
            >
              Nhắn tin
            </button>
          </div>

          <div className="contacts-profile-info">
            <h5>Thông tin cá nhân</h5>
            <div className="contacts-profile-info-grid">
              <div className="contacts-profile-info-label">Bio</div>
              <div className="contacts-profile-info-value">
                {isLoading && !profile.bio ? '...' : (profile.bio?.trim() || profile.statusMessage?.trim() || 'Chưa cập nhật')}
              </div>

              <div className="contacts-profile-info-label">Giới tính</div>
              <div className="contacts-profile-info-value">
                {isLoading && !profile.gender ? '...' : (profile.gender === 'MALE' ? 'Nam' : profile.gender === 'FEMALE' ? 'Nữ' : 'Chưa cập nhật')}
              </div>
              <div className="contacts-profile-info-label">Ngày sinh</div>
              <div className="contacts-profile-info-value">
                {isLoading && !profile.dob ? '...' : (profile.dob || 'Chưa cập nhật')}
              </div>

              <div className="contacts-profile-info-label">Điện thoại</div>
              <div className="contacts-profile-info-value">
                {isLoading && !profile.phone ? 'Đang tải...' : (profile.phone || 'Chưa cập nhật')}
              </div>

              <div className="contacts-profile-info-label">Email</div>
              <div className="contacts-profile-info-value">
                {isLoading && !profile.email ? 'Đang tải...' : (profile.email || 'Chưa cập nhật')}
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
