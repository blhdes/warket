# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev       # Start dev server at http://localhost:5173
npm run build     # TypeScript compile + Vite production build
npm run lint      # ESLint validation
npm run preview   # Preview production build locally
npx vitest run --exclude 'src/test/fetchTitle.integration.test.ts'   # unit tests, no network
```

`npm run build` runs `tsc -b` first, so TypeScript errors surface there. The server has its own checks: `cd server && npm run check && npm test`.

## Environment

Requires a `.env` file (see `.env.example`) with the address of the warket server (`server/`, a Cloudflare Worker):
```
VITE_API_URL=http://localhost:8787
```

To run both locally: `cd server && npm run dev` in one terminal, `npm run dev` in another.
The server's API contract is `server/API.md`.

### Setup & Hooks
* **Initialization:** To initialize Claude's local settings and security hooks for a new environment, run `npm run init-claude`.

## Architecture

**warket** is a privacy-first asset watchlist app. Core concept: a 12-word BIP39 seed phrase is SHA-256 hashed client-side to produce a `vault_hash`, which is the sole identity token. No accounts, no emails — just the hash.

### Auth & Security Flow

1. User enters/generates a seed phrase → `src/features/auth/seedPhrase.ts` hashes it via Web Crypto API
2. Hash becomes the URL segment: `/vault/:hash`
3. Every server call sends `Authorization: Bearer <vault hash>` (set in `src/lib/api.ts`). The server keeps only a SHA-256 fingerprint of it.
4. The server filters every row by that vault: multi-tenancy without accounts
5. Read-only share keys are made by the server (`PUT /v1/share`). A viewer sends `Authorization: Share <key>` and the server refuses every write

### Routing & Pages

```
App.tsx
├── /                      → LandingPage.tsx (seed phrase entry/generation)
├── /vault/:hash           → VaultPage.tsx (main app)
└── /shared/:shareHash     → SharedVaultPage.tsx (read-only view)
```

### Feature Modules

Code is organized by feature under `src/features/`:
- `auth/` — seed phrase generation (own 534-word list), SHA-256 hashing
- `assets/` — asset cards, list view, add/edit modals
- `lists/` — lists grid, CRUD, search/filter

### Key Libraries

| File | Role |
|------|------|
| `src/lib/api.ts` | The only file that talks to the server: `createVaultApi(access)` returns every call, errors become `ApiError` with a readable message |
| `src/lib/types.ts` | Shared TypeScript interfaces (`Resource`, `VaultList`, `ListWithCount`, `Asset`) |
| `src/lib/vaultExport.ts` | Export file format, file download, quick local check before import |
| `src/lib/fetchTitle.ts` | URL title fetching (races multiple CORS proxies) |

### State Management

No external state library. Uses React Context only for theme (`src/contexts/ThemeContext.tsx`). Everything else is local component state. Pages build one `api` object and pass it down as a prop; `api.readOnly` is true for a shared vault.

### Styling

- **Tailwind CSS v4** with custom design tokens
- Theme switching via `data-theme="dark"|"light"` on `<html>` element
- All color/typography/spacing tokens defined as CSS custom properties in `src/index.css`
- Dark theme is default; flash prevention script in `index.html` applies theme before CSS loads
- Custom font stack: Instrument Serif (display), General Sans (body), JetBrains Mono (mono)
- Accent color: deep teal (`#2a9d8f` dark / `#1a8377` light)

### Database

Cloudflare D1 (SQLite) behind the Worker in `server/`. Schema in `server/src/db/schema.ts`, migrations in `server/migrations/`.
- Tables: `lists`, `assets`, `shares`, keyed by `vault_id` (a fingerprint of the vault hash)
- The server sets positions: new lists and assets go last, reorder is one all-or-nothing `PUT .../order`
- The old Supabase project (`supabase/schema.sql`) still serves the live site until the data is moved to Cloudflare

## Security & Environment

- **Seed phrases never leave the client.** Generation and hashing in `src/features/auth/seedPhrase.ts` are local. Never suggest or implement code that transmits a seed phrase over the network.
- Only the resulting vault hash is sent to the server, in the `Authorization` header, never in a URL query or body.
- Never cache server answers in the service worker: they depend on the `Authorization` header, so a URL-keyed cache would mix up vaults.

## Coding Style

- Only comment complex or non-obvious logic — skip comments for standard React/Vite patterns, JSX structure, and self-evident operations
- Avoid verbose comments that restate what the code already clearly expresses

## Always Reference

Before implementing any new feature, read `src/lib/types.ts` and verify that your implementation is compatible with the existing `Resource`, `VaultList`, and `Asset` interfaces. Do not introduce new data shapes that duplicate or conflict with these types.

## Core References

Read these first when refactoring any data logic:

| File | Purpose |
|------|---------|
| `src/lib/types.ts` | Central TypeScript interfaces — `Resource`, `VaultList`, `Asset` |
| `src/lib/api.ts` | Every server call. Add new calls here, never `fetch` the server from a component |
| `server/API.md` | The server contract both apps follow |

### Drag & Drop

Uses `@dnd-kit` (core + sortable + utilities). After a drop the new order is sent in one request; on failure the view reloads from the server.

### Components

Reusable components in `src/components/`:
- `Modal.tsx` — portalized, swipe-to-dismiss on mobile
- `MarkdownEditor.tsx` — toolbar + preview toggle
- `MarketPulse.tsx` — animated canvas background on landing page
- `Toast.tsx` — notification system
- `Skeleton.tsx` — loading states
