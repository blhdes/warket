import { and, asc, count, eq, getTableColumns, inArray, sql } from 'drizzle-orm'
import { Hono } from 'hono'
import { requireOwner } from '../auth'
import { getDb } from '../db/client'
import { assets, lists } from '../db/schema'
import { ApiError, notFound } from '../errors'
import { assertSameIds, readJson } from '../http'
import { nowIso, toList, toListWithCount } from '../serialize'
import type { AppEnv } from '../types'
import { LIMITS, ListCreateSchema, ListPatchSchema, ReorderSchema, parseInput } from '../validation'

export const listRoutes = new Hono<AppEnv>()

listRoutes.get('/', async c => {
  const { vaultId } = c.get('access')
  const rows = await getDb(c.env)
    .select({ ...getTableColumns(lists), asset_count: count(assets.id) })
    .from(lists)
    .leftJoin(assets, eq(assets.list_id, lists.id))
    .where(eq(lists.vault_id, vaultId))
    .groupBy(lists.id)
    .orderBy(asc(lists.position), asc(lists.created_at), asc(lists.id))
  return c.json(rows.map(toListWithCount))
})

listRoutes.post('/', async c => {
  const { vaultId } = requireOwner(c)
  const input = parseInput(ListCreateSchema, await readJson(c))
  const db = getDb(c.env)

  const [{ total }] = await db.select({ total: count() }).from(lists).where(eq(lists.vault_id, vaultId))
  if (total >= LIMITS.listsPerVault) {
    throw new ApiError(400, 'too_many_lists', `A vault can hold at most ${LIMITS.listsPerVault} lists.`)
  }

  const now = nowIso()
  const [row] = await db
    .insert(lists)
    .values({
      id: crypto.randomUUID(),
      vault_id: vaultId,
      name: input.name,
      tags: input.tags ?? [],
      // Computed inside the same statement, so two quick creates can't pick the same spot.
      position: sql`(select coalesce(max(${lists.position}), -1) + 1 from ${lists} where ${lists.vault_id} = ${vaultId})`,
      created_at: now,
      updated_at: now,
    })
    .returning()
  return c.json(toList(row), 201)
})

listRoutes.put('/order', async c => {
  const { vaultId } = requireOwner(c)
  const { ids } = parseInput(ReorderSchema, await readJson(c))
  const db = getDb(c.env)

  const current = await db.select({ id: lists.id }).from(lists).where(eq(lists.vault_id, vaultId))
  assertSameIds(current.map(r => r.id), ids)

  const [first, ...rest] = ids.map((id, position) =>
    db.update(lists).set({ position }).where(and(eq(lists.id, id), eq(lists.vault_id, vaultId))),
  )
  if (first) await db.batch([first, ...rest])
  return c.body(null, 204)
})

listRoutes.patch('/:id', async c => {
  const { vaultId } = requireOwner(c)
  const input = parseInput(ListPatchSchema, await readJson(c))

  const [row] = await getDb(c.env)
    .update(lists)
    .set({
      ...(input.name !== undefined && { name: input.name }),
      ...(input.tags !== undefined && { tags: input.tags }),
      updated_at: nowIso(),
    })
    .where(and(eq(lists.id, c.req.param('id')), eq(lists.vault_id, vaultId)))
    .returning()
  if (!row) throw notFound('List')
  return c.json(toList(row))
})

listRoutes.delete('/:id', async c => {
  const { vaultId } = requireOwner(c)
  const id = c.req.param('id')
  const db = getDb(c.env)
  const owned = db.select({ id: lists.id }).from(lists).where(and(eq(lists.id, id), eq(lists.vault_id, vaultId)))

  // Assets are removed explicitly too, so this never depends on the foreign key setting.
  const [, deleted] = await db.batch([
    db.delete(assets).where(inArray(assets.list_id, owned)),
    db.delete(lists).where(and(eq(lists.id, id), eq(lists.vault_id, vaultId))).returning({ id: lists.id }),
  ])
  if (deleted.length === 0) throw notFound('List')
  return c.body(null, 204)
})
