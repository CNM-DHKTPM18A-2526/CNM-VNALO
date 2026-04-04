export type AuthUser = {
  id: string
  name: string
  email: string
}

export type LoginPayload = {
  identifier: string
  password: string
}
