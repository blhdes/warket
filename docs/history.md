# The History of Warket

## Origins: asset.cafe (February 13, 2026)

Warket began its life not as warket at all, but as **asset.cafe** — a name that hinted at something casual and approachable rather than the market-grade tool it would eventually become. The project was born in a single sweeping initial commit on February 13, 2026, establishing the entire MVP in one shot: a Vite + React + TypeScript application backed by Supabase PostgreSQL. The core architectural decision made from day one was a radical privacy stance — rather than building a traditional account system with usernames and passwords, the app would use a 12-word BIP39 seed phrase hashed client-side via the Web Crypto API. The resulting SHA-256 hash became both the user's identity and the URL segment for their vault (`/vault/:hash`). No email, no password, no server-side identity. Every Supabase query would carry this hash in an `x-vault-hash` header, and Row Level Security policies on every table would silently filter to matching rows. The initial feature set was surprisingly complete: list CRUD with search and tag filters, asset cards with ticker badges and markdown descriptions, resource links with auto title fetching via CORS proxies, and a dark-themed Tailwind CSS v4 UI with modals, toasts, and loading skeletons. The database schema included two migration files, one revealing that "resources" had been called "articles" for a brief moment before an early rename.

## Phase 7: Visual Identity and Design System (February 15, 2026)

Two days after the initial commit, the project received what was called a "Phase 7 design polish" — a label that implies six prior phases of iteration that happened before the repository even existed. This commit was among the largest in the project's history, touching 29 files and adding over 2,200 lines. The design system was rebuilt around a dark slate and amber/gold color palette expressed entirely through CSS custom properties, giving the app a premium, editorial feel. Typography became a three-font stack: Instrument Serif for display text, General Sans for body copy, and JetBrains Mono for code and tickers. A custom `MarkdownEditor` component was built with a toolbar and preview toggle. The modal system was made responsive — a scale-and-fade transition on desktop, a bottom-sheet slide-up on mobile. The logo at this stage was a "C7 Mid Handle" design — a stylized coffee cup built from ascending bars — reflecting the asset.cafe brand. A favicon suite was generated at all standard sizes using a Sharp-based Node.js script. Asset cards were significantly expanded: custom image URLs could be added to tickers, the card hover lifted with a subtle shadow, and tags became styled pill components. The `Skeleton` component gained a shimmer-sweep gradient animation and the `Toast` moved to the top-right with a progress bar. This commit established the design language that would carry forward — even as the color palette and logo would soon change.

## Drag-and-Drop, Editing, and Mobile Touch (February 16, 2026)

On February 16, the focus shifted from visual polish to interaction depth. Two pull requests were merged on the same day. The first introduced full drag-and-drop reordering using `@dnd-kit`, with batch position updates written back to Supabase after each drop event completes — a clean pattern using a dedicated `src/lib/position.ts` utility. List editing was added, making list names and metadata mutable rather than fixed at creation. Inline summary editing directly in the asset card let users update short descriptions without opening a modal. The second PR of the day addressed a painful mobile UX problem: on touch devices, drag-and-drop was conflicting with page scrolling. The solution was targeted — drag-and-drop sorting is disabled entirely when any asset card is expanded, restoring normal scroll behavior. To make this work, the library was extended with a 400ms long-press activation threshold so that a tap on a card element would not accidentally initiate a drag. These two commits together transformed warket from a read-mostly interface into something genuinely editable and reorganizable, with thoughtful attention to the different affordances of touch versus pointer input.

## The Rebrand to Warket and Dual-Theme System (February 17, 2026)

The most visible single transformation in the project's history arrived on February 17: a complete rebrand from **asset.cafe** to **warket**. The name change propagated through `package.json`, `index.html`, and all branding text. More substantively, the entire color palette was replaced — the amber/gold accent was discarded in favor of deep teal (`#2a9d8f` in dark mode, `#1a8377` in light mode), a color that connotes reliability and precision rather than warmth and leisure. The logo was redesigned from the C7 coffee-cup to an ascending W — described as "variant G," an asymmetric double-bottom chart pattern — a direct visual metaphor for watchlisting and market movement. All favicon assets were regenerated from the new SVG. Simultaneously, the app gained a full dual-theme system: a `ThemeContext` provider, a `ThemeToggle` component with sun/moon icons, `localStorage` persistence of the user's preference, and a flash-prevention script injected into `index.html` that applies the saved theme attribute to `<html>` before any CSS loads, eliminating the white flash on page load that plagues naive dark-mode implementations. Every hardcoded `rgba()` color scattered across components was replaced with CSS custom properties, making the two-theme system coherent end-to-end. This commit also fixed the lingering mobile DnD scroll regression more robustly. The rebrand was not cosmetic — it marked a shift in the project's self-conception from a casual bookmark-and-coffee tool to something positioned more seriously in the financial watchlist space.

