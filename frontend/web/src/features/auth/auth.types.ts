export type Gender = 'MALE' | 'FEMALE' | 'OTHER'

export type AuthUser = {
  id: string
  name: string
  email: string
  phone?: string | null
  roles?: string[]
  permissions?: string[]
  avatarUrl?: string | null
  coverUrl?: string | null
  bio?: string | null
  dob?: string | null
  gender?: Gender | null
}

export type LoginPayload = {
  identifier: string
  password: string
  deviceId?: string
  deviceName?: string
  platform?: 'WEB' | 'PC'
}

export type SendRegisterOtpPayload = {
  phone: string
  email: string
}

export type RegisterPayload = {
  displayName: string
  phone: string
  email: string
  password: string
  otpCode: string
  dob?: string
  gender?: Gender
  acceptedTerms?: boolean
  acceptedPrivacy?: boolean
  legalVersion?: string
  deviceName?: string
  platform?: 'WEB' | 'PC'
}
