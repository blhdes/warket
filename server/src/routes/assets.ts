import { and, asc, count, eq, inArray, sql } from 'drizzle-orm'
import { Hono } from 'hono'
import { requireOwner } from '../auth'
import { type Db, getDb } from '../db/client'
import { assets, lists } from '../db/schema'
import { ApiError, notFound } from '../errors'
import { assertSameIds, readJson } from '../http'
import { nowIso, toAsset } from '../serialize'
import type { AppEnv } from '../types'
import { AssetCreateSchema, AssetPatchSchema, LIMITS, ReorderSchema, parseInput } from '../validation'

export const assetRoutes = new Hono<AppEnv>()

/** Ids of every list in the vault, as a subquery (one bound value, whatever the vault size). */
const vaultListIds = (db: Db, vaultId: string) =>
  db.select({ id: lists.id }).from(lists).where(eq(lists.vault_id, vaultId))

async function requireList(db: Db, listId: string, vaultId: string) {
  const [list] = await db
    .select({ id: lists.id })
    .from(lists)
    .where(and(eq(lists.id, listId), eq(lists.vault_id, vaultId)))
    .limit(1)
  if (!list) throw notFound('List')
}

const assetOrder = [asc(assets.position), asc(assets.created_at), asc(assets.id)]

assetRoutes.get('/lists/:listId/assets', async c => {
  const { vaultId } = c.get('access')
  const listId = c.req.param('listId')
  const db = getDb(c.env)
  await requireList(db, listId, vaultId)

  const rows = await db.select().from(assets).where(eq(assets.list_id, listId)).orderBy(...assetOrder)
  return c.json(rows.map(toAsset))
})

assetRoutes.post('/lists/:listId/assets', async c => {
  const { vaultId } = requireOwner(c)
  const listId = c.req.param('listId')
  const input = parseInput(AssetCreateSchema, await readJson(c))
  const db = getDb(c.env)
  await requireList(db, listId, vaultId)

  const [{ total }] = await db.select({ total: count() }).from(assets).where(eq(assets.list_id, listId))
  if (total >= LIMITS.assetsPerList) {
    throw new ApiError(400, 'too_many_assets', `A list can hold at most ${LIMITS.assetsPerList} assets.`)
  }

  const [row] = await db
    .insert(assets)
    .values({
      id: crypto.randomUUID(),
      list_id: listId,
      name: input.name,
      ticker: input.ticker ?? '',
      summary: input.summary ?? '',
      description: input.description ?? '',
      tags: input.tags ?? [],
      resources: input.resources ?? [],
      image_url: input.image_url ?? null,
      // Placed last, computed inside the same statement.
      position: sql`(select coalesce(max(${assets.position}), -1) + 1 from ${assets} where ${assets.list_id} = ${listId})`,
      created_at: nowIso(),
    })
    .returning()
  return c.json(toAsset(row), 201)
})

assetRoutes.put('/lists/:listId/assets/order', async c => {
  const { vaultId } = requireOwner(c)
  const listId = c.req.param('listId')
  const { ids } = parseInput(ReorderSchema, await readJson(c))
  const db = getDb(c.env)
  await requireList(db, listId, vaultId)

  const current = await db.select({ id: assets.id }).from(assets).where(eq(assets.list_id, listId))
  assertSameIds(current.map(r => r.id), ids)

  const [first, ...rest] = ids.map((id, position) =>
    db.update(assets).set({ position }).where(and(eq(assets.id, id), eq(assets.list_id, listId))),
  )
  if (first) await db.batch([first, ...rest])
  return c.body(null, 204)
})

assetRoutes.get('/assets/index', async c => {
  const { vaultId } = c.get('access')
  const db = getDb(c.env)
  const rows = await db
    .select({ list_id: assets.list_id, name: assets.name, ticker: assets.ticker })
    .from(assets)
    .where(inArray(assets.list_id, vaultListIds(db, vaultId)))
  return c.json(rows)
})

assetRoutes.patch('/assets/:id', async c => {
  const { vaultId } = requireOwner(c)
  const input = parseInput(AssetPatchSchema, await readJson(c))
  const db = getDb(c.env)
  const owned = and(eq(assets.id, c.req.param('id')), inArray(assets.list_id, vaultListIds(db, vaultId)))

  // Only the fields that were sent change: Drizzle skips undefined values. "" or null image_url clears it.
  const nothingSent = Object.values(input).every(value => value === undefined)
  const [row] = nothingSent
    ? await db.select().from(assets).where(owned).limit(1)
    : await db.update(assets).set(input).where(owned).returning()
  if (!row) throw notFound('Asset')
  return c.json(toAsset(row))
})

assetRoutes.delete('/assets/:id', async c => {
  const { vaultId } = requireOwner(c)
  const db = getDb(c.env)
  const deleted = await db
    .delete(assets)
    .where(and(eq(assets.id, c.req.param('id')), inArray(assets.list_id, vaultListIds(db, vaultId))))
    .returning({ id: assets.id })
  if (deleted.length === 0) throw notFound('Asset')
  return c.body(null, 204)
})
