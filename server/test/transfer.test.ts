import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import seed from '../../warket-seed-data.json'
import { sha256Hex } from '../src/auth'
import { type ErrorOut, type ListOut, client, owner, randomHash } from './helpers'

type ImportResult = { lists_imported: number; assets_imported: number }
type ExportFile = {
  version: number
  app: string
  exported_at: string
  lists: { name: string; tags: string[]; assets: Record<string, unknown>[] }[]
}

const newVault = () => {
  const hash = randomHash()
  return { hash, api: client(owner(hash)) }
}

const totals = async (api: ReturnType<typeof client>) => {
  const lists = (await api.get<ListOut[]>('/v1/lists')).json
  return { lists: lists.length, assets: lists.reduce((sum, l) => sum + (l.asset_count ?? 0), 0) }
}

describe('import', () => {
  it('imports the seed file: 11 lists and 62 assets', async () => {
    const { api } = newVault()
    const res = await api.post<ImportResult>('/v1/import', seed)
    expect(res.status).toBe(200)
    expect(res.json).toEqual({ lists_imported: 11, assets_imported: 62 })
    expect(await totals(api)).toEqual({ lists: 11, assets: 62 })
  })

  it('merges same-named lists when importing twice: 11 lists and 124 assets', async () => {
    const { api } = newVault()
    await api.post('/v1/import', seed)
    const second = await api.post<ImportResult>('/v1/import', seed)
    expect(second.json).toEqual({ lists_imported: 0, assets_imported: 62 })
    expect(await totals(api)).toEqual({ lists: 11, assets: 124 })
  })

  it('merges lists with the same name inside one file, ignoring case', async () => {
    const { api } = newVault()
    const file = {
      version: 1,
      lists: [
        { name: 'Tech', assets: [{ name: 'Apple' }] },
        { name: 'tech ', assets: [{ name: 'Nvidia', ticker: '' }] },
      ],
    }
    expect((await api.post<ImportResult>('/v1/import', file)).json).toEqual({ lists_imported: 1, assets_imported: 2 })
    expect(await totals(api)).toEqual({ lists: 1, assets: 2 })
  })

  it('writes nothing when one asset is bad, and says where', async () => {
    const { api } = newVault()
    await api.post('/v1/lists', { name: 'Existing' })
    const file = structuredClone(seed)
    file.lists[1].assets[2].summary = 'x'.repeat(251)

    const res = await api.post<ErrorOut>('/v1/import', file)
    expect(res.status).toBe(400)
    expect(res.json.error.message).toBe('List 2, asset 3: summary is longer than 250 characters')
    expect(await totals(api)).toEqual({ lists: 1, assets: 0 })
  })

  it.each([
    ['a null asset', { version: 1, lists: [{ name: 'L', assets: [null] }] }],
    ['a missing lists field', { version: 1 }],
    ['a list without a name', { version: 1, lists: [{ assets: [] }] }],
  ])('rejects %s with 400, not a crash', async (_label, file) => {
    const { api } = newVault()
    const res = await api.post<ErrorOut>('/v1/import', file)
    expect(res.status).toBe(400)
    expect(res.json.error.code).toBe('invalid_input')
  })
})

describe('export', () => {
  it('uses the shared file format and survives a round trip', async () => {
    const { api } = newVault()
    await api.post('/v1/import', seed)
    const first = (await api.get<ExportFile>('/v1/export')).json
    expect(first.version).toBe(1)
    expect(first.app).toBe('warket')
    expect(first.lists).toHaveLength(11)
    // image_url is left out when empty, as both apps do today.
    expect(first.lists.flatMap(l => l.assets).some(a => 'image_url' in a)).toBe(false)

    const copy = newVault().api
    await copy.post('/v1/import', first)
    const second = (await copy.get<ExportFile>('/v1/export')).json
    expect(second.lists).toEqual(first.lists)
  })

  it('exports only the chosen lists', async () => {
    const { api } = newVault()
    await api.post('/v1/import', seed)
    const lists = (await api.get<ListOut[]>('/v1/lists')).json
    const chosen = [lists[0], lists[2]]
    const file = (await api.get<ExportFile>(`/v1/export?lists=${chosen.map(l => l.id).join(',')}`)).json
    expect(file.lists.map(l => l.name)).toEqual(chosen.map(l => l.name))
  })
})

describe('delete vault', () => {
  it('leaves nothing behind', async () => {
    const { hash, api } = newVault()
    await api.post('/v1/import', seed)
    await api.put('/v1/share')
    const listIds = (await api.get<ListOut[]>('/v1/lists')).json.map(l => l.id)
    expect((await api.del('/v1/vault')).status).toBe(204)
    expect(await totals(api)).toEqual({ lists: 0, assets: 0 })

    // Check the database itself, including assets whose lists are gone.
    const vaultId = await sha256Hex(hash)
    const count = (sql: string, ...values: string[]) => env.DB.prepare(sql).bind(...values).first<number>('n')
    expect(await count('select count(*) as n from lists where vault_id = ?', vaultId)).toBe(0)
    expect(await count('select count(*) as n from shares where vault_id = ?', vaultId)).toBe(0)
    const placeholders = listIds.map(() => '?').join(',')
    expect(await count(`select count(*) as n from assets where list_id in (${placeholders})`, ...listIds)).toBe(0)
  })
})
