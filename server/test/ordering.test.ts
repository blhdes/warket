import { describe, expect, it } from 'vitest'
import { type AssetOut, type ErrorOut, type ListOut, client, owner, randomHash } from './helpers'

const newVault = () => client(owner(randomHash()))

describe('list positions', () => {
  it('stay unique and increasing after create, delete, create', async () => {
    const api = newVault()
    const a = (await api.post<ListOut>('/v1/lists', { name: 'A' })).json
    const b = (await api.post<ListOut>('/v1/lists', { name: 'B' })).json
    const c = (await api.post<ListOut>('/v1/lists', { name: 'C' })).json
    expect([a.position, b.position, c.position]).toEqual([0, 1, 2])

    expect((await api.del(`/v1/lists/${b.id}`)).status).toBe(204)
    const d = (await api.post<ListOut>('/v1/lists', { name: 'D' })).json
    expect(d.position).toBe(3)

    const lists = (await api.get<ListOut[]>('/v1/lists')).json
    expect(lists.map(l => l.name)).toEqual(['A', 'C', 'D'])
    expect(lists.map(l => l.position)).toEqual([0, 2, 3])
  })

  it('reorder in one request, and a wrong id set changes nothing', async () => {
    const api = newVault()
    const ids: string[] = []
    for (const name of ['A', 'B', 'C']) ids.push((await api.post<ListOut>('/v1/lists', { name })).json.id)
    const [a, b, c] = ids

    expect((await api.put('/v1/lists/order', { ids: [c, a, b] })).status).toBe(204)
    expect((await api.get<ListOut[]>('/v1/lists')).json.map(l => l.name)).toEqual(['C', 'A', 'B'])

    for (const wrong of [[a, b], [a, b, c, randomHash()], [a, a, b], [a, b, randomHash()]]) {
      const res = await api.put<ErrorOut>('/v1/lists/order', { ids: wrong })
      expect(res.status).toBe(400)
      expect(res.json.error.code).toBe('invalid_order')
    }
    expect((await api.get<ListOut[]>('/v1/lists')).json.map(l => l.name)).toEqual(['C', 'A', 'B'])
  })

  it('count the assets in each list, and deleting a list removes its assets', async () => {
    const api = newVault()
    const list = (await api.post<ListOut>('/v1/lists', { name: 'Tech' })).json
    await api.post(`/v1/lists/${list.id}/assets`, { name: 'Apple' })
    await api.post(`/v1/lists/${list.id}/assets`, { name: 'Nvidia' })
    expect((await api.get<ListOut[]>('/v1/lists')).json[0].asset_count).toBe(2)

    await api.del(`/v1/lists/${list.id}`)
    expect((await api.get('/v1/assets/index')).json).toEqual([])
  })
})

describe('asset positions', () => {
  it('put new assets last and reorder in one request', async () => {
    const api = newVault()
    const list = (await api.post<ListOut>('/v1/lists', { name: 'L' })).json
    const path = `/v1/lists/${list.id}/assets`
    const x = (await api.post<AssetOut>(path, { name: 'X' })).json
    const y = (await api.post<AssetOut>(path, { name: 'Y' })).json
    await api.del(`/v1/assets/${x.id}`)
    const z = (await api.post<AssetOut>(path, { name: 'Z' })).json
    expect([y.position, z.position]).toEqual([1, 2])

    expect((await api.put(`${path}/order`, { ids: [z.id, y.id] })).status).toBe(204)
    expect((await api.get<AssetOut[]>(path)).json.map(a => a.name)).toEqual(['Z', 'Y'])

    const wrong = await api.put(`${path}/order`, { ids: [z.id] })
    expect(wrong.status).toBe(400)
    expect((await api.get<AssetOut[]>(path)).json.map(a => a.name)).toEqual(['Z', 'Y'])
  })
})

describe('input tidying (same rules for both apps)', () => {
  it('trims names and lowercases and de-duplicates tags', async () => {
    const api = newVault()
    const list = (await api.post<ListOut>('/v1/lists', { name: '  Tech  ', tags: [' AI', 'ai', 'Chips', ''] })).json
    expect(list.name).toBe('Tech')
    expect(list.tags).toEqual(['ai', 'chips'])

    const asset = (await api.post<AssetOut>(`/v1/lists/${list.id}/assets`, { name: 'Apple', tags: ['Big', 'BIG'] })).json
    expect(asset.tags).toEqual(['big'])
  })

  it('uppercases tickers and accepts an empty or missing ticker', async () => {
    const api = newVault()
    const list = (await api.post<ListOut>('/v1/lists', { name: 'L' })).json
    const path = `/v1/lists/${list.id}/assets`
    expect((await api.post<AssetOut>(path, { name: 'A', ticker: ' aapl ' })).json.ticker).toBe('AAPL')
    expect((await api.post<AssetOut>(path, { name: 'B', ticker: '' })).json.ticker).toBe('')
    const missing = await api.post<AssetOut>(path, { name: 'C' })
    expect(missing.status).toBe(201)
    expect(missing.json.ticker).toBe('')
  })

  it('rejects a missing name and a summary over 250 characters, counted like the database', async () => {
    const api = newVault()
    expect((await api.post<ErrorOut>('/v1/lists', { name: '   ' })).json.error.message).toBe('missing name')

    const list = (await api.post<ListOut>('/v1/lists', { name: 'L' })).json
    const path = `/v1/lists/${list.id}/assets`
    const tooLong = await api.post<ErrorOut>(path, { name: 'A', summary: 'x'.repeat(251) })
    expect(tooLong.status).toBe(400)
    expect(tooLong.json.error.message).toBe('summary is longer than 250 characters')

    // 250 emoji are 500 UTF-16 units but 250 characters for the database: accepted.
    expect((await api.post(path, { name: 'B', summary: '📈'.repeat(250) })).status).toBe(201)
  })

  it('patches only the fields sent, and "" or null clears the image', async () => {
    const api = newVault()
    const list = (await api.post<ListOut>('/v1/lists', { name: 'L' })).json
    const asset = (
      await api.post<AssetOut>(`/v1/lists/${list.id}/assets`, {
        name: 'Apple',
        ticker: 'AAPL',
        image_url: 'https://example.com/logo.png',
      })
    ).json
    expect(asset.image_url).toBe('https://example.com/logo.png')

    const renamed = (await api.patch<AssetOut>(`/v1/assets/${asset.id}`, { name: 'Apple Inc.' })).json
    expect(renamed.ticker).toBe('AAPL')
    expect(renamed.image_url).toBe('https://example.com/logo.png')

    expect((await api.patch<AssetOut>(`/v1/assets/${asset.id}`, { image_url: '' })).json.image_url).toBeNull()
    await api.patch(`/v1/assets/${asset.id}`, { image_url: 'https://example.com/b.png' })
    expect((await api.patch<AssetOut>(`/v1/assets/${asset.id}`, { image_url: null })).json.image_url).toBeNull()

    const unchanged = await api.patch<AssetOut>(`/v1/assets/${asset.id}`, {})
    expect(unchanged.status).toBe(200)
    expect(unchanged.json.name).toBe('Apple Inc.')
  })
})
