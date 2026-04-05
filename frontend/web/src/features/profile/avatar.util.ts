export const MAX_AVATAR_FILE_SIZE_BYTES = 2 * 1024 * 1024

export function validateAvatarFile(file: File): string | null {
  if (!file.type.startsWith('image/')) {
    return 'profile.avatar.errors.invalidType'
  }

  if (file.size > MAX_AVATAR_FILE_SIZE_BYTES) {
    return 'profile.avatar.errors.fileTooLarge'
  }

  return null
}

export async function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()

    reader.onload = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result)
        return
      }

      reject(new Error('Cannot read selected file.'))
    }

    reader.onerror = () => {
      reject(new Error('Cannot read selected file.'))
    }

    reader.readAsDataURL(file)
  })
}
