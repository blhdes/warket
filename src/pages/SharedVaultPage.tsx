import { useEffect, useMemo, useState } from 'react'
import { useParams, useNavigate } from 'react-router'
import { getSupabase, vaultClient } from '../lib/supabase'
import { resolveShareKey } from '../lib/queries'
import ToastContainer from '../components/Toast'
import ListsView from '../features/lists/ListsView'
import ExportModal from '../components/ExportModal'
import Logo from '../components/Logo'
import ThemeToggle from '../components/ThemeToggle'

export default function SharedVaultPage() {
  const { shareHash } = useParams<{ shareHash: string }>()
  const navigate = useNavigate()
  const [vaultHash, setVaultHash] = useState<string | null>(null)
  const [resolving, setResolving] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [exportModalOpen, setExportModalOpen] = useState(false)

  useEffect(() => {
    if (!shareHash) return

    const resolve = async () => {
      try {
        const { data, error: fetchError } = await resolveShareKey(getSupabase(), shareHash)

        if (fetchError || !data) {
          setError('Invalid or expired share key.')
          setResolving(false)
          return
        }

        setVaultHash(data.vault_hash)
        setResolving(false)
      } catch {
        setError('Failed to resolve share key.')
        setResolving(false)
      }
    }

    resolve()
  }, [shareHash])

  const db = useMemo(() => {
    if (!vaultHash) return null
    try {
      return vaultClient(vaultHash)
    } catch {
      setError('Failed to connect to vault.')
      return null
    }
  }, [vaultHash])

  if (resolving) {
    return (
      <div className="h-dvh flex items-center justify-center" style={{ backgroundColor: 'var(--surface-0)' }}>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
          Resolving shared vault...
        </p>
      </div>
    )
  }

  if (error || !vaultHash || !db) {
    return (
      <div className="h-dvh flex items-center justify-center" style={{ backgroundColor: 'var(--surface-0)' }}>
        <div className="text-center space-y-4">
          <p style={{ color: 'var(--error)', fontSize: '0.875rem' }}>
            {error || 'Unable to load shared vault.'}
          </p>
          <button onClick={() => navigate('/')} className="btn-ghost">
            Back to Home
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="h-dvh flex flex-col overflow-hidden" style={{ backgroundColor: 'var(--surface-0)' }}>
      <div className="decorative-bg" />

      {/* Header */}
      <header
        className="shrink-0 z-40 gradient-border-bottom"
        style={{
          backgroundColor: 'var(--header-bg)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          paddingTop: 'env(safe-area-inset-top)',
        }}
      >
        <div className="mx-auto flex h-14 items-center justify-between px-4" style={{ maxWidth: '1400px' }}>
          <div
            className="flex items-center gap-2 text-lg"
            style={{
              fontFamily: 'var(--font-display)',
              color: 'var(--text-primary)',
            }}
          >
            <Logo size={18} style={{ color: 'var(--accent)', opacity: 0.45 }} />
            <span><span style={{ color: 'var(--accent)' }}>w</span>arket</span>
          </div>

          <div className="flex items-center gap-3">
            {/* Read-only badge */}
            <span
              className="session-badge"
              style={{ cursor: 'default', fontSize: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}
            >
              Read-only
            </span>

            {/* Export */}
            <button
              onClick={() => setExportModalOpen(true)}
              className="theme-toggle"
              title="Export vault"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                <path d="M10.75 2.75a.75.75 0 0 0-1.5 0v8.614L6.295 8.235a.75.75 0 1 0-1.09 1.03l4.25 4.5a.75.75 0 0 0 1.09 0l4.25-4.5a.75.75 0 0 0-1.09-1.03l-2.955 3.129V2.75Z" />
                <path d="M3.5 12.75a.75.75 0 0 0-1.5 0v2.5A2.75 2.75 0 0 0 4.75 18h10.5A2.75 2.75 0 0 0 18 15.25v-2.5a.75.75 0 0 0-1.5 0v2.5c0 .69-.56 1.25-1.25 1.25H4.75c-.69 0-1.25-.56-1.25-1.25v-2.5Z" />
              </svg>
            </button>

            <ThemeToggle />

            {/* Back to home */}
            <button
              onClick={() => navigate('/')}
              className="btn-ghost flex items-center gap-1.5"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-3.5 w-3.5">
                <path fillRule="evenodd" d="M17 10a.75.75 0 0 1-.75.75H5.612l4.158 3.96a.75.75 0 1 1-1.04 1.08l-5.5-5.25a.75.75 0 0 1 0-1.08l5.5-5.25a.75.75 0 1 1 1.04 1.08L5.612 9.25H16.25A.75.75 0 0 1 17 10Z" clipRule="evenodd" />
              </svg>
              <span className="hidden sm:inline">Home</span>
            </button>
          </div>
        </div>
      </header>

      {/* Content */}
      <main
        className="flex-1 overflow-y-auto overflow-x-hidden w-full mx-auto px-4 py-6"
        style={{ maxWidth: '1400px', paddingBottom: 'calc(1.5rem + env(safe-area-inset-bottom))', overscrollBehavior: 'none' }}
      >
        <ListsView db={db} vaultHash={vaultHash} readOnly />
      </main>

      <ExportModal
        open={exportModalOpen}
        onClose={() => setExportModalOpen(false)}
        db={db}
        vaultHash={vaultHash}
      />

      <ToastContainer />
    </div>
  )
}
