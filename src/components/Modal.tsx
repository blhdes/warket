import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { Capacitor } from '@capacitor/core'
import { haptic } from '../lib/haptics'

interface ModalProps {
  open: boolean
  onClose: () => void
  title: string
  children: ReactNode
}

const CLOSE_MS = 250
const EASE = 'cubic-bezier(0.4, 0, 0.2, 1)'

export default function Modal({ open, onClose, title, children }: ModalProps) {
  const overlayRef = useRef<HTMLDivElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)
  const dragStartY = useRef<number | null>(null)
  const currentDragY = useRef(0)
  const [isClosing, setIsClosing] = useState(false)
  const closingTimer = useRef<ReturnType<typeof setTimeout>>(undefined)

  /* ── Cleanup timer on unmount ────────────────────────── */
  useEffect(() => () => {
    if (closingTimer.current) clearTimeout(closingTimer.current)
  }, [])

  /* ── Reset when open changes ─────────────────────────── */
  useEffect(() => {
    if (open) {
      haptic.light()
      setIsClosing(false)
      if (closingTimer.current) clearTimeout(closingTimer.current)
      // Restore CSS open animations (clear inline overrides)
      if (panelRef.current) {
        panelRef.current.style.animation = ''
        panelRef.current.style.transition = ''
        panelRef.current.style.transform = ''
        panelRef.current.style.opacity = ''
      }
      if (overlayRef.current) {
        overlayRef.current.style.animation = ''
        overlayRef.current.style.transition = ''
        overlayRef.current.style.opacity = ''
      }
    } else {
      setIsClosing(false)
    }
  }, [open])

  /* ── Animated close (button / backdrop / escape) ─────── */
  const animateClose = useCallback(() => {
    if (isClosing) return
    const isDesktop = window.matchMedia('(min-width: 640px)').matches

    // Cancel CSS open animation so inline styles take effect
    if (panelRef.current) {
      panelRef.current.style.animation = 'none'
      panelRef.current.style.transition = `transform ${CLOSE_MS}ms ${EASE}, opacity ${CLOSE_MS}ms ${EASE}`
      panelRef.current.style.transform = isDesktop
        ? 'scale(0.96) translateY(8px)'
        : 'translateY(100%)'
      panelRef.current.style.opacity = '0'
    }
    if (overlayRef.current) {
      overlayRef.current.style.animation = 'none'
      overlayRef.current.style.transition = `opacity ${CLOSE_MS}ms ${EASE}`
      overlayRef.current.style.opacity = '0'
    }

    setIsClosing(true)
    closingTimer.current = setTimeout(onClose, CLOSE_MS)
  }, [isClosing, onClose])

  /* ── Escape key ──────────────────────────────────────── */
  useEffect(() => {
    if (!open || isClosing) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') animateClose()
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [open, isClosing, animateClose])

  /* ── Swipe-to-dismiss (mobile) ─────────────────────────── */
  const onTouchStart = useCallback((e: React.TouchEvent) => {
    if (isClosing) return
    dragStartY.current = e.touches[0].clientY
    currentDragY.current = 0
    // Cancel CSS open animation — its `forwards` fill overrides inline styles
    if (panelRef.current) {
      panelRef.current.style.animation = 'none'
      panelRef.current.style.transition = 'none'
      panelRef.current.style.transform = 'translateY(0)'
    }
    if (overlayRef.current) {
      overlayRef.current.style.animation = 'none'
    }
  }, [isClosing])

  const onTouchMove = useCallback((e: React.TouchEvent) => {
    if (dragStartY.current === null) return
    const delta = e.touches[0].clientY - dragStartY.current
    if (delta > 0) {
      currentDragY.current = delta
      if (panelRef.current) {
        panelRef.current.style.transform = `translateY(${delta}px)`
      }
      // Progressively fade backdrop as user drags down
      if (overlayRef.current) {
        const progress = Math.min(delta / 300, 1)
        overlayRef.current.style.opacity = String(1 - progress * 0.6)
      }
    }
  }, [])

  const onTouchEnd = useCallback(() => {
    if (currentDragY.current > 80) {
      // Dismiss: animate panel down + fade backdrop out
      if (panelRef.current) {
        panelRef.current.style.transition = `transform ${CLOSE_MS}ms ${EASE}`
        panelRef.current.style.transform = 'translateY(100%)'
      }
      if (overlayRef.current) {
        overlayRef.current.style.transition = `opacity ${CLOSE_MS}ms ${EASE}`
        overlayRef.current.style.opacity = '0'
      }
      setIsClosing(true)
      closingTimer.current = setTimeout(onClose, CLOSE_MS)
    } else {
      // Snap back to open position
      if (panelRef.current) {
        panelRef.current.style.transition = `transform 0.2s ${EASE}`
        panelRef.current.style.transform = 'translateY(0)'
      }
      if (overlayRef.current) {
        overlayRef.current.style.transition = `opacity 0.2s ${EASE}`
        overlayRef.current.style.opacity = '1'
      }
    }
    dragStartY.current = null
    currentDragY.current = 0
  }, [onClose])

  /* ── iOS keyboard: track visual viewport height ─────── */
  const isNative = Capacitor.isNativePlatform()
  const [vpHeight, setVpHeight] = useState<number | null>(null)

  useEffect(() => {
    if (!open || !isNative || !window.visualViewport) return

    const onResize = () => {
      setVpHeight(window.visualViewport!.height)
    }
    onResize()
    window.visualViewport.addEventListener('resize', onResize)
    return () => window.visualViewport!.removeEventListener('resize', onResize)
  }, [open, isNative])

  /* ── iOS keyboard: scroll focused input into view ────── */
  const contentRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open || !isNative) return
    const container = contentRef.current
    if (!container) return

    const onFocusIn = (e: FocusEvent) => {
      const target = e.target as HTMLElement
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT') {
        requestAnimationFrame(() => {
          target.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
        })
      }
    }

    container.addEventListener('focusin', onFocusIn)
    return () => container.removeEventListener('focusin', onFocusIn)
  }, [open, isNative])

  /* ── Don't render unless open or animating out ────────── */
  if (!open && !isClosing) return null

  return createPortal(
    <div
      ref={overlayRef}
      onClick={e => { if (e.target === overlayRef.current && !isClosing) animateClose() }}
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 animate-modal-backdrop"
      style={{
        backgroundColor: 'var(--overlay-bg)',
        backdropFilter: 'blur(4px)',
        WebkitBackdropFilter: 'blur(4px)',
      }}
    >
      <div
        ref={panelRef}
        className="animate-modal-sheet modal-panel w-full sm:max-w-md"
        style={{
          backgroundColor: 'var(--surface-1)',
          border: '1px solid var(--border-hover)',
          borderRadius: '16px 16px 0 0',
          boxShadow: 'var(--modal-shadow)',
          maxHeight: vpHeight ? `${vpHeight * 0.9}px` : '90vh',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Mobile drag zone (handle + acts as swipe target) */}
        <div
          className="sm:hidden"
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
          style={{ touchAction: 'none' }}
        >
          <div className="sheet-handle" />
        </div>

        <div
          className="flex items-center justify-between px-5 py-4"
          style={{ borderBottom: '1px solid var(--border-default)' }}
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
        >
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '1.125rem', color: 'var(--text-primary)' }}>
            {title}
          </h2>
          <button
            onClick={isClosing ? undefined : animateClose}
            className="transition-colors text-xl leading-none"
            style={{ color: 'var(--text-tertiary)' }}
            onMouseEnter={e => (e.currentTarget.style.color = 'var(--text-primary)')}
            onMouseLeave={e => (e.currentTarget.style.color = 'var(--text-tertiary)')}
          >
            &times;
          </button>
        </div>
        <div ref={contentRef} className="p-5 overflow-y-auto">{children}</div>
      </div>
    </div>,
    document.body,
  )
}
