import { asc, count, eq, inArray, max } from 'drizzle-orm'
import type { BatchItem } from 'drizzle-orm/batch'
import { Hono } from 'hono'
import { requireOwner } from '../auth'
import { getDb } from '../db/client'
import { type AssetRow, assets, lists } from '../db/schema'
import { ApiError } from '../errors'
import { readJson } from '../http'
import { nowIso, toExportedAsset } from '../serialize'
import type { AppEnv } from '../types'
import { LIMITS, VaultExportSchema, parseInput } from '../validation'

export const transferRoutes = new Hono<AppEnv>()

// D1 allows 100 bound values per statement: lists have 7 columns, assets 11.
const LISTS_PER_INSERT = 14
const ASSETS_PER_INSERT = 9

const chunk = <T>(items: T[], size: number): T[][] =>
  Array.from({ length: Math.ceil(items.length / size) }, (_, i) => items.slice(i * size, (i + 1) * size))

transferRoutes.get('/export', async c => {
  const { vaultId } = c.get('access')
  const db = getDb(c.env)
  const wanted = new Set((c.req.query('lists') ?? '').split(',').map(s => s.trim()).filter(Boolean))

  const allLists = await db
    .select()
    .from(lists)
    .where(eq(lists.vault_id, vaultId))
    .orderBy(asc(lists.position), asc(lists.created_at), asc(lists.id))
  const selected = wanted.size ? allLists.filter(l => wanted.has(l.id)) : allLists

  const assetRows = await db
    .select()
    .from(assets)
    .where(inArray(assets.list_id, db.select({ id: lists.id }).from(lists).where(eq(lists.vault_id, vaultId))))
    .orderBy(asc(assets.position), asc(assets.created_at), asc(assets.id))
  const byList = Map.groupBy(assetRows, (a: AssetRow) => a.list_id)

  return c.json({
    version: 1,
    app: 'warket',
    exported_at: nowIso(),
    lists: selected.map(l => ({
      name: l.name,
      tags: l.tags,
      assets: (byList.get(l.id) ?? []).map(toExportedAsset),
    })),
  })
})

type Target = { id: string; nextPosition: number; assetCount: number }

/**
 * Lists are matched by name without regard to case, against existing lists and against lists
 * earlier in the same file. Matched lists get the new assets at the end; new lists go after the
 * existing ones. Everything is written in one batch, so a failure writes nothing.
 */
transferRoutes.post('/import', async c => {
  const { vaultId } = requireOwner(c)
  const data = parseInput(VaultExportSchema, await readJson(c))
  const db = getDb(c.env)
  const vaultLists = db.select({ id: lists.id }).from(lists).where(eq(lists.vault_id, vaultId))

  const existing = await db
    .select({ id: lists.id, name: lists.name, position: lists.position })
    .from(lists)
    .where(eq(lists.vault_id, vaultId))
    .orderBy(asc(lists.position), asc(lists.created_at), asc(lists.id))
  const stats = await db
    .select({ list_id: assets.list_id, total: count(), top: max(assets.position) })
    .from(assets)
    .where(inArray(assets.list_id, vaultLists))
    .groupBy(assets.list_id)
  const statsByList = new Map(stats.map(s => [s.list_id, s]))

  const byName = new Map<string, Target>()
  for (const list of existing) {
    const key = list.name.toLowerCase()
    if (byName.has(key)) continue // duplicates already in the vault: the first one wins
    const s = statsByList.get(list.id)
    byName.set(key, { id: list.id, nextPosition: (s?.top ?? -1) + 1, assetCount: s?.total ?? 0 })
  }

  const now = nowIso()
  let nextListPosition = existing.reduce((top, l) => Math.max(top, l.position + 1), 0)
  const newLists: (typeof lists.$inferInsert)[] = []
  const newAssets: (typeof assets.$inferInsert)[] = []

  for (const list of data.lists) {
    const key = list.name.toLowerCase()
    let target = byName.get(key)
    if (!target) {
      target = { id: crypto.randomUUID(), nextPosition: 0, assetCount: 0 }
      byName.set(key, target)
      newLists.push({
        id: target.id,
        vault_id: vaultId,
        name: list.name,
        tags: list.tags ?? [],
        position: nextListPosition++,
        created_at: now,
        updated_at: now,
      })
    }
    for (const asset of list.assets ?? []) {
      newAssets.push({
        id: crypto.randomUUID(),
        list_id: target.id,
        name: asset.name,
        ticker: asset.ticker ?? '',
        summary: asset.summary ?? '',
        description: asset.description ?? '',
        tags: asset.tags ?? [],
        resources: asset.resources ?? [],
        image_url: asset.image_url ?? null,
        position: target.nextPosition++,
        created_at: now,
      })
      target.assetCount++
    }
    if (target.assetCount > LIMITS.assetsPerList) {
      throw new ApiError(400, 'too_many_assets', `List "${list.name}" would hold more than ${LIMITS.assetsPerList} assets.`)
    }
  }
  if (existing.length + newLists.length > LIMITS.listsPerVault) {
    throw new ApiError(400, 'too_many_lists', `The vault would hold more than ${LIMITS.listsPerVault} lists.`)
  }

  // Lists first: assets point to them.
  const statements: BatchItem<'sqlite'>[] = [
    ...chunk(newLists, LISTS_PER_INSERT).map(rows => db.insert(lists).values(rows)),
    ...chunk(newAssets, ASSETS_PER_INSERT).map(rows => db.insert(assets).values(rows)),
  ]
  const [first, ...rest] = statements
  if (first) await db.batch([first, ...rest])

  return c.json({ lists_imported: newLists.length, assets_imported: newAssets.length })
})
