import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
  type TouchEvent as ReactTouchEvent,
  type WheelEvent as ReactWheelEvent,
} from 'react'
import { ChevronLeft, ChevronRight, Download, X, ZoomIn, ZoomOut } from 'lucide-react'

import type { ViewerImageItem } from '../chat.types'

import { ImageViewerContext, type ImageViewerContextValue } from '../context/ImageViewerContext'

type ImageViewerProviderProps = {
  images: ViewerImageItem[]
  children: ReactNode
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

export function ImageViewerProvider({ images, children }: ImageViewerProviderProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(0)
  const [scale, setScale] = useState(1)

  const pinchDistanceRef = useRef<number | null>(null)
  const pinchScaleRef = useRef(1)
  const swipeStartXRef = useRef<number | null>(null)

  const canNavigate = images.length > 1
  const activeItem = images[activeIndex] ?? null

  const openByIndex = useCallback(
    (index: number) => {
      if (images.length === 0) {
        return
      }

      setActiveIndex(clamp(index, 0, images.length - 1))
      setScale(1)
      setIsOpen(true)
    },
    [images.length],
  )

  const openImageViewerByMessageId = useCallback(
    (messageId: string) => {
      const index = images.findIndex((item) => item.messageId === messageId)
      if (index >= 0) {
        openByIndex(index)
      }
    },
    [images, openByIndex],
  )

  const openImageViewerByUrl = useCallback(
    (url: string) => {
      const index = images.findIndex((item) => item.url === url)
      if (index >= 0) {
        openByIndex(index)
      }
    },
    [images, openByIndex],
  )

  const closeImageViewer = useCallback(() => {
    setIsOpen(false)
    setScale(1)
    pinchDistanceRef.current = null
    swipeStartXRef.current = null
  }, [])

  const handlePrev = useCallback(() => {
    if (!canNavigate) {
      return
    }
    setActiveIndex((prev) => (prev - 1 + images.length) % images.length)
    setScale(1)
  }, [canNavigate, images.length])

  const handleNext = useCallback(() => {
    if (!canNavigate) {
      return
    }
    setActiveIndex((prev) => (prev + 1) % images.length)
    setScale(1)
  }, [canNavigate, images.length])

  const handleWheelZoom = (event: ReactWheelEvent<HTMLImageElement>) => {
    event.preventDefault()
    const delta = event.deltaY < 0 ? 0.12 : -0.12
    setScale((prev) => clamp(prev + delta, 1, 4))
  }

  const getTouchDistance = (event: ReactTouchEvent) => {
    if (event.touches.length < 2) {
      return null
    }

    const first = event.touches.item(0)
    const second = event.touches.item(1)
    if (!first || !second) {
      return null
    }

    const dx = first.clientX - second.clientX
    const dy = first.clientY - second.clientY
    return Math.hypot(dx, dy)
  }

  const handleTouchStart = (event: ReactTouchEvent<HTMLImageElement>) => {
    if (event.touches.length === 1) {
      swipeStartXRef.current = event.touches[0].clientX
      pinchDistanceRef.current = null
      return
    }

    const distance = getTouchDistance(event)
    if (distance) {
      pinchDistanceRef.current = distance
      pinchScaleRef.current = scale
    }
  }

  const handleTouchMove = (event: ReactTouchEvent<HTMLImageElement>) => {
    if (event.touches.length < 2 || pinchDistanceRef.current === null) {
      return
    }

    const distance = getTouchDistance(event)
    if (!distance) {
      return
    }

    const ratio = distance / pinchDistanceRef.current
    setScale(clamp(pinchScaleRef.current * ratio, 1, 4))
  }

  const handleTouchEnd = (event: ReactTouchEvent<HTMLImageElement>) => {
    if (event.touches.length > 0) {
      return
    }

    pinchDistanceRef.current = null

    if (!canNavigate || scale > 1.05 || swipeStartXRef.current === null) {
      swipeStartXRef.current = null
      return
    }

    const endX = event.changedTouches[0]?.clientX
    if (typeof endX !== 'number') {
      swipeStartXRef.current = null
      return
    }

    const deltaX = endX - swipeStartXRef.current
    swipeStartXRef.current = null

    if (Math.abs(deltaX) < 60) {
      return
    }

    if (deltaX < 0) {
      handleNext()
    } else {
      handlePrev()
    }
  }

  useEffect(() => {
    if (!isOpen) {
      return
    }

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeImageViewer()
      }
      if (event.key === 'ArrowLeft') {
        handlePrev()
      }
      if (event.key === 'ArrowRight') {
        handleNext()
      }
    }

    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKeyDown)

    return () => {
      document.body.style.overflow = ''
      window.removeEventListener('keydown', onKeyDown)
    }
  }, [closeImageViewer, handleNext, handlePrev, isOpen])

  const contextValue = useMemo<ImageViewerContextValue>(
    () => ({
      openImageViewerByMessageId,
      openImageViewerByUrl,
      closeImageViewer,
    }),
    [closeImageViewer, openImageViewerByMessageId, openImageViewerByUrl],
  )

  return (
    <ImageViewerContext.Provider value={contextValue}>
      {children}

      {isOpen && activeItem ? (
        <div
          className='fixed inset-0 z-[120] bg-slate-950/90 backdrop-blur-[1px] animate-[reaction-pop_180ms_ease-out]'
          onClick={closeImageViewer}
        >
          <header className='absolute left-0 right-0 top-0 z-10 flex items-center justify-between px-4 py-3 text-white'>
            <div className='min-w-0'>
              <p className='truncate text-sm font-semibold'>{activeItem.senderName}</p>
              <p className='truncate text-xs text-slate-300'>{activeItem.timestamp}</p>
            </div>
            <button
              type='button'
              onClick={closeImageViewer}
              className='inline-flex h-10 w-10 items-center justify-center rounded-full border border-white/20 bg-black/30 transition hover:bg-black/45'
              aria-label='Đóng trình xem ảnh'
            >
              <X size={22} />
            </button>
          </header>

          {canNavigate ? (
            <>
              <button
                type='button'
                onClick={(event) => {
                  event.stopPropagation()
                  handlePrev()
                }}
                className='absolute left-3 top-1/2 z-10 inline-flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white transition hover:bg-black/55'
                aria-label='Ảnh trước'
              >
                <ChevronLeft size={22} />
              </button>

              <button
                type='button'
                onClick={(event) => {
                  event.stopPropagation()
                  handleNext()
                }}
                className='absolute right-3 top-1/2 z-10 inline-flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white transition hover:bg-black/55'
                aria-label='Ảnh tiếp theo'
              >
                <ChevronRight size={22} />
              </button>
            </>
          ) : null}

          <div className='absolute inset-0 flex items-center justify-center p-4' onClick={closeImageViewer}>
            <img
              src={activeItem.url}
              alt='Ảnh hội thoại'
              className='max-h-[86vh] max-w-[92vw] select-none object-contain transition duration-150'
              style={{ transform: `scale(${scale})` }}
              onClick={(event) => event.stopPropagation()}
              onWheel={handleWheelZoom}
              onTouchStart={handleTouchStart}
              onTouchMove={handleTouchMove}
              onTouchEnd={handleTouchEnd}
              onTouchCancel={() => {
                pinchDistanceRef.current = null
                swipeStartXRef.current = null
              }}
              draggable={false}
            />
          </div>

          <div className='absolute bottom-4 right-4 z-10 flex items-center gap-2'>
            <a
              href={activeItem.url}
              download
              onClick={(event) => event.stopPropagation()}
              className='inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white transition hover:bg-black/55'
              aria-label='Tải ảnh xuống'
              title='Tải ảnh xuống'
            >
              <Download size={18} />
            </a>
            <button
              type='button'
              onClick={(event) => {
                event.stopPropagation()
                setScale((prev) => clamp(prev - 0.2, 1, 4))
              }}
              className='inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white transition hover:bg-black/55'
              aria-label='Thu nhỏ ảnh'
            >
              <ZoomOut size={18} />
            </button>
            <button
              type='button'
              onClick={(event) => {
                event.stopPropagation()
                setScale((prev) => clamp(prev + 0.2, 1, 4))
              }}
              className='inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white transition hover:bg-black/55'
              aria-label='Phóng to ảnh'
            >
              <ZoomIn size={18} />
            </button>
          </div>
        </div>
      ) : null}
    </ImageViewerContext.Provider>
  )
}


