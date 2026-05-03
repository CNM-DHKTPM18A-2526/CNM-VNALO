import type { ChangeEvent, KeyboardEvent as ReactKeyboardEvent } from 'react'
import React from 'react'
import Cropper, { type Area } from 'react-easy-crop'

import { useAuth } from '../features/auth/useAuth'
import { updateAvatarForUser } from '../features/profile/avatar.service'
import { uploadCover } from '../features/profile/cover.service'
import { getCroppedImageFile } from '../features/profile/image-crop.util'
import { validateAvatarFile } from '../features/profile/avatar.util'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Card } from '../shared/components/ui/Card'
import { Modal } from '../shared/components/ui/Modal'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { CURRENT_USER } from '../shared/mock/data'
import { updateProfile } from '../features/auth/auth.api'

const GENDER_VALUES = ['MALE', 'FEMALE', 'OTHER'] as const

type GenderValue = (typeof GENDER_VALUES)[number]

type GenderDraft = GenderValue | ''
type PreviewImageKind = 'avatar' | 'cover'
type CropTarget = 'avatar' | 'cover'
type PendingCrop = {
  kind: CropTarget
  sourceUrl: string
  originalFileName: string
  mimeType: string
}

function isGenderValue(value: string): value is GenderValue {
  return (GENDER_VALUES as readonly string[]).includes(value)
}

function formatDateOfBirth(value: string | null | undefined) {
  if (!value) {
    return null
  }

  const parts = value.split('-')
  if (parts.length !== 3) {
    return value
  }

  const [year, month, day] = parts
  return `${day}/${month}/${year}`
}

function getLocalTodayIsoDate() {
  const now = new Date()
  const offsetMs = now.getTimezoneOffset() * 60000
  return new Date(now.getTime() - offsetMs).toISOString().slice(0, 10)
}

const PROFILE_BIO_MAX_LENGTH = 160
const AVATAR_ASPECT = 1
const COVER_ASPECT = 16 / 6

