# Migration 2: Capacitor (Native iOS & Android)

## STATUS KEY
- ✅ Already done
- 🔧 Needs work
- ❌ Not started

---

## What's already done (from PWA phase) ✅

No need to re-implement:
- `viewport-fit=cover` ✅ in `index.html`
- `apple-mobile-web-app-capable` and `apple-mobile-web-app-status-bar-style` ✅ in `index.html`
- `env(safe-area-inset-top/bottom)` ✅ already in `OfflineBanner.tsx` and `InstallPrompt.tsx`
- `theme-color` meta tag dynamically updated on theme change ✅ already in `ThemeContext.tsx`
- `vite-plugin-pwa` + Workbox service worker ✅ already configured in `vite.config.ts`

---

## File change checklist

| File | Action |
|------|--------|
| `package.json` | Add `cap:*` scripts |
| `.gitignore` | Add `/android`, `/ios` |
| `capacitor.config.ts` | Create (new file at root) |
| `src/main.tsx` | Add Keyboard init only |
| `src/contexts/ThemeContext.tsx` | Extend existing `useEffect` for StatusBar sync |
| `src/components/InstallPrompt.tsx` | Add `isNativePlatform()` early return |
| `src/lib/haptics.ts` | Create (new file) |

---

## 1. INSTALL PACKAGES ❌

Run all installs before any config:

```bash
npm install @capacitor/core @capacitor/cli
npm install @capacitor/android @capacitor/ios
npm install @capacitor/status-bar @capacitor/keyboard
npm install @capacitor/splash-screen
npm install @capacitor/haptics
```

Then init and add platforms:

```bash
npx cap init "warket" "com.warket.app" --web-dir dist
npx cap add android
npx cap add ios
```

---

## 2. CAPACITOR CONFIG ❌

Create `capacitor.config.ts` at project root:

```ts
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.warket.app',
  appName: 'warket',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
    // No hostname — BrowserRouter works fine inside Capacitor's WebView.
    // The app always boots at root and React Router handles navigation client-side.
  },
  ios: {
    contentInset: 'automatic',
    preferredContentMode: 'mobile',
    scheme: 'warket'
  },
  android: {
    buildOptions: {
      keystorePath: undefined,
      keystoreAlias: undefined
    }
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      launchShowDuration: 1500,
      backgroundColor: '#08090d',  // matches --surface-0 dark theme
      showSpinner: false,
      androidScaleType: 'CENTER_CROP',
      splashFullScreen: true,
      splashImmersive: true
    }
  }
};

export default config;
```

---

## 3. PACKAGE.JSON SCRIPTS ❌

Add to the `scripts` block in `package.json`:

```json
"cap:build": "npm run build && npx cap sync",
"cap:android": "npm run build && npx cap sync && npx cap open android",
"cap:ios": "npm run build && npx cap sync && npx cap open ios",
"cap:run:android": "npm run build && npx cap sync && npx cap run android",
"cap:run:ios": "npm run build && npx cap sync && npx cap run ios"
```

Workflow is always: build web → sync to native → open IDE or run on device.

---

## 4. .GITIGNORE ❌

Add to `.gitignore`:

```
# Capacitor native projects
/android
/ios
```

---

## 5. STATUS BAR + KEYBOARD ❌

**StatusBar sync belongs in `ThemeContext.tsx`, not `main.tsx`**, because it needs to react to theme changes. Extend the existing `useEffect`:

```ts
// src/contexts/ThemeContext.tsx
import { Capacitor } from '@capacitor/core';
import { StatusBar, Style } from '@capacitor/status-bar';

// Inside ThemeProvider — extend the existing useEffect:
useEffect(() => {
  document.documentElement.setAttribute('data-theme', theme)
  localStorage.setItem(STORAGE_KEY, theme)
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', theme === 'dark' ? '#08090d' : '#f8f9fb')

  if (Capacitor.isNativePlatform()) {
    StatusBar.setStyle({ style: theme === 'dark' ? Style.Dark : Style.Light })
    StatusBar.setOverlaysWebView({ overlay: true })
  }
}, [theme])
```

`main.tsx` only needs the Keyboard plugin (one-time init, not theme-dependent):

