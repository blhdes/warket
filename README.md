# warket

**A secure, seed-based asset vault for organizing and tracking financial assets with privacy at its core.**

**Live:** [asset-cafe.vercel.app](https://asset-cafe.vercel.app/)

> Two clients, one server: this **web app** (React, documented below, deployed above) and a **native iOS app** in [`warket-ios/`](#native-ios-app) (Swift/SwiftUI). Both talk to the warket server in [`server/`](server/), a Cloudflare Worker with a D1 database.

---

## Overview

warket is a privacy-first web application for managing curated lists of financial assets (stocks, crypto, real estate, etc.). Each vault's data is kept apart on the server using a **seed phrase-based vault system**. No accounts, no emails: just a 12-word phrase that unlocks your vault.

### Key Features

- **Seed-phrase authentication**: Generate a 12-word phrase from warket's own word list. Your vault is derived from its hash.
- **No credentials stored**: The seed phrase is hashed on your device and never sent. The server does not store the vault hash either, only a SHA-256 fingerprint of it.
- **One small server**: A Cloudflare Worker with a D1 (SQLite) database stored in the EU. It checks every request and keeps each vault's rows apart.
- **Read-only shared vaults**: Give anyone a share key for read-only access, without exposing the seed phrase. Viewers can browse and export. The server refuses every change made with a share key.
- **Session persistence**: "Keep session open" checkbox on the landing page saves your vault hash in `localStorage` so you stay logged in across tabs and browser restarts. Clicking "Lock" clears it.
- **Import/Export**: Export your vault as JSON with a list-selector modal (choose which lists to include). Import with auto-positioning and same-name list merging. All or nothing: a broken file writes nothing.
- **PWA support**: Installable as a Progressive Web App. Includes offline banner on connectivity loss, native Chrome install prompt, and iOS share-sheet hint.
- **Asset management**: Organize assets into lists, add logos, descriptions (markdown), tags, and resource links.
- **Smart search**: Search lists by name, or by asset names and tickers within lists.
- **Edit lists**: Rename, edit tags, or delete lists from an edit modal with confirmation flow.
- **Drag-and-drop reordering**: Reorder lists, asset cards, and resources via pointer or touch drag. Powered by @dnd-kit with accessible keyboard support. DnD is automatically disabled when cards are expanded, filters are active, or in read-only mode.
- **Inline summary editing**: Edit asset summaries directly from the card with a pencil icon toggle.
- **Custom asset images**: Upload logos via URL to replace the default gradient ticker badge.
- **Full markdown editor**: Built-in toolbar for formatting descriptions (bold, italic, headings, lists, code, links).
- **Dark/Light theme**: Toggle between dark and light themes. Preference persists in localStorage with flash-free page loads.
- **Responsive UI**: Mobile-first design with bottom-sheet modals, swipe-to-dismiss, and desktop hover interactions. Drag handles hidden on mobile for clean touch UX.
- **Design system**: Deep teal accent, Instrument Serif + General Sans + JetBrains Mono typography, sharp editorial radii, dual-theme CSS custom properties.

---

## Tech Stack

- **Frontend**: React 19 + TypeScript + Vite
- **Styling**: Tailwind CSS 4 + custom CSS design tokens (dual-theme via `data-theme` attribute)
- **Server**: Cloudflare Worker (Hono, Drizzle) + D1 (SQLite), in [`server/`](server/)
- **Routing**: React Router 7
- **Auth**: Client-side seed phrase → SHA-256 hash → vault partition
- **Sharing**: SHA-256 with domain separation (`:share` suffix) for one-way share key derivation
- **Drag & Drop**: @dnd-kit (core, sortable, utilities)
- **Markdown**: marked.js for rendering
- **PWA**: vite-plugin-pwa (Workbox service worker, runtime caching)
- **Icons**: Heroicons (inline SVG)

---

## How It Works

### 1. Seed Phrase Generation & Hashing

On the landing page, users can:
- Generate a new 12-word seed phrase
- Paste an existing seed phrase to access their vault
- Paste a 64-character share key to open a read-only shared vault

The app auto-detects the input type: a 64-character hex string is checked with the server (`GET /v1/session`) before navigating, and unknown share keys are rejected with an error. Anything else is validated as a 12-word seed phrase.

The seed phrase is hashed client-side using **SHA-256** (via Web Crypto API) to produce a 256-bit vault hash. The app sends this hash to the server in the `Authorization` header. The server keeps only `SHA-256(vault hash)`, stored as `vault_id`.

**No seed phrase is ever sent to the server.**

### 2. Vault Isolation

Every request carries `Authorization: Bearer <vault hash>` (owner) or `Authorization: Share <share key>` (viewer). The server turns it into a vault id and filters every query by it. The full contract is in [`server/API.md`](server/API.md).

The vault hash is stored in `sessionStorage` for the session duration. If "Keep session open" is checked, the hash is also saved to `localStorage` for persistence across tabs and browser restarts. Clicking "Lock" clears both stores and returns to the landing page.

### 3. Read-Only Shared Vaults

Vault owners can generate a **share key**: a deterministic, one-way hash derived from the vault hash using SHA-256 with domain separation (`:share` suffix). This ensures:

- The share key cannot be reversed to obtain the vault hash
- The same vault always produces the same share key
- Share keys grant read-only access only, enforced by the server

**Flow:**
1. Vault owner clicks the **Share** button (link icon) in the header
2. The server (`PUT /v1/share`) creates the share and returns the key, `SHA-256(vault_hash + ":share")`
3. The app copies the key to the clipboard
4. Anyone can paste the share key on the landing page → opens `/shared/{shareKey}` in read-only mode

**Read-only mode hides:** create/edit/delete buttons, drag-and-drop, import functionality, tag editing, summary editing, and image changes. Export with selective list picking remains available.

### 4. Import/Export

**Export:**
- Clicking Export opens the `ExportModal`: choose which lists to include via checkboxes (or "Select all")
- Downloads a timestamped JSON file (`warket-export-YYYY-MM-DD.json`) with all selected lists and their assets (name, ticker, tags, summary, description, resources)
- Position values are excluded from export: order is preserved by array sequence
- Available in both owner and read-only (shared) modes

**Import:**
- Upload a JSON file via the import button in the vault header
- Auto-positions new lists after existing ones
- Same-name lists (case-insensitive) are merged: imported assets are appended after existing assets
- The server checks the whole file and writes it in one go: a broken file writes nothing

### 5. Data Model

Defined in `server/src/db/schema.ts` (D1, SQLite). Data is stored as plain text, kept apart per vault. It is not end-to-end encrypted.

**Lists** (`lists` table)
- `id` (UUID)
- `vault_id` (text): SHA-256 of the vault hash, the partition key
- `name` (text)
- `tags` (JSON text array)
- `position` (integer): sort order, set by the server
- `created_at`, `updated_at`

**Assets** (`assets` table)
- `id` (UUID)
- `list_id` (UUID): foreign key to `lists`, deleted with its list
- `name` (text)
- `ticker` (text, may be empty)
- `summary` (text, max 250 characters)
- `description` (text, markdown)
- `tags` (JSON text array)
- `resources` (JSON array of `{title, url, favicon}`, order is array order)
- `image_url` (text, nullable): custom logo URL
- `position` (integer): sort order, set by the server
- `created_at`

**Shares** (`shares` table)
- `vault_id` (text): primary key
- `share_id` (text): SHA-256 of the share key, unique
- `created_at`

### 6. UI/UX Flow

1. **Landing Page**: Generate or enter seed phrase / paste share key → hash → navigate to `/vault/{hash}` or `/shared/{shareHash}`
2. **Vault Page**: View/create lists → click list → view/add assets. Header: session badge, import, export, share, theme toggle, lock.
3. **Shared Vault Page**: Read-only view with export, theme toggle, and home button. "Read-only" badge in header.
4. **Asset Cards**:
   - Collapsed: drag handle (desktop only), ticker badge (gradient or custom image), name, tags (desktop), resource count
   - Expanded: inline-editable summary, description editor, sortable resources, tags CRUD, delete
   - Hover ticker badge (when expanded) → camera icon overlay → click → add/edit custom logo
   - Read-only: view-only mode: no edit controls, static tags, plain resource list
5. **Drag & Drop**: Lists, asset cards, and resources can be reordered by dragging (pointer or touch). Drag handles appear on hover (desktop). Reordering is disabled when search/tag filters are active, when any asset card is expanded, or in read-only mode.
6. **Edit Lists**: Pencil icon on list cards opens an edit modal for renaming, editing tags, or deleting the list (with confirmation).
7. **Theme Toggle**: Sun/moon icon in the top-right corner. Dark mode by default. Smooth 250ms cross-fade transition with flash prevention on page load.
8. **Modals**: All modals use React portals (`createPortal(jsx, document.body)`) to avoid CSS stacking context issues. Mobile: bottom-sheet with swipe-to-dismiss. Desktop: centered with scale+fade animation.

---

## Design System

### Typography
- **Display**: Instrument Serif (Google Fonts)
- **Body**: General Sans (Fontshare)
- **Mono**: JetBrains Mono (Google Fonts)

### Color Palette (Deep Teal, dual-theme)

**Dark theme:**
- **Surfaces**: `#08090d`, `#0e1018`, `#161922`, `#1e212d`
- **Accent**: `#2a9d8f` (deep teal)
- **Borders**: `#262a38`, `#353a4d`, `#464b62`
- **Text**: `#f0f0f2`, `#a0a3b1`, `#636678`, `#464959`

**Light theme:**
- **Surfaces**: `#f8f9fb`, `#ffffff`, `#f0f1f5`, `#e4e6ed`
- **Accent**: `#1a8377` (deeper teal for contrast)
- **Borders**: `#dfe1e8`, `#c8cbd6`, `#b0b4c3`
- **Text**: `#1a1d27`, `#4a4e5c`, `#7a7f91`, `#a0a4b4`

### Logo

Ascending W: an asymmetric double-bottom chart pattern where the right arm rises higher than the left, communicating bullish breakout momentum. Monochrome, uses `currentColor` for theme compatibility.

### Favicon

Transparent background with a subtle teal-tinted rounded rectangle (`fill="#2a9d8f" opacity="0.12"`) and the W stroke. Works on both light and dark browser tab bars.

### Layout

- **Desktop max-width**: 1400px for vault and shared vault pages
- **Grid**: Responsive grid: 1 column (mobile) → 2 columns (sm) → 3 columns (lg) → 4 columns (xl)

### Border Radii
- `--radius-sm`: 2px
- `--radius-md`: 6px
- `--radius-lg`: 8px
- `--radius-pill`: 999px

### Key CSS Classes
- `.card-surface`: Hover lift + shadow + border lighten
- `.ticker-badge`: 36x36px square gradient badge (or custom image)
- `.btn-primary` / `.btn-ghost`: Button variants
- `.input-field`: Unified input styling
- `.tag-pill`: Pill badge with inset shadow when active
- `.session-badge`: Vault hash / read-only indicator in header
- `.animate-modal-sheet`: Bottom-sheet slide-up (mobile)
- `.animate-modal-backdrop`: Fade-in overlay
- `.grid-expand-wrapper`: CSS grid 0fr/1fr smooth expand/collapse
- `.drag-handle`: 6-dot grip icon, cursor grab, visible on hover (desktop only)
- `.drag-overlay`: Elevated card clone during drag (box-shadow, border accent, z-999)
- `.theme-toggle`: Sun/moon toggle button

---

## Project Structure

```
warket/
├── public/
│   ├── favicon.svg              # W logo (transparent bg + teal tint)
│   ├── favicon.ico
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── apple-touch-icon.png
│   ├── android-chrome-*.png
│   └── site.webmanifest
├── src/
│   ├── components/
│   │   ├── ExportModal.tsx      # List-selector export modal (checkboxes + select all)
│   │   ├── InstallPrompt.tsx    # PWA install prompt (Chrome native + iOS hint)
│   │   ├── OfflineBanner.tsx    # Fixed top banner shown when network is offline
│   │   ├── MarketPulse.tsx      # Animated market-movement canvas (landing page bg)
│   │   ├── Logo.tsx             # W ascending breakout as React component
│   │   ├── MarkdownEditor.tsx   # Custom markdown toolbar + textarea
│   │   ├── Modal.tsx            # Shared modal (portal + swipe)
│   │   ├── Skeleton.tsx         # Loading skeletons
│   │   ├── ThemeToggle.tsx      # Sun/moon theme toggle button
│   │   └── Toast.tsx            # Toast notifications
│   ├── contexts/
│   │   └── ThemeContext.tsx      # Theme provider (dark/light, localStorage)
│   ├── features/
│   │   ├── assets/
│   │   │   ├── AddAssetModal.tsx
│   │   │   ├── AddResourceModal.tsx
│   │   │   ├── AssetCard.tsx    # Main asset card (expand/collapse, DnD, readOnly)
│   │   │   ├── AssetListView.tsx
│   │   │   └── DescriptionModal.tsx
│   │   ├── auth/
│   │   │   └── seedPhrase.ts    # Phrase generation and SHA-256 hashing (local only)
│   │   └── lists/
│   │       └── ListsView.tsx    # List grid, DnD, search, tag filter, readOnly
│   ├── lib/
│   │   ├── api.ts               # Every call to the warket server
│   │   ├── favicon.ts           # Google favicon proxy
│   │   ├── fetchTitle.ts        # URL title fetcher (multi-strategy CORS proxy racing)
│   │   ├── haptics.ts           # Vibration feedback
│   │   ├── markdown.ts          # Markdown to safe HTML
│   │   ├── types.ts             # TypeScript types
│   │   └── vaultExport.ts       # Export file format, download, quick check before import
│   ├── pages/
│   │   ├── LandingPage.tsx      # Unified seed phrase / share key input
│   │   ├── SharedVaultPage.tsx  # Read-only vault page (via share key)
│   │   └── VaultPage.tsx        # Full vault with CRUD, import/export, share
│   ├── index.css                # Full design system + dual-theme tokens + animations
│   └── main.tsx
├── server/                      # warket server: Cloudflare Worker + D1 (see server/README.md)
│   ├── API.md                   # The API contract both apps follow
│   ├── src/                     # Routes, access checks, validation, database schema
│   └── migrations/              # D1 migrations
├── docs/archive/                # Retired material, e.g. the old Supabase schema
├── src/test/
│   ├── api.test.ts
│   ├── fetchTitle.test.ts
│   ├── fetchTitle.integration.test.ts
│   ├── markdown.test.ts
│   ├── seedPhrase.test.ts
│   └── setup.ts
├── package.json
├── tsconfig.json
├── vite.config.ts
└── README.md
```

---

## Native iOS App

A native **Swift/SwiftUI** port lives alongside the web app in `warket-ios/` (Xcode project `warket.xcodeproj`, bundle id `com.blhdes.warket`). Same server, same seed-phrase vault model: a vault opens on both.

```
warket-ios/warket/
├── Core/          · APIClient (server calls), VaultRepository, Session, VaultTransfer (JSON export/import), TitleFetcher
├── Features/
│   ├── Unlock/    · seed-phrase entry, generate/paste, shared-vault entry sheet
│   ├── Lists/     · list grid, share/export/import actions
│   └── Assets/    · asset detail, add-resource sheet
├── Models/
├── Theme/         · Liquid-Glass-over-mesh visual language, system-adaptive light/dark tokens
└── Components/
```

**Shipped so far:**
- **MVP**: vault unlock (generate/paste seed phrase), list + asset CRUD, matching the web app's core flow.
- **Liquid Glass redesign**: UI rebuilt around Liquid Glass surfaces over an animated mesh background.
- **Web parity pass**: read-only sharing (the server checks the share key and refuses writes), JSON export/import (`VaultTransfer`, byte-compatible with the web app's export format), system-adaptive theme (follows `UITraitCollection.userInterfaceStyle`, no manual toggle yet, unlike the web app's switch), and resource-title auto-fetch (`TitleFetcher`: direct `URLSession` fetch, no CORS restriction on native, with `api.microlink.io` as a fallback for JS-rendered pages).

Open it with `cd warket-ios && open warket.xcodeproj`.

---

## Setup & Installation

### Prerequisites
- Node.js 20.19+
- A Cloudflare account, only to deploy the server

### 1. Clone & Install
```bash
git clone <repository-url>
cd warket
npm install
```

### 2. Run the Server Locally

```bash
cd server
npm install
npm run db:migrate   # creates the local D1 database
npm run dev          # http://localhost:8787
```

Deploying it and the limits it enforces are described in `server/README.md` and `server/API.md`.

### 3. Environment Variables

Copy `.env.example` to `.env` in the project root. It points the web app at the server:
```env
VITE_API_URL=http://localhost:8787
```

### 4. Run Development Server
```bash
npm run dev
```

Visit `http://localhost:5173`

### 5. Run Tests
```bash
npx vitest run --exclude 'src/test/fetchTitle.integration.test.ts'   # unit tests, no network
cd server && npm run check && npm test                               # server checks and API tests
```

### 6. Build for Production
```bash
npm run build
npm run preview  # Preview production build
```

---

## Usage Guide

### Creating Your Vault

1. **Generate Seed Phrase**: Click "Generate New Seed Phrase" on the landing page
2. **Save It Securely**: Write down your 12 words. This is your only way to access the vault.
3. **Copy to Clipboard** (optional)
4. **Access Vault**: Click "Access Vault" → app hashes the phrase and navigates to your vault

### Sharing Your Vault (Read-Only)

1. Inside your vault, click the **Share** button (link icon) in the header
2. A share key is generated and copied to your clipboard
3. Send the share key to anyone
4. They paste it on the landing page → "Access Vault" → opens the vault in read-only mode
5. Viewers can browse lists, expand asset cards, view descriptions, and selectively export data

### Importing & Exporting

**Export:**
- Click the **Export** button (down-arrow icon) in the vault header
- Choose which lists to include using the checkboxes, then click **Export**
- A JSON file downloads with the selected lists and their assets

**Import:**
- Click the **Import** button (up-arrow icon) in the vault header
- Select a `.json` file
- New lists are added after existing ones
- If a list with the same name already exists, assets are merged into it

### Managing Lists

- Click **"+ New List"** to add a new list
- Name it (e.g., "Tech Stocks", "Real Estate")
- Optionally add tags for organization
- Click a list card to view its assets
- **Edit**: Click the pencil icon on a list card → rename, edit tags, or delete
- **Reorder** (desktop): Drag the grip handle to reorder lists. Order persists across sessions.
- **Search**: Type in the search bar to filter by list name, asset name, or ticker

### Managing Assets

- Inside a list, click **"+ Add Asset"**
- Fill in: Name, Ticker, Summary (optional, max 250 chars)
- Click **Save**
- The asset appears as a collapsed card

### Expanding Assets

Click any asset card to expand it. You'll see:
- **Summary** (if set): click the pencil icon to edit inline, or click "+ Add Summary" if empty
- **Description**: Click "View / Edit" to open the markdown editor
- **Resources**: URLs to external links (investor decks, articles, etc.), drag to reorder on desktop
- **Tags**: Add/remove tags for filtering
- **Custom Image**: Hover over the ticker badge → camera icon → click → paste logo URL

### Locking Your Vault

Click the **Lock** button (top-right) to:
- Clear the vault hash from both `sessionStorage` and `localStorage`
- Return to the landing page
- Require re-entering the seed phrase to access the vault again

### Keeping Your Session Open

Check the **"Keep session open"** checkbox on the landing page before accessing your vault. This saves your vault hash in `localStorage`, so you'll be automatically redirected to your vault when you revisit the app, even after closing the browser. Clicking "Lock" ends the persistent session.

---

## Security Considerations

- **Seed phrase is everything**: Losing your seed phrase = permanent loss of vault access.
- **No password recovery**: There is no "forgot password": the seed phrase IS the password.
- **Client-side hashing**: SHA-256 is computed in the browser. The hash is deterministic (same phrase = same hash).
- **Share keys are one-way**: A share key is derived from the vault hash using domain-separated SHA-256 (`hash + ":share"`). It cannot be reversed to obtain the vault hash or seed phrase.
- **Read-only enforcement**: The server answers every write made with a share key with an error (403). Hiding the edit buttons is only for comfort.
- **No keys stored**: The server keeps SHA-256 fingerprints of vault hashes and share keys, never the keys themselves. Vault data is stored as plain text, kept apart per vault.
- **Rate limits**: The server limits how many requests one address can make per minute.
- **HTTPS required**: Always serve over HTTPS in production. The seed phrase never leaves the device, but the vault hash and share keys travel in every request.

---

## Roadmap / Future Enhancements

- **Notes the server cannot read** (idea, not built): notes locked on the device with a key made from the seed phrase. Today all vault data is stored as plain text.
- **Multi-vault support**: Manage multiple vaults from one session
- **Price tracking**: Integrate live price APIs for stocks/crypto
- **Collaborative vaults**: Shared seed phrase with write access and role management

---

## Contributing

This is a personal project. If you'd like to fork and extend it, feel free! Pull requests are welcome for bug fixes and feature additions.

---

## License

MIT License. See `LICENSE` file for details.

---

## Credits

- **Design & Development**: Built with care for privacy and premium UX
- **Fonts**: Instrument Serif (Google Fonts), General Sans (Fontshare), JetBrains Mono
- **Icons**: Heroicons
- **Logo**: Custom ascending W: asymmetric double-bottom chart pattern

---

**warket**: Your market, your vault.
