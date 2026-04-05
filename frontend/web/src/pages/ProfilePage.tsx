import type { ChangeEvent } from 'react'
import { useEffect, useRef, useState } from 'react'

import { useAuth } from '../features/auth/useAuth'
import { updateAvatarForUser } from '../features/profile/avatar.service'
import { uploadCover } from '../features/profile/cover.service'
import { validateAvatarFile } from '../features/profile/avatar.util'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Card } from '../shared/components/ui/Card'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { CURRENT_USER } from '../shared/mock/data'
import { updateProfile } from '../features/auth/auth.api'

const GENDER_VALUES = ['MALE', 'FEMALE', 'OTHER'] as const

type GenderValue = (typeof GENDER_VALUES)[number]

type GenderDraft = GenderValue | ''

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

export function ProfilePage() {
  const { accessToken, isBootstrapping, user, updateUser } = useAuth()
  const { t } = useLanguage()
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const coverInputRef = useRef<HTMLInputElement | null>(null)

  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const [coverUrl, setCoverUrl] = useState<string | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [coverPreviewUrl, setCoverPreviewUrl] = useState<string | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [selectedCoverFile, setSelectedCoverFile] = useState<File | null>(null)
  const [isSavingAvatar, setIsSavingAvatar] = useState(false)
  const [isSavingCover, setIsSavingCover] = useState(false)
  const [avatarErrorMessage, setAvatarErrorMessage] = useState<string | null>(null)
  const [avatarSuccessMessage, setAvatarSuccessMessage] = useState<string | null>(null)
  const [coverErrorMessage, setCoverErrorMessage] = useState<string | null>(null)
  const [coverSuccessMessage, setCoverSuccessMessage] = useState<string | null>(null)
  const [isEditingProfile, setIsEditingProfile] = useState(false)
  const [isSavingProfile, setIsSavingProfile] = useState(false)
  const [profileErrorMessage, setProfileErrorMessage] = useState<string | null>(null)
  const [profileSuccessMessage, setProfileSuccessMessage] = useState<string | null>(null)
  const [draftDisplayName, setDraftDisplayName] = useState('')
  const [draftDob, setDraftDob] = useState('')
  const [draftGender, setDraftGender] = useState<GenderDraft>('')

  const resolvedName = user?.name ?? CURRENT_USER.name
  const resolvedDob = user?.dob ?? null
  const resolvedGender = user?.gender ?? null
  const resolvedPhone = user?.phone ?? null
  const resolvedEmail = user?.email ?? null

  useEffect(() => {
    setAvatarUrl(user?.avatarUrl ?? null)
  }, [user?.avatarUrl])

  useEffect(() => {
    setCoverUrl(user?.coverUrl ?? null)
  }, [user?.coverUrl])

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl)
      }

      if (coverPreviewUrl) {
        URL.revokeObjectURL(coverPreviewUrl)
      }
    }
  }, [coverPreviewUrl, previewUrl])

  const openFilePicker = () => {
    fileInputRef.current?.click()
  }

  const openCoverPicker = () => {
    coverInputRef.current?.click()
  }

  const startEditingProfile = () => {
    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)
    setDraftDisplayName(user?.name ?? CURRENT_USER.name)
    setDraftDob(user?.dob ?? '')
    setDraftGender(user?.gender ?? '')
    setIsEditingProfile(true)
  }

  const cancelEditingProfile = () => {
    setIsEditingProfile(false)
    setProfileErrorMessage(null)
    setProfileSuccessMessage(null)
    setDraftDisplayName(user?.name ?? CURRENT_USER.name)
    setDraftDob(user?.dob ?? '')
    setDraftGender(user?.gender ?? '')
  }

  const resetSelection = () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl)
    }

    setPreviewUrl(null)
    setSelectedFile(null)

    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const resetCoverSelection = () => {
    if (coverPreviewUrl) {
      URL.revokeObjectURL(coverPreviewUrl)
    }

    setCoverPreviewUrl(null)
    setSelectedCoverFile(null)

    if (coverInputRef.current) {
      coverInputRef.current.value = ''
    }
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

    if (previewUrl) {
      URL.revokeObjectURL(previewUrl)
    }

    setSelectedFile(file)
    setPreviewUrl(URL.createObjectURL(file))
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

    if (coverPreviewUrl) {
      URL.revokeObjectURL(coverPreviewUrl)
    }

    setSelectedCoverFile(file)
    setCoverPreviewUrl(URL.createObjectURL(file))
  }

  const saveAvatar = async () => {
    if (!selectedFile || !accessToken) {
      return
    }

    setIsSavingAvatar(true)
    setAvatarErrorMessage(null)
    setAvatarSuccessMessage(null)

    try {
      const updatedUser = await updateAvatarForUser(accessToken, selectedFile)
      setAvatarUrl(updatedUser.avatarUrl ?? null)
      updateUser(updatedUser)
      setAvatarSuccessMessage(t('profile.avatar.messages.saveSuccess'))
      resetSelection()
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

  const saveCover = async () => {
    if (!selectedCoverFile || !accessToken) {
      return
    }

    setIsSavingCover(true)
    setCoverErrorMessage(null)
    setCoverSuccessMessage(null)

    try {
      const uploadedCoverUrl = await uploadCover(selectedCoverFile, accessToken)
      const updatedUser = await updateProfile(accessToken, {
        coverUrl: uploadedCoverUrl,
      })

      setCoverUrl(updatedUser.coverUrl ?? uploadedCoverUrl)
      updateUser(updatedUser)
      setCoverSuccessMessage(t('profile.cover.messages.saveSuccess'))
      resetCoverSelection()
    } catch {
      setCoverErrorMessage(t('profile.cover.messages.saveError'))
    } finally {
      setIsSavingCover(false)
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
          className={`profile-cover${coverPreviewUrl || coverUrl ? ' profile-cover-has-image' : ''}`}
          style={coverPreviewUrl || coverUrl ? { backgroundImage: `url(${coverPreviewUrl ?? coverUrl})` } : undefined}
        >
          <div className='profile-cover-actions'>
            <button className='btn btn-ghost profile-cover-change-btn' type='button' onClick={openCoverPicker} disabled={isSavingCover}>
              {t('profile.cover.changeButton')}
            </button>
            {selectedCoverFile ? (
              <>
                <button className='btn btn-primary profile-cover-save-btn' type='button' onClick={saveCover} disabled={isSavingCover}>
                  {isSavingCover ? t('profile.cover.savingButton') : t('profile.cover.saveButton')}
                </button>
                <button className='btn btn-ghost profile-cover-cancel-btn' type='button' onClick={resetCoverSelection} disabled={isSavingCover}>
                  {t('profile.cover.cancelButton')}
                </button>
              </>
            ) : null}
          </div>
        </div>

        <div className='profile-header'>
          <div className='profile-avatar-wrap'>
            <button
              className='profile-avatar-trigger'
              onClick={openFilePicker}
              type='button'
              disabled={isSavingAvatar}
            >
              <UserAvatar imageUrl={previewUrl ?? avatarUrl} name={resolvedName} size='lg' />
              <span className='profile-avatar-overlay'>{t('profile.avatar.changeButton')}</span>
            </button>
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

        <div className='profile-body'>
          {coverErrorMessage ? (
            <p className='profile-avatar-feedback profile-avatar-feedback-error'>{coverErrorMessage}</p>
          ) : null}
          {coverSuccessMessage ? (
            <p className='profile-avatar-feedback profile-avatar-feedback-success'>{coverSuccessMessage}</p>
          ) : null}

          {selectedFile || avatarErrorMessage || avatarSuccessMessage ? (
            <div className='profile-avatar-panel'>
              <div className='profile-avatar-actions'>
                {selectedFile ? (
                  <>
                    <button className='btn btn-primary' type='button' onClick={saveAvatar} disabled={isSavingAvatar}>
                      {isSavingAvatar ? t('profile.avatar.savingButton') : t('profile.avatar.saveButton')}
                    </button>
                    <button
                      className='btn btn-ghost'
                      type='button'
                      onClick={resetSelection}
                      disabled={isSavingAvatar}
                    >
                      {t('profile.avatar.cancelButton')}
                    </button>
                  </>
                ) : null}
              </div>

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
