export async function resizeImageFile(file: File, maxWidth = 1280, maxHeight = 1280, quality = 0.8): Promise<File> {
  if (!file.type.startsWith('image/')) return file;

  // If file size is already small, skip resizing (e.g., < 200KB)
  const SIZE_THRESHOLD = 200 * 1024;
  if (file.size <= SIZE_THRESHOLD) return file;

  const imageBitmap = await createImageBitmap(file);
  const { width: srcW, height: srcH } = imageBitmap;

  let targetW = srcW;
  let targetH = srcH;

  // Compute target size keeping aspect ratio
  const ratio = Math.min(maxWidth / srcW, maxHeight / srcH, 1);
  targetW = Math.round(srcW * ratio);
  targetH = Math.round(srcH * ratio);

  const canvas = document.createElement('canvas');
  canvas.width = targetW;
  canvas.height = targetH;
  const ctx = canvas.getContext('2d');
  if (!ctx) return file;

  ctx.drawImage(imageBitmap, 0, 0, targetW, targetH);

  const mime = file.type === 'image/png' ? 'image/png' : 'image/jpeg';

  const blob: Blob | null = await new Promise(resolve => canvas.toBlob(resolve as BlobCallback, mime, quality));
  if (!blob) return file;

  const newName = file.name.replace(/(\.[a-zA-Z0-9_-]+)?$/, '') + '_resized' + (mime === 'image/png' ? '.png' : '.jpg');
  const resizedFile = new File([blob], newName, { type: mime });
  return resizedFile;
}
