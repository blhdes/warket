import { useEffect, useState } from 'react'
import type { VaultList } from '../lib/types'
import { errorMessage, type VaultApi } from '../lib/api'
import { downloadExport } from '../lib/vaultExport'
import Modal from './Modal'
import { toast } from './Toast'

interface Props {
  open: boolean
  onClose: () => void
  api: VaultApi
}

export default function ExportModal({ open, onClose, api }: Props) {
  const [lists, setLists] = useState<VaultList[]>([])
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [exporting, setExporting] = useState(false)

  useEffect(() => {
    if (!open) return
    setLoading(true)

    const fetchLists = async () => {
      try {
        const fetched = await api.lists()
        setLists(fetched)
        setSelected(new Set(fetched.map(l => l.id)))
      } catch (e) {
        console.error('Could not load lists for export', e)
        toast(errorMessage(e))
      }
      setLoading(false)
    }

    fetchLists()
  }, [open, api])

  const handleToggle = (id: string) => {
    setSelected(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const handleToggleAll = () => {
    if (selected.size === lists.length) {
      setSelected(new Set())
    } else {
      setSelected(new Set(lists.map(l => l.id)))
    }
  }

  const handleExport = async () => {
    if (selected.size === 0) return
    setExporting(true)
    try {
      // No ids means "everything", which also keeps the address short for big vaults.
      const listIds = selected.size === lists.length ? undefined : Array.from(selected)
      const result = downloadExport(await api.exportVault(listIds))
      toast(`Exported ${result.listsExported} lists, ${result.assetsExported} assets`, 'success')
      onClose()
    } catch (e) {
      console.error('Export failed', e)
      toast(errorMessage(e, 'Export failed'))
    }
    setExporting(false)
  }

  return (
    <Modal open={open} onClose={onClose} title="Export Vault">
      <div className="space-y-4">
        {loading ? (
          <p style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>Loading lists...</p>
        ) : lists.length === 0 ? (
          <p style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>No lists to export.</p>
        ) : (
          <>
            <label
              className="flex items-center gap-2 cursor-pointer"
              style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)' }}
            >
              <input
                type="checkbox"
                checked={selected.size === lists.length}
                onChange={handleToggleAll}
                style={{ accentColor: 'var(--accent)' }}
              />
              Select all ({lists.length} {lists.length === 1 ? 'list' : 'lists'})
            </label>

            <div
              className="space-y-1 overflow-y-auto"
              style={{
                maxHeight: '16rem',
                border: '1px solid var(--border-default)',
                borderRadius: 'var(--radius-md)',
                padding: '8px',
              }}
            >
              {lists.map(list => (
                <label
                  key={list.id}
                  className="flex items-center gap-2.5 px-2 py-1.5 cursor-pointer"
                  style={{
                    borderRadius: 'var(--radius-md)',
                    fontSize: '0.875rem',
                    color: 'var(--text-primary)',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={selected.has(list.id)}
                    onChange={() => handleToggle(list.id)}
                    style={{ accentColor: 'var(--accent)' }}
                  />
                  {list.name}
                  {list.tags?.length > 0 && (
                    <span style={{ fontSize: '0.6875rem', color: 'var(--text-muted)' }}>
                      ({list.tags.join(', ')})
                    </span>
                  )}
                </label>
              ))}
            </div>
          </>
        )}

        <button
          onClick={handleExport}
          disabled={selected.size === 0 || exporting || loading}
          className="btn-primary w-full"
        >
          {exporting ? 'Exporting...' : `Export ${selected.size} ${selected.size === 1 ? 'List' : 'Lists'}`}
        </button>
      </div>
    </Modal>
  )
}
