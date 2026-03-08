import { useEffect, useRef, useState } from 'react'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { Asset, Resource } from '../../lib/types'
import { faviconUrl, extractHostname } from '../../lib/favicon'
import { fetchPageTitle } from '../../lib/fetchTitle'
import Modal from '../../components/Modal'
import { toast } from '../../components/Toast'
import { useFormNavigation } from '../../hooks/useFormNavigation'

interface Props {
  open: boolean
  onClose: () => void
  db: SupabaseClient
  listId: string
  onCreated: (asset: Asset) => void
}

export default function AddAssetModal({ open, onClose, db, listId, onCreated }: Props) {
  const [name, setName] = useState('')
  const [ticker, setTicker] = useState('')
  const [summary, setSummary] = useState('')
  const [tagsInput, setTagsInput] = useState('')
  const [saving, setSaving] = useState(false)

  // ── Resource gathering state ─────────────────────────────
  const [resources, setResources] = useState<Resource[]>([])
  const [resUrl, setResUrl] = useState('')
  const [resTitle, setResTitle] = useState('')
  const [fetchingTitle, setFetchingTitle] = useState(false)

  // ── Hover state for interactive styling ──────────────────
  const [hoveredResIdx, setHoveredResIdx] = useState<number | null>(null)
  const [hoveredRemoveIdx, setHoveredRemoveIdx] = useState<number | null>(null)
  const formRef = useRef<HTMLFormElement>(null)
  useFormNavigation(formRef)

  const hostname = extractHostname(resUrl)
  const isValidUrl = hostname !== ''
  const favicon = faviconUrl(resUrl)

  // Auto-fetch page title whenever the URL changes
  useEffect(() => {
    setResTitle('')
    setFetchingTitle(false)

    if (!isValidUrl) return

    const controller = new AbortController()
    setFetchingTitle(true)

    const timer = setTimeout(async () => {
      const title = await fetchPageTitle(resUrl, controller.signal)
      if (!controller.signal.aborted) {
        if (title) setResTitle(title)
        setFetchingTitle(false)
      }
    }, 600)

    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [resUrl])

  const resetResourceInputs = () => {
    setResUrl('')
    setResTitle('')
    setFetchingTitle(false)
  }

  const handleAddResource = () => {
    if (!isValidUrl) return

    const newResource: Resource = {
      title: resTitle.trim() || resUrl.trim(),
      url: resUrl.trim(),
      favicon,
    }
    setResources(prev => [...prev, newResource])
    resetResourceInputs()
  }

  const handleRemoveResource = (index: number) => {
    setResources(prev => prev.filter((_, i) => i !== index))
  }

  const reset = () => {
    setName(''); setTicker(''); setSummary('')
    setTagsInput(''); setResources([])
    resetResourceInputs()
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim() || !ticker.trim()) return

    const tags = tagsInput
      .split(',')
      .map(t => t.trim().toLowerCase())
      .filter(Boolean)

    setSaving(true)
    const { data, error } = await db
      .from('assets')
      .insert({
        list_id: listId,
        name: name.trim(),
        ticker: ticker.trim().toUpperCase(),
        summary: summary.trim(),
        tags,
        resources,
      })
      .select()
      .single()

    setSaving(false)

    if (error) {
      toast(error.message)
      return
    }

    toast('Asset added', 'success')
    onCreated(data as Asset)
    reset()
    onClose()
  }

  return (
    <Modal open={open} onClose={onClose} title="Add Asset">
      <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
        {/* Name */}
        <div className="space-y-1.5">
          <label className="block label-sm">
            Name
          </label>
          <input
            type="text"
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="e.g. NVIDIA Corporation"
            autoFocus
            className="input-field"
          />
        </div>

        {/* Ticker */}
        <div className="space-y-1.5">
          <label className="block label-sm">
            Ticker
          </label>
          <input
            type="text"
            value={ticker}
            onChange={e => setTicker(e.target.value)}
            placeholder="e.g. NVDA"
            className="input-field"
            style={{ textTransform: 'uppercase' }}
          />
        </div>

        {/* Summary */}
        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <label className="block label-sm">
              Summary
            </label>
            <span style={{ fontSize: '0.75rem', color: summary.length > 250 ? 'var(--error)' : 'var(--text-muted)' }}>
              {summary.length}/250
            </span>
          </div>
          <textarea
            value={summary}
            onChange={e => setSummary(e.target.value)}
            maxLength={250}
            rows={3}
            placeholder="Brief description (max 250 chars)"
            className="input-field"
            style={{ resize: 'none' }}
          />
        </div>

        {/* Tags */}
        <div className="space-y-1.5">
          <label className="block label-sm">
            Tags
          </label>
          <input
            type="text"
            value={tagsInput}
            onChange={e => setTagsInput(e.target.value)}
            placeholder="ai, gpu, growth (comma-separated)"
            className="input-field"
          />
        </div>

        {/* ── Resources section ─────────────────────────────── */}
        <div className="space-y-2">
          <label className="block label-sm">
            Resources{' '}
            <span style={{ color: 'var(--text-muted)', fontWeight: 400, textTransform: 'none' }}>
              ({resources.length} added)
            </span>
          </label>

          {/* List of added resources */}
          {resources.length > 0 && (
            <div
              className="space-y-1 p-2"
              style={{
                background: 'var(--surface-2)',
                border: '1px solid var(--border-default)',
                borderRadius: 'var(--radius-md)',
              }}
            >
              {resources.map((res, i) => (
                <div
                  key={`${res.url}-${i}`}
                  className="flex items-center gap-2 px-2 py-1.5"
                  style={{
                    borderRadius: 'var(--radius-md)',
                    background: hoveredResIdx === i ? 'var(--surface-2)' : 'transparent',
                  }}
                  onMouseEnter={() => setHoveredResIdx(i)}
                  onMouseLeave={() => setHoveredResIdx(null)}
                >
                  <img
                    src={res.favicon}
                    alt=""
                    className="h-4 w-4 shrink-0"
                    style={{ borderRadius: 'var(--radius-sm)' }}
                    onError={e => { (e.target as HTMLImageElement).style.display = 'none' }}
                  />
                  <span
                    className="min-w-0 flex-1 truncate"
                    style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}
                  >
                    {res.title}
                  </span>
                  <button
                    type="button"
                    onClick={() => handleRemoveResource(i)}
                    onMouseEnter={() => setHoveredRemoveIdx(i)}
                    onMouseLeave={() => setHoveredRemoveIdx(null)}
                    className="shrink-0 rounded p-0.5"
                    style={{
                      color: hoveredRemoveIdx === i ? 'var(--error)' : 'var(--text-muted)',
                    }}
                    title="Remove"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" className="h-3.5 w-3.5">
                      <path d="M5.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 1 0 1.06 1.06L8 9.06l2.72 2.72a.75.75 0 1 0 1.06-1.06L9.06 8l2.72-2.72a.75.75 0 0 0-1.06-1.06L8 6.94 5.28 4.22Z" />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* URL input */}
          <input
            type="url"
            value={resUrl}
            onChange={e => setResUrl(e.target.value)}
            placeholder="https://..."
            className="input-field"
          />

          {/* Title input (shown when URL is valid) */}
          {isValidUrl && (
            <>
              <div className="relative">
                <input
                  type="text"
                  value={resTitle}
                  onChange={e => setResTitle(e.target.value)}
                  placeholder={fetchingTitle ? 'Fetching page title...' : 'Page title or label'}
                  className="input-field"
                />
                {fetchingTitle && (
                  <div className="absolute right-3 top-1/2 -translate-y-1/2">
                    <div
                      className="h-3.5 w-3.5 animate-spin rounded-full border-2"
                      style={{ borderColor: 'var(--border-default)', borderTopColor: 'var(--accent)' }}
                    />
                  </div>
                )}
              </div>

              {/* Preview card */}
              <div
                className="flex items-center gap-2.5 px-3 py-2.5"
                style={{
                  background: 'var(--surface-2)',
                  border: '1px solid var(--border-default)',
                  borderRadius: 'var(--radius-md)',
                }}
              >
                <img
                  src={favicon}
                  alt=""
                  className="h-4 w-4 shrink-0 rounded"
                  onError={e => { (e.target as HTMLImageElement).style.display = 'none' }}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate" style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>
                    {resTitle || resUrl}
                  </p>
                  <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{hostname}</p>
                </div>
              </div>

              {/* Add resource button */}
              <button
                type="button"
                onClick={handleAddResource}
                className="btn-ghost"
                style={{ fontSize: '0.75rem' }}
              >
                + Add Resource
              </button>
            </>
          )}
        </div>

        <button
          type="submit"
          disabled={!name.trim() || !ticker.trim() || saving}
          className="btn-primary w-full"
        >
          {saving ? 'Saving...' : 'Add Asset'}
        </button>
      </form>
    </Modal>
  )
}
