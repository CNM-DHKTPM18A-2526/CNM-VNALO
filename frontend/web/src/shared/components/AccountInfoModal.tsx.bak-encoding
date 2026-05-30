import React, { type ChangeEvent, type KeyboardEvent as ReactKeyboardEvent } from 'react'
import Cropper, { type Area } from 'react-easy-crop'

import { useAuth } from '../../features/auth/useAuth'
import { updateAvatarForUser } from '../../features/profile/avatar.service'
import { uploadCover } from '../../features/profile/cover.service'
import { getCroppedImageFile } from '../../features/profile/image-crop.util'
import { validateAvatarFile } from '../../features/profile/avatar.util'
import { Modal } from './ui/Modal'
import { UserAvatar } from './UserAvatar'
import { useLanguage } from '../i18n/LanguageContext'
import { updateProfile } from '../../features/auth/auth.api'
import type { Gender } from '../../features/auth/auth.types'

import './account-info-modal.css'

type CropTarget = 'avatar' | 'cover'

type PendingCrop = {
  kind: CropTarget
  sourceUrl: string
  originalFileName: string
  mimeType: string
}

type AccountInfoModalProps = {
  isOpen: boolean
  onClose: () => void
}

const GENDER_OPTIONS: Array<{ value: Gender; label: string }> = [
  { value: 'MALE', label: 'Nam' },
  { value: 'FEMALE', label: 'Nữ' },
  { value: 'OTHER', label: 'Khác' },
]

const AVATAR_ASPECT = 1
const COVER_ASPECT = 16 / 6
const BIO_MAX_LENGTH = 160

function formatDateOfBirth(value: string | null | undefined) {
  if (!value) return null
  const parts = value.split('-')
  if (parts.length !== 3) return value
  const [year, month, day] = parts
  return `${day}/${month}/${year}`
}

function getLocalTodayIsoDate() {
  const now = new Date()
  const offsetMs = now.getTimezoneOffset() * 60000
  return new Date(now.getTime() - offsetMs).toISOString().slice(0, 10)
}

