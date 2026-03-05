Turn warket into a Progressive Web App (PWA). The app uses Vite + React + TypeScript and is deployed on Vercel.

## STATUS KEY
- ✅ Already done
- 🔧 Needs work
- ❌ Not started

---

## 1. WEB APP MANIFEST ✅ (partial)

`public/site.webmanifest` already exists at `/site.webmanifest` (referenced correctly in index.html).

Current content is minimal — needs these additions:
- `"description": "Private research & investment tracker"`
- `"start_url": "/"`
- `"orientation": "portrait-primary"`
- `"purpose": "any maskable"` on both icon entries
- Fix `theme_color`: currently `#2a9d8f` (teal accent) — should be `#0a0b10` to match background

Icons already in `public/`:
- `android-chrome-192x192.png` ✅
- `android-chrome-512x512.png` ✅
- `apple-touch-icon.png` ✅

> Do NOT rename or move the manifest to `manifest.json`. The file is already `site.webmanifest` and `index.html` already references it.

IMPORTANT: If a light theme exists, the theme_color should update dynamically based on the active theme. Add logic in `src/contexts/ThemeContext.tsx` to update the `<meta name="theme-color">` tag when the theme changes:
- Dark: `#0a0b10`
- Light: `#f8f9fb` (or whatever the light background CSS variable resolves to)

---

## 2. HTML META TAGS 🔧

`index.html` already has:
- ✅ `<link rel="manifest" href="/site.webmanifest">`
- ✅ `<meta name="theme-color" content="#08090d">`
- ✅ `<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">`
- ✅ `<meta name="viewport" content="width=device-width, initial-scale=1.0">`

Still needs:
- 🔧 `<meta name="apple-mobile-web-app-capable" content="yes">`
- 🔧 `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`
- 🔧 Update viewport to add `viewport-fit=cover`: `width=device-width, initial-scale=1, viewport-fit=cover`

---

## 3. SERVICE WORKER ❌

`vite-plugin-pwa` is not installed. No service worker exists.

Install: `npm install -D vite-plugin-pwa`

Configure in `vite.config.ts`:
- Use `"generateSW"` strategy (Workbox auto-generates the SW)
- Runtime caching strategies:
  - App shell (HTML, JS, CSS): CacheFirst
  - Google Fonts + Fontshare: CacheFirst with 30-day expiration
  - Favicon API (google.com/s2/favicons): CacheFirst with 7-day expiration
  - Supabase API calls: NetworkFirst (always try fresh data, fall back to cache)
- Set `cleanupOutdatedCaches: true`
- Set `skipWaiting: true` (auto-activate new service worker)
- Point `manifest` at `site.webmanifest` (or let the plugin generate from config — either works)

---

## 4. OFFLINE FALLBACK ❌

Create a simple offline indicator component:
- When `navigator.onLine` is false, show a subtle banner at the top of the app: "You're offline — showing cached data"
- Style with yellow/amber background, dismissible
- The app still renders with whatever data was cached
- Hide banner automatically when connection returns

Listen to `window` `'online'` and `'offline'` events.

---

## 5. INSTALL PROMPT ❌

Create a subtle, non-intrusive install prompt:
- Listen for the `'beforeinstallprompt'` event (Chrome/Android only)
- Show a small banner or button in the header: "Install App" with a download icon
- When clicked, trigger the native install dialog
- After install or dismissal, hide permanently (`localStorage` key: `"warket-pwa-dismissed"`)
- On iOS (detect via `navigator.userAgent`), show a tooltip: "Tap Share → Add to Home Screen" (iOS doesn't support `beforeinstallprompt`)

---

## 6. SAFE AREA HANDLING ❌

For devices with notches or dynamic islands:
- Add `padding-top: env(safe-area-inset-top)` to the header
- Add `padding-bottom: env(safe-area-inset-bottom)` to any fixed bottom elements
- The `viewport-fit=cover` meta tag (added in step 2) enables this

---

## 7. DO NOT

- Don't change any existing functionality
- Don't add push notifications (not reliable across platforms)
- Don't cache Supabase auth tokens in the service worker
- Don't break the existing localStorage theme system (`warket-theme`)
- Don't rename `site.webmanifest` or move it

---

## After completing, tell me:
1. How to test the PWA locally (Vite dev server doesn't serve SW by default — use `vite preview` or `vite-plugin-pwa`'s dev SW option)
2. What the Lighthouse PWA score looks like
3. Any iOS-specific caveats I should know about
