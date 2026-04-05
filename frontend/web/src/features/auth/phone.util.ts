export function normalizeVietnamPhone(phone: string): string {
  const compact = phone.trim().replace(/[\s().-]/g, '')

  if (!compact) {
    return ''
  }

  if (/^\+84\d{9}$/.test(compact)) {
    return compact
  }

  if (/^84\d{9}$/.test(compact)) {
    return `+${compact}`
  }

  if (/^0\d{9}$/.test(compact)) {
    return `+84${compact.slice(1)}`
  }

  return compact.startsWith('+') ? compact : `+${compact}`
}

export function isNormalizedVietnamPhone(phone: string): boolean {
  return /^\+84\d{9}$/.test(phone)
}
