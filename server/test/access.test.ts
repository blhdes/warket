import { describe, expect, it } from 'vitest'
import { sha256Hex } from '../src/auth'
import {
  type AssetOut,
  type ErrorOut,
  KNOWN_SHARE_KEY,
  KNOWN_VAULT_HASH,
  type ListOut,
  call,
  client,
  owner,
  randomHash,
  viewer,
} from './helpers'

/** A vault with one list holding one asset, shared. Returns everything a test needs. */
async function sharedVault() {
  const hash = randomHash()
  const api = client(owner(hash))
  const list = (await api.post<ListOut>('/v1/lists', { name: 'Tech' })).json
  const asset = (await api.post<AssetOut>(`/v1/lists/${list.id}/assets`, { name: 'Apple', ticker: 'aapl' })).json
  const { share_key } = (await api.put<{ share_key: string }>('/v1/share')).json
  return { hash, api, list, asset, shareKey: share_key, guest: client(viewer(share_key)) }
}

describe('health', () => {
  it('answers without any header', async () => {
    const res = await call('GET', '/v1/health')
    expect(res.status).toBe(200)
    expect(res.json).toEqual({ ok: true })
  })
})

describe('who is calling', () => {
  const hex = randomHash()
  it.each([
    ['no header', undefined],
    ['a short value', 'Bearer abc123'],
    ['uppercase hex', `Bearer ${hex.toUpperCase()}`],
    ['an unknown scheme', `Basic ${hex}`],
    ['extra words', `Bearer ${hex} extra`],
  ])('gives 401 for %s', async (_label, auth) => {
    const res = await client(auth).get<ErrorOut>('/v1/lists')
    expect(res.status).toBe(401)
    expect(res.json.error.code).toBe('unauthorized')
  })

  it('reports the mode in /v1/session', async () => {
    const { api, guest } = await sharedVault()
    expect((await api.get('/v1/session')).json).toEqual({ mode: 'owner' })
    expect((await guest.get('/v1/session')).json).toEqual({ mode: 'shared' })
  })

  it('gives 404 for an unknown share key', async () => {
    const res = await client(viewer(randomHash())).get<ErrorOut>('/v1/session')
    expect(res.status).toBe(404)
    expect(res.json.error.code).toBe('share_not_found')
  })
})

describe('vault separation', () => {
  it('shows an owner only their own vault', async () => {
    const { list, asset } = await sharedVault()
    const stranger = client(owner(randomHash()))

    expect((await stranger.get('/v1/lists')).json).toEqual([])
    expect((await stranger.get('/v1/assets/index')).json).toEqual([])
    expect((await stranger.get(`/v1/lists/${list.id}/assets`)).status).toBe(404)
    expect((await stranger.patch(`/v1/lists/${list.id}`, { name: 'Mine' })).status).toBe(404)
    expect((await stranger.del(`/v1/lists/${list.id}`)).status).toBe(404)
    expect((await stranger.post(`/v1/lists/${list.id}/assets`, { name: 'X' })).status).toBe(404)
    expect((await stranger.patch(`/v1/assets/${asset.id}`, { name: 'Mine' })).status).toBe(404)
    expect((await stranger.del(`/v1/assets/${asset.id}`)).status).toBe(404)
    expect((await stranger.get<{ lists: unknown[] }>('/v1/export')).json.lists).toEqual([])
  })
})