## Collaboration Features, Import/Export, and Final Polish (February 18–19, 2026)

The final two days of the project's recorded history brought the most architecturally significant new capability: **shared vaults**. A read-only share key is derived from the vault hash via SHA-256 with domain separation, stored in a new `vault_shares` Supabase table, and resolved into a `/shared/:shareHash` route that renders the vault with a `readOnly` prop threaded all the way down through `ListsView → AssetListView → AssetCard → DescriptionModal` — suppressing all mutation UI throughout. The landing page was upgraded to auto-detect whether the user's input is a 12-word seed phrase or a 64-character hex share key, unifying the entry point. Import and export were added: JSON export supports full-vault or selective list picking via an `ExportModal`, and import handles auto-positioning and same-name list merging. The desktop layout widened to a 1,400px max-width with a four-column grid at `xl` breakpoints. On February 19, the final commit added **session persistence** — a "keep session open" checkbox that saves the vault hash to `localStorage`, allowing the vault to reopen automatically across tabs and browser restarts, with a Lock button to clear both session and local storage. Share key validation was tightened to verify against the database before navigating, rejecting non-existent keys with a user-facing error. The `fetchTitle` utility was rewritten to be attribute-order-independent in its meta tag parsing, with support for `og:title`, `twitter:title`, and `name="title"` variants across four CORS proxies. And finally, the landing page gained the **MarketPulse** animated canvas background — a theme-aware, infinitely scrolling visualization with dual palettes for dark and light mode — giving the entry screen the kinetic energy of a live market ticker without displaying any real data.

---

## Session Notes (February 21, 2026)

### Key Technical Concepts

- **warket** (formerly **asset.cafe**): A privacy-first asset watchlist web application
- **Vite + React + TypeScript**: Frontend stack
- **Supabase**: PostgreSQL backend with Row Level Security (RLS)
- **BIP39 seed phrase authentication**: 12-word phrase hashed via SHA-256 (Web Crypto API) — no traditional accounts
- **`x-vault-hash` header**: Used in every Supabase query for vault-scoped RLS filtering
- **Tailwind CSS v4**: Styling framework with CSS custom properties for theming
- **@dnd-kit**: Drag-and-drop reordering library with 400ms long-press mobile activation
- **Dual-theme system**: `ThemeContext` + `ThemeToggle`, `localStorage` persistence, flash-prevention script in `index.html`
- **Shared vaults**: SHA-256 domain-separated share key, `vault_shares` Supabase table, read-only `/shared/:shareHash` route
- **MarketPulse**: Animated canvas background on the landing page, theme-aware with dual palettes
- **Import/Export**: JSON vault export (full or selective via `ExportModal`), import with auto-positioning and list merging
- **Session persistence**: "Keep session open" checkbox saving vault hash to `localStorage`

### Commit Archaeology

Key commits examined with file stats:

| Commit | Description | Files | Insertions |
|--------|-------------|-------|------------|
| `36db66c` | Initial commit: asset.cafe MVP | 35 | 6,456 |
| `92f3995` | Phase 7 design polish | 29 | 2,239 |
| `7ea6aba` | Rebrand to warket, dual-theme, ascending W logo | 24 | 911 |
| `64c2e75` | Shared vaults, import/export, wider layout | 22 | 1,705 |
| `7007a58` | Session persistence, MarketPulse, robust title fetching | 5 | 626 |

### Routing

```
App.tsx
├── /                      → LandingPage.tsx (seed phrase entry/generation)
├── /vault/:hash           → VaultPage.tsx (main app)
└── /shared/:shareHash     → SharedVaultPage.tsx (read-only view)
```

### Key Source Files

| File | Purpose |
|------|---------|
| `src/features/auth/seedPhrase.ts` | BIP39 generation, SHA-256 hashing, share key derivation |
| `src/lib/supabase.ts` | Vault-scoped Supabase client with `x-vault-hash` header |
| `src/lib/types.ts` | Shared TypeScript interfaces (`Resource`, `VaultList`, `Asset`) |
| `src/lib/vaultExport.ts` | JSON export/import with selective list support |
| `src/lib/fetchTitle.ts` | URL title fetching (races multiple CORS proxies) |
| `src/lib/position.ts` | Batch position update for drag-and-drop reordering |
| `src/contexts/ThemeContext.tsx` | Theme provider (only global React Context in the app) |
| `supabase/schema.sql` | Full database schema — tables, columns, RLS policies |
