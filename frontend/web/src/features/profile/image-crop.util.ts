type CropArea = {
  x: number
  y: number
  width: number
  height: number
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error('Unable to load image for cropping.'))
    image.src = src
  })
}

function sanitizeFileName(name: string): string {
  const trimmed = name.trim()
  return trimmed.length > 0 ? trimmed.replace(/\s+/g, '_') : 'cropped-image.jpg'
}

export async function getCroppedImageFile(
  imageSrc: string,
  crop: CropArea,
  fileName: string,
  mimeType: string,
): Promise<File> {
  const image = await loadImage(imageSrc)

  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.round(crop.width))
  canvas.height = Math.max(1, Math.round(crop.height))

  const context = canvas.getContext('2d')
  if (!context) {
    throw new Error('Unable to crop image.')
  }

  context.drawImage(
    image,
    crop.x,
    crop.y,
    crop.width,
    crop.height,
    0,
    0,
    canvas.width,
    canvas.height,
  )

  const normalizedMime = mimeType.startsWith('image/') ? mimeType : 'image/jpeg'
  const blob = await new Promise<Blob | null>((resolve) => {
    canvas.toBlob((value) => resolve(value), normalizedMime, 0.92)
  })

  if (!blob) {
    throw new Error('Unable to export cropped image.')
  }

  return new File([blob], sanitizeFileName(fileName), {
    type: blob.type || normalizedMime,
    lastModified: Date.now(),
  })
}
