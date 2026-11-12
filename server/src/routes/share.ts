import { eq, inArray } from 'drizzle-orm'
import { Hono } from 'hono'
import { deriveShareKey, requireOwner, sha256Hex } from '../auth'
import { getDb } from '../db/client'
import { assets, lists, shares } from '../db/schema'
import { nowIso } from '../serialize'
import type { AppEnv } from '../types'

export const shareRoutes = new Hono<AppEnv>()

shareRoutes.get('/share', async c => {
  const { vaultId } = requireOwner(c)
  const [share] = await getDb(c.env)
    .select({ vault_id: shares.vault_id })
    .from(shares)
    .where(eq(shares.vault_id, vaultId))
    .limit(1)
  return c.json({ shared: Boolean(share) })
})

/** Creates the share, or keeps the existing one. Only a fingerprint of the key is stored. */
shareRoutes.put('/share', async c => {
  const { vaultId, vaultHash } = requireOwner(c)
  const shareKey = await deriveShareKey(vaultHash)
  await getDb(c.env)
    .insert(shares)
    .values({ vault_id: vaultId, share_id: await sha256Hex(shareKey), created_at: nowIso() })
    .onConflictDoNothing({ target: shares.vault_id })
  return c.json({ share_key: shareKey })
})

shareRoutes.delete('/share', async c => {
  const { vaultId } = requireOwner(c)
  await getDb(c.env).delete(shares).where(eq(shares.vault_id, vaultId))
  return c.body(null, 204)
})

/** Removes every list, asset and the share of this vault, all or nothing. */
shareRoutes.delete('/vault', async c => {
  const { vaultId } = requireOwner(c)
  const db = getDb(c.env)
  await db.batch([
    db.delete(assets).where(inArray(assets.list_id, db.select({ id: lists.id }).from(lists).where(eq(lists.vault_id, vaultId)))),
    db.delete(lists).where(eq(lists.vault_id, vaultId)),
    db.delete(shares).where(eq(shares.vault_id, vaultId)),
  ])
  return c.body(null, 204)
})
