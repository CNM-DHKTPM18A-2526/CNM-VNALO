export type Gender = 'MALE' | 'FEMALE' | 'OTHER'

export type AuthUser = {
  id: string
  name: string
  email: string
  avatarUrl?: string | null
  dob?: string | null
  gender?: Gender | null
}

export type LoginPayload = {
  identifier: string
  password: string
}

export type SendRegisterOtpPayload = {
  phone: string
}

export type RegisterPayload = {
  displayName: string
  phone: string
  password: string
  otpCode: string
}
