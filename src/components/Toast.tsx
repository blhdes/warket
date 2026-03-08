import { useState, useCallback } from 'react'
import { haptic } from '../lib/haptics'

interface ToastMessage {
  id: number
  text: string
  type: 'error' | 'success'
}

let addToast: (text: string, type: 'error' | 'success') => void = () => {}

export function toast(text: string, type: 'error' | 'success' = 'error') {
  if (type === 'success') haptic.success()
  else haptic.error()
  addToast(text, type)
}

let nextId = 0

export default function ToastContainer() {
  const [toasts, setToasts] = useState<ToastMessage[]>([])

  addToast = useCallback((text: string, type: 'error' | 'success') => {
    const id = nextId++
    setToasts(prev => [...prev, { id, text, type }])
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
    }, 3200)
  }, [])

  if (toasts.length === 0) return null

  return (
    <div className="fixed top-4 right-4 z-50 space-y-2" style={{ maxWidth: '360px' }}>
      {toasts.map(t => (
        <div
          key={t.id}
          className="animate-toast-in relative overflow-hidden"
          style={{
            padding: '12px 16px 16px',
            borderRadius: 'var(--radius-md)',
            fontSize: '0.875rem',
            boxShadow: 'var(--card-shadow)',
            backgroundColor: t.type === 'error' ? 'var(--error-bg)' : 'var(--success-bg)',
            border: `1px solid ${t.type === 'error' ? 'var(--error-border)' : 'var(--success-border)'}`,
            color: t.type === 'error' ? 'var(--error)' : 'var(--success)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
          }}
        >
          {t.text}
          <div
            className="absolute bottom-0 left-0 h-[2px] animate-toast-progress"
            style={{
              backgroundColor: t.type === 'error' ? 'var(--error)' : 'var(--success)',
              opacity: 0.5,
            }}
          />
        </div>
      ))}
    </div>
  )
}
