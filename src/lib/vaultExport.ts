import type { Resource } from './types'

/* ── Export format (version 1, shared with iOS and the server) ── */

interface ExportedAsset {
  name: string
  ticker: string
  summary: string
  description: string
  tags: string[]
  resources: Resource[]
  image_url?: string
}

interface ExportedList {
  name: string
  tags: string[]
  assets: ExportedAsset[]
}

export interface VaultExport {
  version: number
  app: string
  exported_at: string
  lists: ExportedList[]
}

/* ── Download ───────────────────────────────────────────────── */

/** Saves an export (built by the server) as a JSON file and returns what it holds. */
export function downloadExport(payload: VaultExport) {
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  const date = new Date().toISOString().slice(0, 10)
  a.href = url
  a.download = `warket-export-${date}.json`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)

  return {
    listsExported: payload.lists.length,
    assetsExported: payload.lists.reduce((sum, l) => sum + l.assets.length, 0),
  }
}

/* ── Quick local check before upload ────────────────────────── */

/**
 * Catches an obviously wrong file before it is sent. The server checks every
 * field and limit again and refuses the whole import if anything is off.
 */
export function validateImportData(data: unknown): { valid: boolean; error?: string } {
  if (!data || typeof data !== 'object') return { valid: false, error: 'Invalid JSON structure' }

  const d = data as Record<string, unknown>

  if (typeof d.version !== 'number') return { valid: false, error: 'Missing or invalid "version" field' }
  if (!Array.isArray(d.lists)) return { valid: false, error: 'Missing "lists" array' }

  for (let i = 0; i < d.lists.length; i++) {
    const list = d.lists[i] as Record<string, unknown>
    if (typeof list.name !== 'string' || !list.name.trim()) {
      return { valid: false, error: `List ${i + 1}: missing or empty "name"` }
    }
    if (!Array.isArray(list.assets)) {
      return { valid: false, error: `List "${list.name}": missing "assets" array` }
    }
    for (let j = 0; j < (list.assets as unknown[]).length; j++) {
      const asset = (list.assets as Record<string, unknown>[])[j]
      if (typeof asset.name !== 'string' || !asset.name.trim()) {
        return { valid: false, error: `List "${list.name}", asset ${j + 1}: missing or empty "name"` }
      }
    }
  }

  return { valid: true }
}
