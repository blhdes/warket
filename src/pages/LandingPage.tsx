import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router'
import { generateSeedPhrase, hashSeedPhrase } from '../features/auth/seedPhrase'
import { getSupabase } from '../lib/supabase'
import { resolveShareKey } from '../lib/queries'
import Logo from '../components/Logo'
import ThemeToggle from '../components/ThemeToggle'
import MarketPulse from '../components/MarketPulse'
import { useTheme } from '../contexts/ThemeContext'
import { haptic } from '../lib/haptics'

const HEX_64 = /^[0-9a-f]{64}$/i
const LS_VAULT_KEY = 'vault_hash_persistent'
const LS_REMEMBER_KEY = 'vault_remember'

export default function LandingPage() {
  const navigate = useNavigate()
  const { isDark } = useTheme()
  const [phrase, setPhrase] = useState('')
  const [hash, setHash] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [showWarning, setShowWarning] = useState(false)
  const [copied, setCopied] = useState(false)
  const [inputError, setInputError] = useState('')
  const [remember, setRemember] = useState(() => localStorage.getItem(LS_REMEMBER_KEY) === '1')

  // Auto-resume saved session
  useEffect(() => {
    const saved = localStorage.getItem(LS_VAULT_KEY)
    if (saved) {
      sessionStorage.setItem('vault_hash', saved)
      navigate(`/vault/${saved}`, { replace: true })
    }
  }, [navigate])

  const handleGeneratePhrase = () => {
    haptic.medium()
    const newPhrase = generateSeedPhrase()
    setPhrase(newPhrase)
    setHash('')
    setInputError('')
    setShowWarning(true)
    setCopied(false)
  }

  const handleCopyPhrase = () => {
    navigator.clipboard.writeText(phrase)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleAccessVault = async () => {
    const input = phrase.trim()
    if (!input) return
    haptic.medium()

    setInputError('')

    // Detect share key (64-char hex) — verify it exists in vault_shares
    if (HEX_64.test(input)) {
      setIsLoading(true)
      try {
        const { data, error } = await resolveShareKey(getSupabase(), input)

        if (error || !data) {
          setInputError('Share key not found. Only existing share keys are accepted.')
          return
        }
        navigate(`/shared/${input}`)
      } catch {
        setInputError('Failed to verify share key. Please try again.')
      } finally {
        setIsLoading(false)
      }
      return
    }

    // Validate 12-word seed phrase
    const words = input.split(/\s+/).filter(Boolean)
    if (words.length !== 12) {
      setInputError('Enter a 12-word seed phrase or a 64-character share key.')
      return
    }

    if (!window.isSecureContext) {
      setInputError('A secure connection (HTTPS) is required. Open the app from your deployed URL, not a local network address.')
      return
    }

    setIsLoading(true)
    try {
      const vaultHash = await hashSeedPhrase(input)
      setHash(vaultHash)
      sessionStorage.setItem('vault_hash', vaultHash)

      // Persist session if "Remember me" is checked
      if (remember) {
        localStorage.setItem(LS_VAULT_KEY, vaultHash)
        localStorage.setItem(LS_REMEMBER_KEY, '1')
      } else {
        localStorage.removeItem(LS_VAULT_KEY)
        localStorage.removeItem(LS_REMEMBER_KEY)
      }

      navigate(`/vault/${vaultHash}`)
    } catch (e) {
      setInputError(e instanceof Error ? e.message : 'Something went wrong. Try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const truncatedHash = hash ? `${hash.slice(0, 16)}...${hash.slice(-16)}` : ''

  return (
    <div
      className="fixed inset-0 overflow-hidden"
      style={{ backgroundColor: 'var(--surface-0)' }}
    >
      {/* Theme toggle */}
      <div className="absolute right-4 z-20" style={{ top: 'calc(1rem + env(safe-area-inset-top))' }}>
        <ThemeToggle />
      </div>

      {/* Animated gradient background */}
      <div
        className="absolute inset-0 animate-gradient-shift"
        style={{
          background:
            'radial-gradient(ellipse at 30% 20%, var(--accent-subtle) 0%, transparent 60%), radial-gradient(ellipse at 70% 80%, var(--accent-subtle) 0%, transparent 60%)',
        }}
      />

      {/* Market pulse canvas */}
      <MarketPulse opacity={isDark ? 0.45 : 0.65} />

      {/* Subtle grid pattern overlay */}
      <div
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            `linear-gradient(var(--grid-line-color) 1px, transparent 1px), linear-gradient(90deg, var(--grid-line-color) 1px, transparent 1px)`,
          backgroundSize: '60px 60px',
        }}
      />

      {/* Scrollable content layer */}
      <div className="absolute inset-0 overflow-y-auto z-10 p-4">
        <div className="min-h-full flex items-center justify-center">
          <div className="w-full max-w-md relative">
        {/* Logo / Title */}
        <div className="text-center mb-12">
          <div
            className="inline-flex items-center gap-3 text-5xl"
            style={{ fontFamily: 'var(--font-display)', color: 'var(--text-primary)' }}
          >
            <Logo size={36} style={{ color: 'var(--accent)', opacity: 0.4 }} />
            <span><span style={{ color: 'var(--accent)' }}>w</span>arket</span>
          </div>
          <p
            className="mt-2"
            style={{
              color: 'var(--text-tertiary)',
              fontSize: '0.875rem',
              letterSpacing: '0.05em',
            }}
          >
            Your market, your vault
          </p>
        </div>

        {/* Card */}
        <div
          className="p-8 space-y-6"
          style={{
            backgroundColor: 'var(--surface-1)',
            border: '1px solid var(--border-default)',
            borderRadius: 'var(--radius-lg)',
            boxShadow: 'var(--landing-shadow)',
          }}
        >
          {/* Textarea */}
          <div className="space-y-2">
            <label className="label-sm block">Seed Phrase or Share Key</label>
            <textarea
              value={phrase}
              onChange={e => { setPhrase(e.target.value); setInputError('') }}
              onKeyDown={e => {
                if (e.key === 'Enter') {
                  e.preventDefault()
                  handleAccessVault()
                }
              }}
              enterKeyHint="go"
              placeholder="Enter a 12-word seed phrase or paste a share key..."
              className="input-field h-24 resize-none"
              style={{ fontFamily: 'var(--font-mono)' }}
            />
            {inputError && (
              <p style={{ color: 'var(--error)', fontSize: '0.75rem' }}>{inputError}</p>
            )}
          </div>

          {/* Generate Button */}
          <button onClick={handleGeneratePhrase} className="btn-ghost w-full">
            Generate New Seed Phrase
          </button>

          {/* Warning */}
          {showWarning && (
            <div
              className="space-y-2"
              style={{
                backgroundColor: 'var(--accent-subtle)',
                border: '1px solid var(--accent-glow)',
                borderRadius: 'var(--radius-md)',
                padding: '12px',
              }}
            >
              <p
                style={{
                  color: 'var(--accent)',
                  fontSize: '0.875rem',
                  fontWeight: 600,
                }}
              >
                Save your seed phrase
              </p>
              <p
                style={{
                  color: 'var(--text-secondary)',
                  fontSize: '0.75rem',
                }}
              >
                Write it down or store it securely. You'll need it to access your vault.
              </p>
              <button onClick={handleCopyPhrase} className="btn-primary w-full mt-2">
                {copied ? 'Copied!' : 'Copy to Clipboard'}
              </button>
            </div>
          )}

          {/* Remember me */}
          <label
            className="flex items-center gap-2 cursor-pointer select-none"
            style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}
          >
            <input
              type="checkbox"
              checked={remember}
              onChange={e => setRemember(e.target.checked)}
              style={{ accentColor: 'var(--accent)' }}
            />
            Keep session open
          </label>

          {/* Hint */}
          <p style={{ fontSize: '0.6875rem', color: 'var(--text-muted)', textAlign: 'center' }}>
            Seed phrase opens your vault. Share key opens read-only access.
          </p>

          {/* Access Vault Button */}
          <button
            onClick={handleAccessVault}
            disabled={!phrase.trim() || isLoading}
            className="btn-primary w-full"
            style={{ padding: '12px 16px', fontSize: '0.9375rem' }}
          >
            {isLoading ? 'Verifying...' : 'Access Vault'}
          </button>

          {/* Hash Preview */}
          {truncatedHash && (
            <div className="space-y-2">
              <p className="label-sm">Vault Hash</p>
              <div
                style={{
                  backgroundColor: 'var(--surface-2)',
                  borderRadius: 'var(--radius-md)',
                  padding: '12px',
                }}
              >
                <p
                  className="break-all"
                  style={{
                    fontFamily: 'var(--font-mono)',
                    fontSize: '0.75rem',
                    color: 'var(--text-secondary)',
                  }}
                >
                  {truncatedHash}
                </p>
              </div>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                This hash is derived from your seed phrase and is used to secure your vault.
              </p>
            </div>
          )}
        </div>

        {/* Footer */}
        <p
          className="text-center mt-8"
          style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}
        >
          Your seed phrase is never stored or transmitted.
        </p>
          </div>
        </div>
      </div>
    </div>
  )
}
