import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { Capacitor } from '@capacitor/core'
import { Keyboard, KeyboardResize } from '@capacitor/keyboard'
import { StatusBar } from '@capacitor/status-bar'

if (Capacitor.isNativePlatform()) {
  // Ensure status bar overlays the WebView so web content extends behind it.
  // Config-only setting can be unreliable; runtime call guarantees it.
  StatusBar.setOverlaysWebView({ overlay: true })

  // "Body" mode adjusts the <body> height when the keyboard appears, but keeps
  // the WKWebView itself full-screen. This prevents the native background color
  // from ever becoming visible during keyboard animations.
  Keyboard.setResizeMode({ mode: KeyboardResize.Body })
  Keyboard.setScroll({ isDisabled: false })

  // Prevent WKWebView's native UIScrollView from bouncing the document.
  // Walks up the DOM: if the touch target is inside an explicit scroll container,
  // the event is allowed through; otherwise the document-level bounce is blocked.
  document.addEventListener('touchmove', (e) => {
    let el = e.target as HTMLElement | null
    while (el && el !== document.documentElement) {
      const overflowY = window.getComputedStyle(el).overflowY
      if ((overflowY === 'auto' || overflowY === 'scroll') && el.scrollHeight > el.clientHeight) {
        return
      }
      el = el.parentElement
    }
    if (e.cancelable) e.preventDefault()
  }, { passive: false })
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