```ts
// src/main.tsx — add before createRoot()
import { Capacitor } from '@capacitor/core';
import { Keyboard, KeyboardResize } from '@capacitor/keyboard';

if (Capacitor.isNativePlatform()) {
  Keyboard.setResizeMode({ mode: KeyboardResize.Ionic })
  Keyboard.setScroll({ isDisabled: false })
}
```

---

## 6. SUPPRESS INSTALL PROMPT ON NATIVE ❌

The PWA install prompt (and the iOS "tap Share" tip) is meaningless inside a native Capacitor app. Add a guard at the top of `InstallPrompt.tsx`:

```ts
import { Capacitor } from '@capacitor/core';

export default function InstallPrompt() {
  if (Capacitor.isNativePlatform()) return null
  // ... rest unchanged
}
```

---

## 7. SAFE AREAS ✅ (already done)

`env(safe-area-inset-top/bottom)` is already applied in `OfflineBanner.tsx` and `InstallPrompt.tsx`. The `viewport-fit=cover` meta tag is already in `index.html`. No changes needed — verify these render correctly inside the native WebView after first build.

---

## 8. SPLASH SCREEN ASSETS ❌

The `SplashScreen` plugin config (step 2) handles the color. For a proper logo splash:
- iOS: replace images in `ios/App/App/Assets.xcassets/Splash.imageset/`
- Android: place splash images in `android/app/src/main/res/drawable/`

A solid `#08090d` background is fine for now; add logo assets later.

---

## 9. HAPTIC FEEDBACK ❌ (optional)

Create `src/lib/haptics.ts`:

```ts
import { Capacitor } from '@capacitor/core';
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics';

export const haptic = {
  light: () => Capacitor.isNativePlatform() && Haptics.impact({ style: ImpactStyle.Light }),
  medium: () => Capacitor.isNativePlatform() && Haptics.impact({ style: ImpactStyle.Medium }),
  success: () => Capacitor.isNativePlatform() && Haptics.notification({ type: NotificationType.Success }),
  error: () => Capacitor.isNativePlatform() && Haptics.notification({ type: NotificationType.Error }),
};
```

Suggested callsites:
- `haptic.light()` — button clicks, card expand/collapse, theme toggle
- `haptic.success()` — successful save operations
- `haptic.error()` — delete confirmations

All calls are no-ops on web due to the `isNativePlatform()` guard.

---

## 10. DO NOT

- Don't modify any existing web code behavior
- Don't remove the PWA manifest or service worker (Capacitor ignores them in native; they still work on web)
- Don't change Supabase configuration
- Don't change the localStorage theme system (`warket-theme`)
- Don't add a `hostname` to the Capacitor server config — it's unnecessary and could cause CORS issues with Supabase
- The web version must keep working exactly as before — Capacitor is purely additive

---

## Testing

### Physical device

**Android:**
1. Enable Developer Options + USB Debugging on the device
2. Connect via USB, accept the trust prompt
3. `npm run cap:run:android` — it will detect the device

**iOS:**
1. Requires a paid Apple Developer account ($99/yr) for physical device signing
2. Connect via USB, trust the Mac on the device
3. `npm run cap:run:ios` — select the device in the Xcode dialog that opens

### Emulator / Simulator

**Android:**
- `npm run cap:android` opens Android Studio
- Create an AVD (Virtual Device) from the Device Manager
- Run the app from the IDE, or use `npx cap run android --target <emulator-id>`

**iOS:**
- `npm run cap:ios` opens Xcode
- Select a simulator from the device toolbar
- Press Run (no Apple account needed for simulator)

---

## Folder structure after `cap add`

```
warket/
├── android/              ← gitignored
├── ios/                  ← gitignored
├── public/
├── src/
├── capacitor.config.ts   ← new
├── package.json
└── vite.config.ts
```

---

## Potential permission issues

- **Android internet** — auto-added by Capacitor; no action needed
- **iOS native features** — camera, notifications, Face ID each require a usage description string in `Info.plist`; missing strings cause App Store rejection
- **Supabase CORS** — with `androidScheme: 'https'`, Supabase sees requests from `https://localhost`; verify your Supabase project's allowed origins include this or that the anon key policy permits it
