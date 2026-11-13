import { useEffect, useState } from 'react'
import type { Resource, Asset } from '../../lib/types'
import { errorMessage, type VaultApi } from '../../lib/api'
import { faviconUrl, extractHostname } from '../../lib/favicon'
import { fetchPageTitle } from '../../lib/fetchTitle'
import Modal from '../../components/Modal'
import { toast } from '../../components/Toast'

interface Props {
  open: boolean
  onClose: () => void
  asset: Asset
  api: VaultApi
  onUpdate: (updated: Asset) => void
}

export default function AddResourceModal({ open, onClose, asset, api, onUpdate }: Props) {
  const [url, setUrl] = useState('')
  const [title, setTitle] = useState('')
  const [fetchingTitle, setFetchingTitle] = useState(false)
  const [saving, setSaving] = useState(false)

  const hostname = extractHostname(url)
  const favicon = faviconUrl(url)
  const isValidUrl = hostname !== ''

  // Auto-fetch page title whenever the URL changes
  useEffect(() => {
    setTitle('')
    setFetchingTitle(false)

    if (!isValidUrl) return

    const controller = new AbortController()
    setFetchingTitle(true)

    const timer = setTimeout(async () => {
      const fetched = await fetchPageTitle(url, controller.signal)
      if (!controller.signal.aborted) {
        if (fetched) setTitle(fetched)
        setFetchingTitle(false)
      }
    }, 600)

    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [url])

  const reset = () => {
    setUrl('')
    setTitle('')
    setFetchingTitle(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!isValidUrl) return

    const newResource: Resource = {
      title: title.trim() || url.trim(),
      url: url.trim(),
      favicon,
    }

    const updated = [...(asset.resources ?? []), newResource]

    setSaving(true)
    let saved: Asset
    try {
      saved = await api.updateAsset(asset.id, { resources: updated })
    } catch (e) {
      console.error(`Could not add a resource to asset ${asset.id}`, e)
      toast(errorMessage(e))
      return
    } finally {
      setSaving(false)
    }

    onUpdate(saved)
    toast('Resource added', 'success')
    reset()
    onClose()
  }

  return (
    <Modal open={open} onClose={onClose} title="Add Resource">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* URL */}
        <div className="space-y-1.5">
          <label className="block label-sm">
            URL
          </label>
          <input
            type="url"
            value={url}
            onChange={e => setUrl(e.target.value)}
            placeholder="https://..."
            autoFocus
            className="input-field"
          />
          {url && !isValidUrl && (
            <p style={{ fontSize: '0.75rem', color: 'var(--error)' }}>Enter a valid URL</p>
          )}
        </div>

        {/* Title */}
        <div className="space-y-1.5">
          <label className="block label-sm">
            Title
          </label>
          <div className="relative">
            <input
              type="text"
              value={title}
              onChange={e => setTitle(e.target.value)}
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
        </div>

        {/* Preview */}
        {isValidUrl && (
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
                {title || url}
              </p>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{hostname}</p>
            </div>
          </div>
        )}

        <button
          type="submit"
          disabled={!isValidUrl || saving}
          className="btn-primary w-full"
        >
          {saving ? 'Saving...' : 'Add Resource'}
        </button>
      </form>
    </Modal>
  )
}
