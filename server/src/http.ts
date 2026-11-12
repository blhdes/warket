import type { Context, MiddlewareHandler } from 'hono'
import { ApiError } from './errors'
import type { AppEnv } from './types'

export async function readJson(c: Context<AppEnv>): Promise<unknown> {
  try {
    return await c.req.json()
  } catch (e) {
    throw new ApiError(400, 'invalid_json', `The request body is not valid JSON (${e instanceof Error ? e.name : 'parse error'}).`)
  }
}

/** All ids, each once, and nothing else: a reorder must name exactly the current items. */
export function assertSameIds(current: string[], requested: string[]) {
  const wanted = new Set(requested)
  const same =
    wanted.size === requested.length &&
    wanted.size === current.length &&
    current.every(id => wanted.has(id))
  if (!same) throw new ApiError(400, 'invalid_order', 'The new order must list every item exactly once.')
}

/**
 * Flood protection per visitor address. Cloudflare always sets `cf-connecting-ip` in production;
 * it is only missing in local tests, where the check is skipped.
 */
export const rateLimit: MiddlewareHandler<AppEnv> = async (c, next) => {
  const ip = c.req.header('cf-connecting-ip')
  if (!ip) return next()

  const limiters = [c.env.API_LIMITER]
  if (c.req.method !== 'GET') limiters.push(c.env.WRITE_LIMITER)
  for (const limiter of limiters) {
    const { success } = await limiter.limit({ key: ip })
    if (!success) throw new ApiError(429, 'rate_limited', 'Too many requests. Please wait a minute and try again.')
  }
  return next()
}
