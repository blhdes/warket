import { useEffect, useMemo, useRef, useState } from 'react'
import { useParams, useNavigate } from 'react-router'
import { getSupabase, vaultClient } from '../lib/supabase'
import { deriveShareHash } from '../features/auth/seedPhrase'
import { importVault, validateImportData } from '../lib/vaultExport'
import { toast } from '../components/Toast'
import ToastContainer from '../components/Toast'
import ListsView from '../features/lists/ListsView'
import ExportModal from '../components/ExportModal'
import Logo from '../components/Logo'
import ThemeToggle from '../components/ThemeToggle'

export default function VaultPage() {
  const { hash } = useParams<{ hash: string }>()
  const navigate = useNavigate()
  const [supabaseError, setSupabaseError] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const [listKey, setListKey] = useState(0)
  const [exportModalOpen, setExportModalOpen] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const storedHash = sessionStorage.getItem('vault_hash') || localStorage.getItem('vault_hash_persistent')

  const handleCopyHash = () => {
    navigator.clipboard.writeText(hash!)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  useEffect(() => {
    if (!storedHash) {
      navigate('/', { replace: true })
    }
  }, [storedHash, navigate])

  const db = useMemo(() => {
    if (!hash) return null
    try {
      return vaultClient(hash)
    } catch (e) {
      setSupabaseError(e instanceof Error ? e.message : 'Failed to connect')
      return null
    }
  }, [hash])

  if (!storedHash || !hash) return null

  const truncatedHash = `${hash.slice(0, 8)}...${hash.slice(-4)}`

  const handleLock = () => {
    sessionStorage.removeItem('vault_hash')
    localStorage.removeItem('vault_hash_persistent')
    localStorage.removeItem('vault_remember')
    navigate('/', { replace: true })
  }

  const handleShare = async () => {
    try {
      // Clipboard write must be initiated within the user gesture. Awaiting async
      // work first loses that context, so we pass ClipboardItem a Promise that
      // resolves the content after the Supabase upsert completes.
      const clipContent: Promise<Blob> = (async () => {
        const shareHash = await deriveShareHash(hash)
        const supabase = getSupabase()
        const { error } = await supabase
          .from('vault_shares')
          .upsert({ vault_hash: hash, share_hash: shareHash }, { onConflict: 'vault_hash' })
        if (error) throw new Error(error.message)
        return new Blob([shareHash], { type: 'text/plain' })
      })()

      await navigator.clipboard.write([new ClipboardItem({ 'text/plain': clipContent })])
      toast('Share key copied to clipboard', 'success')
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed to generate share key')
    }
  }

  const handleImportFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !db) return
    e.target.value = ''

    try {
      const text = await file.text()
      const data = JSON.parse(text)

      const validation = validateImportData(data)
      if (!validation.valid) {
        toast(validation.error ?? 'Invalid file')
        return
      }

      const result = await importVault(db, hash, data)
      toast(`Imported ${result.listsImported} lists, ${result.assetsImported} assets`, 'success')
      setListKey(k => k + 1)
    } catch (e) {
      if (e instanceof SyntaxError) {
        toast('Invalid JSON file')
      } else {
        toast(e instanceof Error ? e.message : 'Import failed')
      }
    }
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
          <button
            onClick={() => setListKey(k => k + 1)}
            className="flex items-center gap-2 text-lg"
            style={{
              fontFamily: 'var(--font-display)',
              color: 'var(--text-primary)',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: 0,
            }}
          >
            <Logo size={18} style={{ color: 'var(--accent)', opacity: 0.45 }} />
            <span><span style={{ color: 'var(--accent)' }}>w</span>arket</span>
          </button>

          <div className="flex items-center gap-3">
            {/* Desktop session badge */}
            <button
              className="session-badge hidden sm:inline-flex"
              onClick={handleCopyHash}
            >
              {copied ? 'Copied!' : truncatedHash}
            </button>

            {/* Mobile session badge */}
            <button
              className="session-badge sm:hidden flex items-center justify-center"
              onClick={handleCopyHash}
              style={{ width: '32px', height: '32px', padding: 0 }}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                className="w-3.5 h-3.5"
              >
                <path
                  fillRule="evenodd"
                  d="M15.988 3.012A2.25 2.25 0 0 1 18 5.25v6.5A2.25 2.25 0 0 1 15.75 14H13.5v-2h2.25a.25.25 0 0 0 .25-.25v-6.5a.25.25 0 0 0-.25-.25h-6.5a.25.25 0 0 0-.25.25V7.5h-2V5.25a2.25 2.25 0 0 1 2.25-2.238h6.738ZM4.25 8A2.25 2.25 0 0 0 2 10.25v4.5A2.25 2.25 0 0 0 4.25 17h6.5A2.25 2.25 0 0 0 13 14.75v-4.5A2.25 2.25 0 0 0 10.75 8h-6.5Z"
                  clipRule="evenodd"
                />
              </svg>
            </button>

            {/* Import */}
            <input
              ref={fileInputRef}
              type="file"
              accept=".json"
              onChange={handleImportFile}
              className="hidden"
            />
            <button
              onClick={() => fileInputRef.current?.click()}
              className="theme-toggle"
              title="Import vault"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                <path d="M9.25 13.25a.75.75 0 0 0 1.5 0V4.636l2.955 3.129a.75.75 0 0 0 1.09-1.03l-4.25-4.5a.75.75 0 0 0-1.09 0l-4.25 4.5a.75.75 0 1 0 1.09 1.03L9.25 4.636v8.614Z" />
                <path d="M3.5 12.75a.75.75 0 0 0-1.5 0v2.5A2.75 2.75 0 0 0 4.75 18h10.5A2.75 2.75 0 0 0 18 15.25v-2.5a.75.75 0 0 0-1.5 0v2.5c0 .69-.56 1.25-1.25 1.25H4.75c-.69 0-1.25-.56-1.25-1.25v-2.5Z" />
              </svg>
            </button>

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

            {/* Share */}
            <button
              onClick={handleShare}
              className="theme-toggle"
              title="Share vault (read-only)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                <path d="M12.232 4.232a2.5 2.5 0 0 1 3.536 3.536l-1.225 1.224a.75.75 0 0 0 1.061 1.06l1.224-1.224a4 4 0 0 0-5.656-5.656l-3 3a4 4 0 0 0 .225 5.865.75.75 0 0 0 .977-1.138 2.5 2.5 0 0 1-.142-3.667l3-3Z" />
                <path d="M11.603 7.963a.75.75 0 0 0-.977 1.138 2.5 2.5 0 0 1 .142 3.667l-3 3a2.5 2.5 0 0 1-3.536-3.536l1.225-1.224a.75.75 0 0 0-1.061-1.06l-1.224 1.224a4 4 0 1 0 5.656 5.656l3-3a4 4 0 0 0-.225-5.865Z" />
              </svg>
            </button>

            <ThemeToggle />

            {/* Lock button */}
            <button
              onClick={handleLock}
              className="btn-ghost flex items-center gap-1.5"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                className="h-3.5 w-3.5"
              >
                <path
                  fillRule="evenodd"
                  d="M10 1a4.5 4.5 0 0 0-4.5 4.5V9H5a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5.5A4.5 4.5 0 0 0 10 1Zm3 8V5.5a3 3 0 1 0-6 0V9h6Z"
                  clipRule="evenodd"
                />
              </svg>
              <span className="hidden sm:inline">Lock</span>
            </button>
          </div>
        </div>
      </header>

      {/* Content */}
      <main
        className="flex-1 overflow-y-auto overflow-x-hidden w-full mx-auto px-4 py-6"
        style={{ maxWidth: '1400px', paddingBottom: 'calc(1.5rem + env(safe-area-inset-bottom))', overscrollBehavior: 'none' }}
      >
        {supabaseError ? (
          <div
            className="p-6 text-center"
            style={{
              borderRadius: 'var(--radius-lg)',
              border: '1px solid var(--error-border)',
              backgroundColor: 'var(--error-bg)',
              color: 'var(--error)',
              fontSize: '0.875rem',
            }}
          >
            <p>{supabaseError}</p>
          </div>
        ) : db ? (
          <ListsView key={listKey} db={db} vaultHash={hash} />
        ) : null}
      </main>

      {db && (
        <ExportModal
          open={exportModalOpen}
          onClose={() => setExportModalOpen(false)}
          db={db}
          vaultHash={hash}
        />
      )}

      <ToastContainer />
    </div>
  )
}
