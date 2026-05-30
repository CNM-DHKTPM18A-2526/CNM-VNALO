/**
 * Shared password validation utility.
 * Implements the same policy as the backend (RegisterRequest).
 *
 * Backend rules:
 * - @Size(min = 8, max = 100)
 * - @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).+$")
 */

export function validatePassword(password: string): string | null {
  if (!password) {
    return 'Vui lòng nhập mật khẩu'
  }

  if (password.length < 8) {
    return 'Mật khẩu phải tối thiểu 8 ký tự'
  }

  if (password.length > 100) {
    return 'Mật khẩu không được vượt quá 100 ký tự'
  }

  if (!/[a-z]/.test(password)) {
    return 'Mật khẩu phải có ít nhất 1 ký tự thường (a-z)'
  }

  if (!/[A-Z]/.test(password)) {
    return 'Mật khẩu phải có ít nhất 1 ký tự in hoa (A-Z)'
  }

  if (!/\d/.test(password)) {
    return 'Mật khẩu phải có ít nhất 1 chữ số (0-9)'
  }

  return null
}

export function isValidPassword(password: string): boolean {
  return validatePassword(password) === null
}

export function getPasswordRequirements(): string[] {
  return [
    'Tối thiểu 8 ký tự',
    'Ít nhất 1 ký tự in hoa (A-Z)',
    'Ít nhất 1 ký tự thường (a-z)',
    'Ít nhất 1 chữ số (0-9)',
  ]
}
