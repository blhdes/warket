import { eq } from 'drizzle-orm'
import type { Context, MiddlewareHandler } from 'hono'
import { getDb } from './db/client'
import { shares } from './db/schema'
import { ApiError } from './errors'
import type { AppEnv, OwnerAccess } from './types'

const HEX_64 = /^[0-9a-f]{64}$/

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('')
}

/** The read-only key for a vault. Same recipe as both apps, so old share keys keep working. */
export const deriveShareKey = (vaultHash: string) => sha256Hex(`${vaultHash}:share`)

/**
 * Reads `Authorization: Bearer <vault hash>` (owner) or `Authorization: Share <share key>` (viewer).
 * The vault hash is only kept in memory for this request: never stored, never logged.
 */
export const resolveAccess: MiddlewareHandler<AppEnv> = async (c, next) => {
  if (c.req.path === '/v1/health') return next()

  const header = c.req.header('Authorization') ?? ''
  const [scheme = '', value = '', ...rest] = header.trim().split(/\s+/)
  if (rest.length > 0 || !HEX_64.test(value)) {
    throw new ApiError(401, 'unauthorized', 'Missing or malformed Authorization header.')
  }

  switch (scheme.toLowerCase()) {
    case 'bearer':
      c.set('access', { mode: 'owner', vaultId: await sha256Hex(value), vaultHash: value })
      return next()

    case 'share': {
      const shareId = await sha256Hex(value)
      const [share] = await getDb(c.env)
        .select({ vault_id: shares.vault_id })
        .from(shares)
        .where(eq(shares.share_id, shareId))
        .limit(1)
      if (!share) throw new ApiError(404, 'share_not_found', 'Invalid or expired share key.')
      if (c.req.method !== 'GET') {
        throw new ApiError(403, 'read_only', 'A shared vault is read-only.')
      }
      c.set('access', { mode: 'shared', vaultId: share.vault_id })
      return next()
    }

    default:
      throw new ApiError(401, 'unauthorized', 'Missing or malformed Authorization header.')
  }
}

/** For routes only the owner may use, including GET ones. */
export function requireOwner(c: Context<AppEnv>): OwnerAccess {
  const access = c.get('access')
  if (access.mode !== 'owner') throw new ApiError(403, 'read_only', 'A shared vault is read-only.')
  return access
}