describe('sharing', () => {
  it('derives the same share key as both apps', async () => {
    const res = await client(owner(KNOWN_VAULT_HASH)).put<{ share_key: string }>('/v1/share')
    expect(res.status).toBe(200)
    expect(res.json.share_key).toBe(KNOWN_SHARE_KEY)
  })

  it('reports whether the vault is shared', async () => {
    const api = client(owner(randomHash()))
    expect((await api.get('/v1/share')).json).toEqual({ shared: false })
    await api.put('/v1/share')
    await api.put('/v1/share') // keeping an existing share is fine
    expect((await api.get('/v1/share')).json).toEqual({ shared: true })
  })

  it('lets a viewer read lists, assets, the index and the export', async () => {
    const { list, guest } = await sharedVault()

    const lists = await guest.get<ListOut[]>('/v1/lists')
    expect(lists.status).toBe(200)
    expect(lists.json.map(l => l.name)).toEqual(['Tech'])

    const assets = await guest.get<AssetOut[]>(`/v1/lists/${list.id}/assets`)
    expect(assets.json.map(a => a.ticker)).toEqual(['AAPL'])

    const index = await guest.get<{ ticker: string }[]>('/v1/assets/index')
    expect(index.json.map(a => a.ticker)).toEqual(['AAPL'])

    const exported = await guest.get<{ lists: { name: string }[] }>('/v1/export')
    expect(exported.json.lists.map(l => l.name)).toEqual(['Tech'])
  })

  it('gives a viewer 403 on every write route, and on GET /v1/share', async () => {
    const { list, asset, hash, guest } = await sharedVault()
    const writes: Promise<{ status: number }>[] = [
      guest.post('/v1/lists', { name: 'X' }),
      guest.patch(`/v1/lists/${list.id}`, { name: 'X' }),
      guest.del(`/v1/lists/${list.id}`),
      guest.put('/v1/lists/order', { ids: [list.id] }),
      guest.post(`/v1/lists/${list.id}/assets`, { name: 'X' }),
      guest.put(`/v1/lists/${list.id}/assets/order`, { ids: [asset.id] }),
      guest.patch(`/v1/assets/${asset.id}`, { name: 'X' }),
      guest.del(`/v1/assets/${asset.id}`),
      guest.post('/v1/import', { version: 1, lists: [] }),
      guest.put('/v1/share'),
      guest.del('/v1/share'),
      guest.del('/v1/vault'),
      guest.get('/v1/share'),
    ]
    for (const res of await Promise.all(writes)) expect(res.status).toBe(403)

    // Nothing changed.
    const lists = await client(owner(hash)).get<ListOut[]>('/v1/lists')
    expect(lists.json).toHaveLength(1)
    expect(lists.json[0].asset_count).toBe(1)
  })

  it('stops the key working after DELETE /v1/share', async () => {
    const { api, guest } = await sharedVault()
    expect((await api.del('/v1/share')).status).toBe(204)
    expect((await guest.get('/v1/lists')).status).toBe(404)
  })
})

describe('responses', () => {
  it('never contain vault_id, vault_hash, share_id or the vault key', async () => {
    const { hash, api, list, asset, guest } = await sharedVault()
    const replies = [
      await api.get('/v1/lists'),
      await api.get(`/v1/lists/${list.id}/assets`),
      await api.get('/v1/assets/index'),
      await api.get('/v1/export'),
      await api.get('/v1/session'),
      await api.patch(`/v1/lists/${list.id}`, { name: 'Renamed' }),
      await api.patch(`/v1/assets/${asset.id}`, { summary: 'x' }),
      await guest.get('/v1/lists'),
      await guest.get('/v1/export'),
    ]
    const vaultId = await sha256Hex(hash)
    for (const { text } of replies) {
      expect(text).not.toMatch(/vault_id|vault_hash|share_id/)
      expect(text).not.toContain(hash)
      expect(text).not.toContain(vaultId)
    }
  })

  it('are never cached', async () => {
    const api = client(owner(randomHash()))
    expect((await api.get('/v1/lists')).headers.get('Cache-Control')).toBe('no-store')
    expect((await call('GET', '/v1/health')).headers.get('Cache-Control')).toBe('no-store')
  })

  it('reject bodies over 2 MB with 413', async () => {
    const api = client(owner(randomHash()))
    const res = await api.post<ErrorOut>('/v1/lists', { name: 'x'.repeat(2 * 1024 * 1024 + 10) })
    expect(res.status).toBe(413)
  })

  it('reject a body that is not JSON with 400', async () => {
    const api = client(owner(randomHash()))
    const res = await api.post<ErrorOut>('/v1/lists', '{ not json')
    expect(res.status).toBe(400)
    expect(res.json.error.code).toBe('invalid_json')
  })
})
