export type AuthUser = {
  id: string
  name: string
  email: string
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