export function AccountInfoModal({ isOpen, onClose }: AccountInfoModalProps) {
  const { t } = useLanguage()
  const { accessToken, user, updateUser } = useAuth()

  const avatarInputRef = React.useRef<HTMLInputElement | null>(null)
  const coverInputRef = React.useRef<HTMLInputElement | null>(null)

  const [avatarUrl, setAvatarUrl] = React.useState<string | null>(null)
  const [coverUrl, setCoverUrl] = React.useState<string | null>(null)
  const [previewUrl, setPreviewUrl] = React.useState<string | null>(null)
  const [coverPreviewUrl, setCoverPreviewUrl] = React.useState<string | null>(null)
  const [pendingCrop, setPendingCrop] = React.useState<PendingCrop | null>(null)
  const [cropPosition, setCropPosition] = React.useState({ x: 0, y: 0 })
  const [cropZoom, setCropZoom] = React.useState(1)
  const [croppedAreaPixels, setCroppedAreaPixels] = React.useState<Area | null>(null)
  const [isApplyingCrop, setIsApplyingCrop] = React.useState(false)
  const [isSavingAvatar, setIsSavingAvatar] = React.useState(false)
  const [isSavingCover, setIsSavingCover] = React.useState(false)
  const [isEditingProfile, setIsEditingProfile] = React.useState(false)
  const [isSavingProfile, setIsSavingProfile] = React.useState(false)
  const [avatarErrorMessage, setAvatarErrorMessage] = React.useState<string | null>(null)
  const [avatarSuccessMessage, setAvatarSuccessMessage] = React.useState<string | null>(null)
  const [coverErrorMessage, setCoverErrorMessage] = React.useState<string | null>(null)
  const [coverSuccessMessage, setCoverSuccessMessage] = React.useState<string | null>(null)
  const [profileErrorMessage, setProfileErrorMessage] = React.useState<string | null>(null)
  const [profileSuccessMessage, setProfileSuccessMessage] = React.useState<string | null>(null)
  const [draftDisplayName, setDraftDisplayName] = React.useState('')
  const [draftBio, setDraftBio] = React.useState('')
  const [draftDob, setDraftDob] = React.useState('')
  const [draftGender, setDraftGender] = React.useState<Gender | ''>('')
  const [activePreview, setActivePreview] = React.useState<{ kind: 'avatar' | 'cover'; url: string } | null>(null)

  const resolvedName = user?.name ?? 'VNALO User'
  const resolvedDob = user?.dob ?? null
  const resolvedGender = user?.gender ?? null
  const resolvedPhone = user?.phone ?? null
  const currentAvatarImage = previewUrl ?? avatarUrl
  const currentCoverImage = coverPreviewUrl ?? coverUrl
  const canPreviewAvatar = Boolean(currentAvatarImage)
  const canPreviewCover = Boolean(currentCoverImage)

  React.useEffect(() => {
    if (!isOpen) {
      return
    }

    setAvatarUrl(user?.avatarUrl ?? null)
    setCoverUrl(user?.coverUrl ?? null)
    setPreviewUrl(null)
    setCoverPreviewUrl(null)
    setPendingCrop(null)
    setCropPosition({ x: 0, y: 0 })
    setCropZoom(1)
    setCroppedAreaPixels(null)
    setAvatarErrorMessage(null)
    setAvatarSuccessMessage(null)
    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)
    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)
    setIsEditingProfile(false)
    setDraftDisplayName(user?.name ?? '')
    setDraftBio(user?.bio ?? '')
    setDraftDob(user?.dob ?? '')
    setDraftGender(user?.gender ?? '')
  }, [isOpen, user?.avatarUrl, user?.bio, user?.coverUrl, user?.dob, user?.gender, user?.name])

  React.useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl)
      if (coverPreviewUrl) URL.revokeObjectURL(coverPreviewUrl)
      if (pendingCrop?.sourceUrl) URL.revokeObjectURL(pendingCrop.sourceUrl)
    }
  }, [coverPreviewUrl, pendingCrop?.sourceUrl, previewUrl])

  const openAvatarPicker = () => avatarInputRef.current?.click()
  const openCoverPicker = () => coverInputRef.current?.click()

  const openImagePreview = (kind: 'avatar' | 'cover', imageUrl: string | null) => {
    if (!imageUrl) return
    setActivePreview({ kind, url: imageUrl })
  }

  const closeImagePreview = () => setActivePreview(null)

  const onPreviewKeyDown = (
    event: ReactKeyboardEvent<HTMLElement>,
    kind: 'avatar' | 'cover',
    imageUrl: string | null,
  ) => {
    if (event.key !== 'Enter' && event.key !== ' ') return
    event.preventDefault()
    openImagePreview(kind, imageUrl)
  }

  const closeCropModal = () => {
    if (pendingCrop?.sourceUrl) URL.revokeObjectURL(pendingCrop.sourceUrl)
    setPendingCrop(null)
    setCropPosition({ x: 0, y: 0 })
    setCropZoom(1)
    setCroppedAreaPixels(null)
    setIsApplyingCrop(false)
    if (avatarInputRef.current) avatarInputRef.current.value = ''
    if (coverInputRef.current) coverInputRef.current.value = ''
  }

  const startCropping = (kind: CropTarget, file: File) => {
    if (pendingCrop?.sourceUrl) URL.revokeObjectURL(pendingCrop.sourceUrl)
    setPendingCrop({
      kind,
      sourceUrl: URL.createObjectURL(file),
      originalFileName: file.name,
      mimeType: file.type,
    })
    setCropPosition({ x: 0, y: 0 })
    setCropZoom(1)
    setCroppedAreaPixels(null)
  }

  const onAvatarChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return
    setAvatarErrorMessage(null)
    setAvatarSuccessMessage(null)
    const errorKey = validateAvatarFile(file)
    if (errorKey) {
      setAvatarErrorMessage(t(errorKey))
      if (avatarInputRef.current) avatarInputRef.current.value = ''
      return
    }
    startCropping('avatar', file)
  }

  const onCoverChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return
    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)
    const errorKey = validateAvatarFile(file)
    if (errorKey) {
      setCoverErrorMessage(t(errorKey))
      if (coverInputRef.current) coverInputRef.current.value = ''
      return
    }
    startCropping('cover', file)
  }

  const saveAvatar = async (file: File) => {
    if (!accessToken) return
    setIsSavingAvatar(true)
    setAvatarErrorMessage(null)
    setAvatarSuccessMessage(null)
    try {
      const updatedUser = await updateAvatarForUser(accessToken, file)
      setAvatarUrl(updatedUser.avatarUrl ?? null)
      updateUser(updatedUser)
      setAvatarSuccessMessage(t('profile.avatar.messages.saveSuccess'))
    } catch {
      setAvatarErrorMessage(t('profile.avatar.messages.saveError'))
    } finally {
      setIsSavingAvatar(false)
    }
  }

  const saveCover = async (file: File) => {
    if (!accessToken) return
    setIsSavingCover(true)
    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)
    try {
      const uploadedCoverUrl = await uploadCover(file, accessToken)
      const updatedUser = await updateProfile(accessToken, { coverUrl: uploadedCoverUrl })
      setCoverUrl(updatedUser.coverUrl ?? uploadedCoverUrl)
      updateUser(updatedUser)
      setCoverSuccessMessage(t('profile.cover.messages.saveSuccess'))
    } catch {
      setCoverErrorMessage(t('profile.cover.messages.saveError'))
    } finally {
      setIsSavingCover(false)
    }
  }

  const handleConfirmCrop = async () => {
    if (!pendingCrop || !croppedAreaPixels) return
    setIsApplyingCrop(true)
    try {
      const croppedFile = await getCroppedImageFile(
        pendingCrop.sourceUrl,
        croppedAreaPixels,
        pendingCrop.originalFileName,
        pendingCrop.mimeType,
      )

      if (pendingCrop.kind === 'avatar') {
        if (previewUrl) URL.revokeObjectURL(previewUrl)
        setPreviewUrl(URL.createObjectURL(croppedFile))
        await saveAvatar(croppedFile)
      } else {
        if (coverPreviewUrl) URL.revokeObjectURL(coverPreviewUrl)
        setCoverPreviewUrl(URL.createObjectURL(croppedFile))
        await saveCover(croppedFile)
      }

      closeCropModal()
    } catch {
      if (pendingCrop.kind === 'avatar') {
        setAvatarErrorMessage(t('profile.avatar.messages.saveError'))
      } else {
        setCoverErrorMessage(t('profile.cover.messages.saveError'))
      }
      setIsApplyingCrop(false)
    }
  }

  const saveProfile = async () => {
    if (!accessToken) return

    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)

    const trimmedDisplayName = draftDisplayName.trim()
    if (!trimmedDisplayName) {
      setProfileErrorMessage(t('profile.errors.displayNameRequired'))
      return
    }

    if (trimmedDisplayName.length < 2) {
      setProfileErrorMessage(t('profile.errors.displayNameTooShort'))
      return
    }

    const todayIso = getLocalTodayIsoDate()
    if (draftDob && draftDob > todayIso) {
      setProfileErrorMessage(t('profile.errors.futureDateOfBirth'))
      return
    }

    if (!draftGender) {
      setProfileErrorMessage(t('profile.errors.invalidGender'))
      return
    }

    setIsSavingProfile(true)
    try {
      const updatedUser = await updateProfile(accessToken, {
        displayName: trimmedDisplayName,
        bio: draftBio.trim(),
        dob: draftDob || undefined,
        gender: draftGender,
      })
      updateUser(updatedUser)
      setIsEditingProfile(false)
      setProfileSuccessMessage(t('profile.messages.saveSuccess'))
    } catch {
      setProfileErrorMessage(t('profile.messages.saveError'))
    } finally {
      setIsSavingProfile(false)
    }
  }

  const genderLabel = (value: Gender | null | undefined) => {
    if (value === 'MALE') return 'Nam'
    if (value === 'FEMALE') return 'Nữ'
    if (value === 'OTHER') return 'Khác'
    return t('profile.notProvided')
  }

  if (!isOpen) {
    return null
  }

  return (
    <>
      <Modal
        isOpen={isOpen}
        onClose={onClose}
        title="Thông tin tài khoản"
        variant="custom"
      >
        <div className="account-modal-shell">
          <div
            aria-label={canPreviewCover ? 'Xem ảnh bìa' : undefined}
            className={`account-modal-cover${currentCoverImage ? ' account-modal-cover-image' : ''}${canPreviewCover ? ' account-modal-media-previewable' : ''}`}
            onClick={() => openImagePreview('cover', currentCoverImage)}
            onKeyDown={(event) => onPreviewKeyDown(event, 'cover', currentCoverImage)}
            role={canPreviewCover ? 'button' : undefined}
            style={currentCoverImage ? { backgroundImage: `url(${currentCoverImage})` } : undefined}
            tabIndex={canPreviewCover ? 0 : undefined}
          >
            <div className="account-modal-cover-actions" onClick={(event) => event.stopPropagation()} onMouseDown={(event) => event.stopPropagation()}>
              <button className="account-modal-cover-btn" type="button" onClick={openCoverPicker} disabled={isSavingCover || isApplyingCrop}>
                {isSavingCover ? 'Đang lưu...' : 'Đổi ảnh bìa'}
              </button>
            </div>
          </div>

          <div className="account-modal-head">
            <div className="account-modal-avatar-wrap">
              <div
                aria-label={canPreviewAvatar ? 'Xem ảnh đại diện' : undefined}
                className={`account-modal-avatar-trigger${canPreviewAvatar ? ' account-modal-media-previewable' : ''}`}
                onClick={() => openImagePreview('avatar', currentAvatarImage)}
                onKeyDown={(event) => onPreviewKeyDown(event, 'avatar', currentAvatarImage)}
                role={canPreviewAvatar ? 'button' : undefined}
                tabIndex={canPreviewAvatar ? 0 : undefined}
              >
                <UserAvatar imageUrl={currentAvatarImage} name={resolvedName} size="lg" />
                <button
                  aria-label="Đổi ảnh đại diện"
                  className="account-modal-avatar-change-btn"
                  onClick={(event) => {
                    event.stopPropagation()
                    openAvatarPicker()
                  }}
                  onMouseDown={(event) => event.stopPropagation()}
                  type="button"
                  disabled={isSavingAvatar || isApplyingCrop}
                >
                  <span className="account-modal-avatar-change-icon">📷</span>
                </button>
              </div>
            </div>

            <div className="account-modal-name-row">
              <h4>{resolvedName}</h4>
            </div>
          </div>

          <div className="account-modal-info">
            <h5>Thông tin cá nhân</h5>
            <div className="account-modal-info-grid">
              <div className="account-modal-info-label">Giới tính</div>
              <div className="account-modal-info-value">{genderLabel(resolvedGender)}</div>
              <div className="account-modal-info-label">Ngày sinh</div>
              <div className="account-modal-info-value">{formatDateOfBirth(resolvedDob) ?? t('profile.notProvided')}</div>
              <div className="account-modal-info-label">Điện thoại</div>
              <div className="account-modal-info-value">{resolvedPhone ?? t('profile.notProvided')}</div>
              <div className="account-modal-info-label">Tiểu sử</div>
              <div className="account-modal-info-value">{user?.bio?.trim() || t('profile.notProvided')}</div>
            </div>
          </div>

          {avatarErrorMessage || avatarSuccessMessage ? (
            <div className="account-modal-status account-modal-status-avatar">
              {avatarErrorMessage ? <p className="account-modal-status-error">{avatarErrorMessage}</p> : null}
              {avatarSuccessMessage ? <p className="account-modal-status-success">{avatarSuccessMessage}</p> : null}
            </div>
          ) : null}

          {coverErrorMessage || coverSuccessMessage ? (
            <div className="account-modal-status account-modal-status-cover">
              {coverErrorMessage ? <p className="account-modal-status-error">{coverErrorMessage}</p> : null}
              {coverSuccessMessage ? <p className="account-modal-status-success">{coverSuccessMessage}</p> : null}
            </div>
          ) : null}

          <div className="account-modal-actions">
            {!isEditingProfile ? (
              <button type="button" className="account-modal-primary-btn" onClick={() => setIsEditingProfile(true)}>
                Cập nhật
              </button>
            ) : null}
          </div>

          {isEditingProfile ? (
            <div className="account-modal-edit">
              <div className="account-modal-field">
                <label htmlFor="account-display-name">Tên hiển thị</label>
                <input
                  id="account-display-name"
                  type="text"
                  value={draftDisplayName}
                  onChange={(event) => setDraftDisplayName(event.target.value)}
                  disabled={isSavingProfile}
                />
              </div>

              <div className="account-modal-field">
                <label htmlFor="account-bio">Tiểu sử</label>
                <textarea
                  id="account-bio"
                  rows={3}
                  value={draftBio}
                  onChange={(event) => setDraftBio(event.target.value)}
                  maxLength={BIO_MAX_LENGTH}
                  disabled={isSavingProfile}
                />
                <div className="account-modal-counter">{`${draftBio.length}/${BIO_MAX_LENGTH}`}</div>
              </div>

              <div className="account-modal-field">
                <label htmlFor="account-dob">Ngày sinh</label>
                <input
                  id="account-dob"
                  type="date"
                  value={draftDob}
                  onChange={(event) => setDraftDob(event.target.value)}
                  max={getLocalTodayIsoDate()}
                  disabled={isSavingProfile}
                />
              </div>

              <div className="account-modal-field">
                <label htmlFor="account-gender">Giới tính</label>
                <select
                  id="account-gender"
                  value={draftGender}
                  onChange={(event) => setDraftGender(event.target.value as Gender | '')}
                  disabled={isSavingProfile}
                >
                  <option value=''>--</option>
                  {GENDER_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>

              {profileErrorMessage ? <p className="account-modal-feedback account-modal-feedback-error">{profileErrorMessage}</p> : null}
              {profileSuccessMessage ? <p className="account-modal-feedback account-modal-feedback-success">{profileSuccessMessage}</p> : null}

              <div className="account-modal-edit-actions">
                <button type="button" className="account-modal-primary-btn" onClick={() => void saveProfile()} disabled={isSavingProfile}>
                  {isSavingProfile ? t('profile.saving') : t('profile.save')}
                </button>
                <button type="button" className="account-modal-secondary-btn" onClick={() => setIsEditingProfile(false)} disabled={isSavingProfile}>
                  {t('profile.cancel')}
                </button>
              </div>
            </div>
          ) : null}

          <input ref={avatarInputRef} type="file" accept="image/*" className="account-modal-hidden-input" onChange={onAvatarChange} />
          <input ref={coverInputRef} type="file" accept="image/*" className="account-modal-hidden-input" onChange={onCoverChange} />
        </div>
      </Modal>

      <Modal
        closeAriaLabel={t('profile.preview.closeAriaLabel')}
        footer={
          <>
            <button className='btn btn-ghost' type='button' onClick={closeCropModal} disabled={isApplyingCrop}>
              {t('profile.crop.cancelButton')}
            </button>
            <button
              className='btn btn-primary'
              type='button'
              onClick={() => {
                void handleConfirmCrop()
              }}
              disabled={isApplyingCrop}
            >
              {isApplyingCrop ? t('profile.crop.processing') : t('profile.crop.confirmButton')}
            </button>
          </>
        }
        isOpen={Boolean(pendingCrop)}
        onClose={closeCropModal}
        title={pendingCrop?.kind === 'cover' ? t('profile.crop.coverTitle') : t('profile.crop.avatarTitle')}
        variant='image'
      >
        {pendingCrop ? (
          <div className='account-modal-crop'>
            <div className='account-modal-crop-stage'>
              <Cropper
                image={pendingCrop.sourceUrl}
                crop={cropPosition}
                zoom={cropZoom}
                aspect={pendingCrop.kind === 'avatar' ? AVATAR_ASPECT : COVER_ASPECT}
                cropShape={pendingCrop.kind === 'avatar' ? 'round' : 'rect'}
                showGrid={pendingCrop.kind === 'cover'}
                onCropChange={setCropPosition}
                onZoomChange={setCropZoom}
                onCropComplete={(_, areaPixels) => setCroppedAreaPixels(areaPixels)}
              />
            </div>
            <label className='account-modal-crop-zoom'>
              <span>{t('profile.crop.zoomLabel')}</span>
              <input
                type='range'
                min={1}
                max={3}
                step={0.01}
                value={cropZoom}
                onChange={(event) => setCropZoom(Number(event.target.value))}
              />
            </label>
          </div>
        ) : null}
      </Modal>

      <Modal
        closeAriaLabel={t('profile.preview.closeAriaLabel')}
        isOpen={Boolean(activePreview)}
        onClose={closeImagePreview}
        title={activePreview?.kind === 'cover' ? t('profile.preview.coverTitle') : t('profile.preview.avatarTitle')}
        variant='image'
      >
        {activePreview ? (
          <div className='account-modal-preview-wrap'>
            <img
              alt={activePreview.kind === 'cover' ? t('profile.preview.coverAlt') : t('profile.preview.avatarAlt')}
              className='account-modal-preview-image'
              src={activePreview.url}
            />
          </div>
        ) : null}
      </Modal>
    </>
  )
}