export function ProfilePage() {
  const { accessToken, isBootstrapping, user, updateUser } = useAuth()
  const { t } = useLanguage()
  const fileInputRef = React.useRef<HTMLInputElement | null>(null)
  const coverInputRef = React.useRef<HTMLInputElement | null>(null)

  const [avatarUrl, setAvatarUrl] = React.useState<string | null>(null)
  const [coverUrl, setCoverUrl] = React.useState<string | null>(null)
  const [previewUrl, setPreviewUrl] = React.useState<string | null>(null)
  const [coverPreviewUrl, setCoverPreviewUrl] = React.useState<string | null>(null)
  const [isSavingAvatar, setIsSavingAvatar] = React.useState(false)
  const [isSavingCover, setIsSavingCover] = React.useState(false)
  const [isApplyingCrop, setIsApplyingCrop] = React.useState(false)
  const [pendingCrop, setPendingCrop] = React.useState<PendingCrop | null>(null)
  const [cropPosition, setCropPosition] = React.useState({ x: 0, y: 0 })
  const [cropZoom, setCropZoom] = React.useState(1)
  const [croppedAreaPixels, setCroppedAreaPixels] = React.useState<Area | null>(null)
  const [avatarErrorMessage, setAvatarErrorMessage] = React.useState<string | null>(null)
  const [avatarSuccessMessage, setAvatarSuccessMessage] = React.useState<string | null>(null)
  const [coverErrorMessage, setCoverErrorMessage] = React.useState<string | null>(null)
  const [coverSuccessMessage, setCoverSuccessMessage] = React.useState<string | null>(null)
  const [isEditingProfile, setIsEditingProfile] = React.useState(false)
  const [isSavingProfile, setIsSavingProfile] = React.useState(false)
  const [profileErrorMessage, setProfileErrorMessage] = React.useState<string | null>(null)
  const [profileSuccessMessage, setProfileSuccessMessage] = React.useState<string | null>(null)
  const [draftDisplayName, setDraftDisplayName] = React.useState('')
  const [draftBio, setDraftBio] = React.useState('')
  const [draftDob, setDraftDob] = React.useState('')
  const [draftGender, setDraftGender] = React.useState<GenderDraft>('')
  const [activePreview, setActivePreview] = React.useState<{ kind: PreviewImageKind; url: string } | null>(null)

  const resolvedName = user?.name ?? CURRENT_USER.name
  const resolvedDob = user?.dob ?? null
  const resolvedGender = user?.gender ?? null
  const resolvedBio = user?.bio ?? null
  const resolvedPhone = user?.phone ?? null
  const resolvedEmail = user?.email ?? null
  const currentAvatarImage = previewUrl ?? avatarUrl
  const currentCoverImage = coverPreviewUrl ?? coverUrl
  const canPreviewAvatar = Boolean(currentAvatarImage)
  const canPreviewCover = Boolean(currentCoverImage)

  React.useEffect(() => {
    setAvatarUrl(user?.avatarUrl ?? null)
  }, [user?.avatarUrl])

  React.useEffect(() => {
    setCoverUrl(user?.coverUrl ?? null)
  }, [user?.coverUrl])

  React.useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl)
      }

      if (coverPreviewUrl) {
        URL.revokeObjectURL(coverPreviewUrl)
      }

      if (pendingCrop?.sourceUrl) {
        URL.revokeObjectURL(pendingCrop.sourceUrl)
      }
    }
  }, [coverPreviewUrl, pendingCrop?.sourceUrl, previewUrl])

  const openFilePicker = () => {
    fileInputRef.current?.click()
  }

  const openCoverPicker = () => {
    coverInputRef.current?.click()
  }

  const openImagePreview = (kind: PreviewImageKind, imageUrl: string | null) => {
    if (!imageUrl) {
      return
    }

    setActivePreview({ kind, url: imageUrl })
  }

  const closeImagePreview = () => {
    setActivePreview(null)
  }

  const onPreviewKeyDown = (
    event: ReactKeyboardEvent<HTMLElement>,
    kind: PreviewImageKind,
    imageUrl: string | null,
  ) => {
    if (event.key !== 'Enter' && event.key !== ' ') {
      return
    }

    event.preventDefault()
    openImagePreview(kind, imageUrl)
  }

  const startEditingProfile = () => {
    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)
    setDraftDisplayName(user?.name ?? CURRENT_USER.name)
    setDraftBio(user?.bio ?? '')
    setDraftDob(user?.dob ?? '')
    setDraftGender(user?.gender ?? '')
    setIsEditingProfile(true)
  }

  const cancelEditingProfile = () => {
    setIsEditingProfile(false)
    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)
    setDraftDisplayName(user?.name ?? CURRENT_USER.name)
    setDraftBio(user?.bio ?? '')
    setDraftDob(user?.dob ?? '')
    setDraftGender(user?.gender ?? '')
  }

  const resetSelection = () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl)
    }

    setPreviewUrl(null)

    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const resetCoverSelection = () => {
    if (coverPreviewUrl) {
      URL.revokeObjectURL(coverPreviewUrl)
    }

    setCoverPreviewUrl(null)

    if (coverInputRef.current) {
      coverInputRef.current.value = ''
    }
  }

  const closeCropModal = () => {
    if (pendingCrop?.sourceUrl) {
      URL.revokeObjectURL(pendingCrop.sourceUrl)
    }

    setPendingCrop(null)
    setCropPosition({ x: 0, y: 0 })
    setCropZoom(1)
    setCroppedAreaPixels(null)
    setIsApplyingCrop(false)

    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
    if (coverInputRef.current) {
      coverInputRef.current.value = ''
    }
  }

  const startCropping = (kind: CropTarget, file: File) => {
    if (pendingCrop?.sourceUrl) {
      URL.revokeObjectURL(pendingCrop.sourceUrl)
    }

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

  const onFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]

    if (!file) {
      return
    }

    setAvatarErrorMessage(null)
    setAvatarSuccessMessage(null)

    const errorKey = validateAvatarFile(file)
    if (errorKey) {
      setAvatarErrorMessage(t(errorKey))
      resetSelection()
      return
    }

    startCropping('avatar', file)
  }

  const onCoverFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]

    if (!file) {
      return
    }

    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)

    const errorKey = validateAvatarFile(file)
    if (errorKey) {
      setCoverErrorMessage(t(errorKey))
      resetCoverSelection()
      return
    }

    startCropping('cover', file)
  }

  const saveAvatar = async (file: File) => {
    if (!accessToken) {
      return
    }

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

  const saveProfile = async () => {
    if (!accessToken) {
      return
    }

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

    if (!draftGender || !isGenderValue(draftGender)) {
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

  const saveCover = async (file: File) => {
    if (!accessToken) {
      return
    }

    setIsSavingCover(true)
    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)

    try {
      const uploadedCoverUrl = await uploadCover(file, accessToken)
      const updatedUser = await updateProfile(accessToken, {
        coverUrl: uploadedCoverUrl,
      })

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
    if (!pendingCrop || !croppedAreaPixels) {
      return
    }

    setIsApplyingCrop(true)

    try {
      const croppedFile = await getCroppedImageFile(
        pendingCrop.sourceUrl,
        croppedAreaPixels,
        pendingCrop.originalFileName,
        pendingCrop.mimeType,
      )

      if (pendingCrop.kind === 'avatar') {
        if (previewUrl) {
          URL.revokeObjectURL(previewUrl)
        }
        setPreviewUrl(URL.createObjectURL(croppedFile))
        await saveAvatar(croppedFile)
        resetSelection()
      } else {
        if (coverPreviewUrl) {
          URL.revokeObjectURL(coverPreviewUrl)
        }
        setCoverPreviewUrl(URL.createObjectURL(croppedFile))
        await saveCover(croppedFile)
        resetCoverSelection()
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

  const genderLabel = (value: string | null | undefined) => {
    if (value === 'MALE') return t('profile.genderLabels.male')
    if (value === 'FEMALE') return t('profile.genderLabels.female')
    if (value === 'OTHER') return t('profile.genderLabels.other')

    return t('profile.notProvided')
  }

  if (isBootstrapping) {
    return (
      <section className='panel-page profile-page'>
        <div className='profile-page-head'>
          <h2>{t('pages.profile.title')}</h2>
          <p className='panel-subtitle'>{t('pages.profile.subtitle')}</p>
        </div>
        <Card className='profile-card profile-card-zalo'>
          <Skeleton className='profile-cover-skeleton' />
          <div className='profile-header'>
            <Skeleton className='profile-avatar-skeleton' />
            <div className='profile-copy'>
              <Skeleton className='skeleton-line skeleton-line-title' />
              <Skeleton className='skeleton-line skeleton-line-short' />
            </div>
          </div>
        </Card>
      </section>
    )
  }

  return (
    <section className='panel-page profile-page'>
      <div className='profile-page-head'>
        <h2>{t('pages.profile.title')}</h2>
        <p className='panel-subtitle'>{t('pages.profile.subtitle')}</p>
      </div>
      <Card className='profile-card profile-card-zalo'>
        <div
          aria-label={canPreviewCover ? t('profile.cover.viewAriaLabel') : undefined}
          className={`profile-cover${currentCoverImage ? ' profile-cover-has-image' : ''}${canPreviewCover ? ' profile-media-previewable' : ''}`}
          onClick={() => openImagePreview('cover', currentCoverImage)}
          onKeyDown={(event) => onPreviewKeyDown(event, 'cover', currentCoverImage)}
          role={canPreviewCover ? 'button' : undefined}
          style={currentCoverImage ? { backgroundImage: `url(${currentCoverImage})` } : undefined}
          tabIndex={canPreviewCover ? 0 : undefined}
        >
          <div className='profile-cover-actions' onClick={(event) => event.stopPropagation()} onMouseDown={(event) => event.stopPropagation()}>
            <button className='btn btn-ghost profile-cover-change-btn' type='button' onClick={openCoverPicker} disabled={isSavingCover}>
              {isSavingCover ? t('profile.cover.savingButton') : t('profile.cover.changeButton')}
            </button>
          </div>
        </div>

        <div className='profile-header'>
          <div className='profile-avatar-wrap'>
            <div
              aria-label={canPreviewAvatar ? t('profile.avatar.viewAriaLabel') : undefined}
              className={`profile-avatar-trigger${canPreviewAvatar ? ' profile-media-previewable' : ''}`}
              onClick={() => openImagePreview('avatar', currentAvatarImage)}
              onKeyDown={(event) => onPreviewKeyDown(event, 'avatar', currentAvatarImage)}
              role={canPreviewAvatar ? 'button' : undefined}
              tabIndex={canPreviewAvatar ? 0 : undefined}
            >
              <UserAvatar imageUrl={currentAvatarImage} name={resolvedName} size='lg' />
              <button
                aria-label={t('profile.avatar.changeButton')}
                className='profile-avatar-overlay-btn'
                onClick={(event) => {
                  event.stopPropagation()
                  openFilePicker()
                }}
                onMouseDown={(event) => event.stopPropagation()}
                type='button'
                disabled={isSavingAvatar}
              >
                <span className='profile-avatar-overlay'>{t('profile.avatar.changeButton')}</span>
              </button>
            </div>
          </div>

          <div className='profile-copy'>
            <div className='profile-copy-head'>
              <h3>{resolvedName}</h3>
            </div>
          </div>

          <div className='profile-header-actions'>
            {!isEditingProfile ? (
              <button className='btn btn-primary profile-edit-main' type='button' onClick={startEditingProfile}>
                {t('profile.update')}
              </button>
            ) : null}
          </div>
        </div>

        <input
          ref={fileInputRef}
          type='file'
          accept='image/*'
          className='profile-avatar-input'
          onChange={onFileChange}
        />
        <input
          ref={coverInputRef}
          type='file'
          accept='image/*'
          className='profile-cover-input'
          onChange={onCoverFileChange}
        />

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
            <div className='profile-crop-modal'>
              <div className='profile-crop-stage'>
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
              <label className='profile-crop-zoom'>
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
            <div className='profile-image-preview-wrap'>
              <img
                alt={activePreview.kind === 'cover' ? t('profile.preview.coverAlt') : t('profile.preview.avatarAlt')}
                className='profile-image-preview'
                src={activePreview.url}
              />
            </div>
          ) : null}
        </Modal>

        <div className='profile-body'>
          {coverErrorMessage ? (
            <p className='profile-avatar-feedback profile-avatar-feedback-error'>{coverErrorMessage}</p>
          ) : null}
          {coverSuccessMessage ? (
            <p className='profile-avatar-feedback profile-avatar-feedback-success'>{coverSuccessMessage}</p>
          ) : null}

          {avatarErrorMessage || avatarSuccessMessage ? (
            <div className='profile-avatar-panel'>
              <p className='profile-avatar-hint'>{t('profile.avatar.hint')}</p>
              {avatarErrorMessage ? (
                <p className='profile-avatar-feedback profile-avatar-feedback-error'>{avatarErrorMessage}</p>
              ) : null}
              {avatarSuccessMessage ? (
                <p className='profile-avatar-feedback profile-avatar-feedback-success'>{avatarSuccessMessage}</p>
              ) : null}
            </div>
          ) : null}

          <div className='profile-content-panel'>
            <div className='profile-basic-info'>
              <div className='profile-basic-info-head'>
                <span className='profile-basic-info-title'>{t('pages.profile.basicInfoTitle')}</span>
              </div>

              {isEditingProfile ? (
                <div className='profile-edit-form'>
                  <div className='profile-edit-field'>
                    <label htmlFor='profile-display-name'>{t('auth.displayNameLabel')}</label>
                    <input
                      id='profile-display-name'
                      type='text'
                      value={draftDisplayName}
                      onChange={(event) => setDraftDisplayName(event.target.value)}
                      autoComplete='name'
                      disabled={isSavingProfile}
                    />
                  </div>

                  <div className='profile-edit-field'>
                    <label htmlFor='profile-bio'>{t('profile.bio')}</label>
                    <textarea
                      id='profile-bio'
                      rows={4}
                      value={draftBio}
                      onChange={(event) => setDraftBio(event.target.value)}
                      placeholder={t('profile.bioPlaceholder')}
                      maxLength={PROFILE_BIO_MAX_LENGTH}
                      disabled={isSavingProfile}
                    />
                    <div className='profile-bio-counter' aria-live='polite'>
                      {`${draftBio.length}/${PROFILE_BIO_MAX_LENGTH} ${t('profile.bioMaxLength')}`}
                    </div>
                  </div>

                  <div className='profile-edit-field'>
                    <label htmlFor='profile-dob'>{t('profile.dateOfBirth')}</label>
                    <input
                      id='profile-dob'
                      type='date'
                      value={draftDob}
                      onChange={(event) => setDraftDob(event.target.value)}
                      max={getLocalTodayIsoDate()}
                      disabled={isSavingProfile}
                    />
                  </div>

                  <div className='profile-edit-field'>
                    <label htmlFor='profile-gender'>{t('profile.gender')}</label>
                    <select
                      id='profile-gender'
                      value={draftGender}
                      onChange={(event) => setDraftGender(event.target.value as GenderDraft)}
                      disabled={isSavingProfile}
                    >
                      <option value=''>--</option>
                      <option value='MALE'>{t('profile.genderLabels.male')}</option>
                      <option value='FEMALE'>{t('profile.genderLabels.female')}</option>
                      <option value='OTHER'>{t('profile.genderLabels.other')}</option>
                    </select>
                  </div>

                  {profileErrorMessage ? (
                    <p className='profile-feedback profile-feedback-error'>{profileErrorMessage}</p>
                  ) : null}
                  {profileSuccessMessage ? (
                    <p className='profile-feedback profile-feedback-success'>{profileSuccessMessage}</p>
                  ) : null}

                  <div className='profile-edit-actions'>
                    <button className='btn btn-primary' type='button' onClick={saveProfile} disabled={isSavingProfile}>
                      {isSavingProfile ? t('profile.saving') : t('profile.save')}
                    </button>
                    <button className='btn btn-ghost' type='button' onClick={cancelEditingProfile} disabled={isSavingProfile}>
                      {t('profile.cancel')}
                    </button>
                  </div>
                </div>
              ) : (
                <div className='profile-basic-info-list'>
                  <div className='profile-basic-info-item profile-basic-info-item-bio'>
                    <span className='profile-basic-info-label'>{t('profile.bio')}</span>
                    <span className='profile-basic-info-value profile-bio-value'>
                      {resolvedBio && resolvedBio.trim() ? resolvedBio : t('profile.bioPlaceholder')}
                    </span>
                  </div>
                  <div className='profile-basic-info-item'>
                    <span className='profile-basic-info-label'>{t('profile.phone')}</span>
                    <span className='profile-basic-info-value'>
                      {resolvedPhone ?? resolvedEmail ?? t('profile.notProvided')}
                    </span>
                  </div>
                  <div className='profile-basic-info-item'>
                    <span className='profile-basic-info-label'>{t('profile.dateOfBirth')}</span>
                    <span className='profile-basic-info-value'>
                      {formatDateOfBirth(resolvedDob) ?? t('profile.notProvided')}
                    </span>
                  </div>
                  <div className='profile-basic-info-item'>
                    <span className='profile-basic-info-label'>{t('profile.gender')}</span>
                    <span className='profile-basic-info-value'>{genderLabel(resolvedGender)}</span>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </Card>
    </section>
  )
}
