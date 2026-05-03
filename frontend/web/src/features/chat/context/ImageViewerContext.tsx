import React, { createContext } from 'react'

export type ImageViewerContextValue = {
  openImageViewerByMessageId: (messageId: string) => void
  openImageViewerByUrl: (url: string) => void
  closeImageViewer: () => void
}

export const ImageViewerContext = createContext<ImageViewerContextValue | null>(null)

export function useImageViewer(): ImageViewerContextValue {
  const context = React.useContext(ImageViewerContext)

  if (!context) {
    throw new Error('useImageViewer must be used inside ImageViewerProvider')
  }

  return context
}
