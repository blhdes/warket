import type { AssetRow, ListRow } from './db/schema'

// Every response is built field by field, so internal columns such as `vault_id` can never leak.

export const toList = (row: ListRow) => ({
  id: row.id,
  name: row.name,
  tags: row.tags,
  position: row.position,
  created_at: row.created_at,
  updated_at: row.updated_at,
})

export const toListWithCount = (row: ListRow & { asset_count: number }) => ({
  ...toList(row),
  asset_count: row.asset_count,
})

export const toAsset = (row: AssetRow) => ({
  id: row.id,
  list_id: row.list_id,
  name: row.name,
  ticker: row.ticker,
  summary: row.summary,
  description: row.description,
  tags: row.tags,
  resources: row.resources,
  image_url: row.image_url,
  position: row.position,
  created_at: row.created_at,
})

/** Same shape both apps export today: `image_url` is left out when empty. */
export const toExportedAsset = (row: AssetRow) => ({
  name: row.name,
  ticker: row.ticker,
  summary: row.summary,
  description: row.description,
  tags: row.tags,
  resources: row.resources,
  ...(row.image_url ? { image_url: row.image_url } : {}),
})

export const nowIso = () => new Date().toISOString()
