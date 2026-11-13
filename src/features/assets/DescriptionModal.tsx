import { useCallback, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { Asset } from '../../lib/types'
import { errorMessage, type VaultApi } from '../../lib/api'
import { renderMarkdown } from '../../lib/markdown'
import { toast } from '../../components/Toast'
import MarkdownEditor from '../../components/MarkdownEditor'

interface Props {
  open: boolean
  onClose: () => void
  asset: Asset
  api: VaultApi
  onUpdate: (updated: Asset) => void
  readOnly?: boolean
}

const CLOSE_MS = 250
const EASE = 'cubic-bezier(0.4, 0, 0.2, 1)'

export default function DescriptionModal({ open, onClose, asset, api, onUpdate, readOnly }: Props) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(asset.description ?? '')
  const [saving, setSaving] = useState(false)
  const overlayRef = useRef<HTMLDivElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const [closeHovered, setCloseHovered] = useState(false)

  /* ── Close animation state ───────────────────────────── */
  const [isClosing, setIsClosing] = useState(false)
  const closingTimer = useRef<ReturnType<typeof setTimeout>>(undefined)

  /* ── Swipe-to-dismiss refs ───────────────────────────── */
  const dragStartY = useRef<number | null>(null)
  const currentDragY = useRef(0)

  /* ── Cleanup timer on unmount ────────────────────────── */
  useEffect(() => () => {
    if (closingTimer.current) clearTimeout(closingTimer.current)
  }, [])

  // Sync draft when asset changes or modal opens
  useEffect(() => {
    if (open) setDraft(asset.description ?? '')
  }, [open, asset.description])

  // Focus textarea when entering edit mode
  useEffect(() => {
    if (editing && textareaRef.current) {
      textareaRef.current.focus()
      textareaRef.current.setSelectionRange(
        textareaRef.current.value.length,
        textareaRef.current.value.length,
      )
    }
  }, [editing])

  /* ── Reset state when open prop changes ──────────────── */
  useEffect(() => {
    if (open) {
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

  // ESC to close
  useEffect(() => {
    if (!open || isClosing) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (editing) { setEditing(false) }
        else animateClose()
      }
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [open, editing, isClosing, animateClose])

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
      // Progressively fade backdrop
      if (overlayRef.current) {
        const progress = Math.min(delta / 300, 1)
        overlayRef.current.style.opacity = String(1 - progress * 0.6)
      }
    }
  }, [])

  const onTouchEnd = useCallback(() => {
    if (currentDragY.current > 80) {
      // Dismiss via swipe
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
      // Snap back
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

  if (!open && !isClosing) return null

  const handleSave = async () => {
    setSaving(true)
    let saved: Asset
    try {
      saved = await api.updateAsset(asset.id, { description: draft })
    } catch (e) {
      console.error(`Could not save the description of asset ${asset.id}`, e)
      toast(errorMessage(e))
      return
    } finally {
      setSaving(false)
    }

    onUpdate(saved)
    toast('Description saved', 'success')
    setEditing(false)
  }

  const handleDiscard = () => {
    setDraft(asset.description ?? '')
    setEditing(false)
  }

  const renderedHtml = editing ? '' : renderMarkdown(asset.description ?? '')

  return createPortal(
    <div
      ref={overlayRef}
      onClick={e => { if (e.target === overlayRef.current && !isClosing) animateClose() }}
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 animate-modal-backdrop"
      style={{ background: 'var(--overlay-bg)', backdropFilter: 'blur(4px)' }}
    >
      <div
        ref={panelRef}
        className="animate-modal-sheet modal-panel flex flex-col w-full"
        style={{
          background: 'var(--surface-1)',
          border: '1px solid var(--border-hover)',
          borderRadius: '16px 16px 0 0',
          maxHeight: '90vh',
          maxWidth: '56rem',
        }}
      >
        {/* ── Mobile sheet handle (swipe target) ───────────────── */}
        <div
          className="sm:hidden"
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
          style={{ touchAction: 'none' }}
        >
          <div className="sheet-handle" />
        </div>

        {/* ── Header ─────────────────────────────────────────── */}
        <div
          className="flex shrink-0 items-center justify-between px-6 py-4"
          style={{ borderBottom: '1px solid var(--border-default)' }}
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
        >
          <div className="min-w-0">
            <h2
              className="truncate"
              style={{
                fontFamily: 'var(--font-display)',
                fontSize: '1.125rem',
                color: 'var(--text-primary)',
              }}
            >
              {asset.name}
            </h2>
            <span
              style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '0.6875rem',
                color: 'var(--text-muted)',
                textTransform: 'uppercase',
              }}
            >
              {asset.ticker}
            </span>
          </div>

          <div className="flex items-center gap-2">
            {!editing ? (
              !readOnly && (
                <button
                  onClick={() => setEditing(true)}
                  className="btn-ghost"
                  style={{ fontSize: '0.8125rem' }}
                >
                  Edit
                </button>
              )
            ) : (
              <>
                <button
                  onClick={handleDiscard}
                  className="btn-ghost"
                  style={{ fontSize: '0.8125rem' }}
                >
                  Discard
                </button>
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="btn-primary"
                  style={{ fontSize: '0.8125rem' }}
                >
                  {saving ? 'Saving...' : 'Save'}
                </button>
              </>
            )}
            <button
              onClick={isClosing ? undefined : animateClose}
              onMouseEnter={() => setCloseHovered(true)}
              onMouseLeave={() => setCloseHovered(false)}
              className="ml-2 rounded p-1"
              style={{
                color: closeHovered ? 'var(--text-primary)' : 'var(--text-tertiary)',
              }}
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-5 w-5">
                <path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z" />
              </svg>
            </button>
          </div>
        </div>

        {/* ── Body ───────────────────────────────────────────── */}
        <div className="min-h-0 flex-1 overflow-hidden">
          {!editing ? (
            /* View mode */
            <div className="h-full overflow-y-auto px-6 py-5">
              {asset.description ? (
                <div
                  className="prose-custom"
                  dangerouslySetInnerHTML={{ __html: renderedHtml }}
                />
              ) : (
                <div className="flex h-full items-center justify-center">
                  <p style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>
                    No description yet.{!readOnly && (
                      <>
                        {' '}
                        <button
                          onClick={() => setEditing(true)}
                          style={{ color: 'var(--accent)' }}
                        >
                          Add one
                        </button>
                      </>
                    )}
                  </p>
                </div>
              )}
            </div>
          ) : (
            /* Edit mode with markdown toolbar */
            <MarkdownEditor
              value={draft}
              onChange={setDraft}
              placeholder="Write your description in markdown..."
              textareaRef={textareaRef}
            />
          )}
        </div>
      </div>
    </div>,
    document.body,
  )
}
