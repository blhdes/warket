import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiError, createVaultApi } from '@src/lib/api'

const SERVER = 'http://api.test'
// Public test vector values (see seedPhrase.test.ts). Never real vault keys.
const VAULT_HASH = 'ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f'
const SHARE_KEY = '4aedbd98322b258ec221d52e62bed851cd76131c7e9452e125eaeecd169c8e7f'

const jsonResponse = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const fetchMock = vi.fn<typeof fetch>()

/** The headers of the n-th fetch call, as a Headers object. */
const sentHeaders = (call = 0) => new Headers(fetchMock.mock.calls[call]?.[1]?.headers)

beforeEach(() => {
  vi.stubEnv('VITE_API_URL', SERVER)
  vi.stubGlobal('fetch', fetchMock)
})

afterEach(() => {
  fetchMock.mockReset()
  vi.restoreAllMocks()
  vi.unstubAllEnvs()
  vi.unstubAllGlobals()
})

describe('createVaultApi – who is calling', () => {
  it('the owner sends the vault hash as a Bearer token', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, []))
    await createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).lists()

    expect(fetchMock.mock.calls[0]?.[0]).toBe(`${SERVER}/v1/lists`)
    expect(sentHeaders().get('Authorization')).toBe(`Bearer ${VAULT_HASH}`)
  })

  it('a viewer sends the share key with the Share scheme and is read only', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { mode: 'shared' }))
    const api = createVaultApi({ kind: 'shared', shareKey: SHARE_KEY })
    await api.session()

    expect(api.readOnly).toBe(true)
    expect(sentHeaders().get('Authorization')).toBe(`Share ${SHARE_KEY}`)
  })

  it('never puts the vault hash in the address', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { share_key: SHARE_KEY }))
    await createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).share()

    expect(String(fetchMock.mock.calls[0]?.[0])).not.toContain(VAULT_HASH)
  })
})

describe('createVaultApi – answers', () => {
  it('sends a JSON body with the right method', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(201, { id: 'l1', name: 'Tech' }))
    const created = await createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).createList({ name: 'Tech', tags: [] })

    const init = fetchMock.mock.calls[0]?.[1]
    expect(init?.method).toBe('POST')
    expect(sentHeaders().get('Content-Type')).toBe('application/json')
    expect(JSON.parse(String(init?.body))).toEqual({ name: 'Tech', tags: [] })
    expect(created).toEqual({ id: 'l1', name: 'Tech' })
  })

  it('a 204 answer resolves with nothing', async () => {
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }))
    await expect(createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).deleteList('l1')).resolves.toBeUndefined()
  })

  it("a 403 answer becomes an ApiError carrying the server's message", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(403, { error: { code: 'read_only', message: 'This vault is shared read only.' } }),
    )
    const result = createVaultApi({ kind: 'shared', shareKey: SHARE_KEY }).deleteList('l1')

    await expect(result).rejects.toBeInstanceOf(ApiError)
    await expect(result).rejects.toMatchObject({ status: 403, code: 'read_only', message: 'This vault is shared read only.' })
  })

  it('an error without the usual shape still gives a readable message', async () => {
    fetchMock.mockResolvedValueOnce(new Response('Bad gateway', { status: 502 }))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    await expect(createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).lists()).rejects.toMatchObject({
      status: 502,
      code: 'unknown',
      message: 'Something went wrong. Please try again.',
    })
  })

  it('a network failure becomes a friendly ApiError', async () => {
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    await expect(createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).lists()).rejects.toMatchObject({
      status: 0,
      code: 'network',
    })
  })

  it('without a server address it says how to fix it', async () => {
    vi.stubEnv('VITE_API_URL', '')
    await expect(createVaultApi({ kind: 'owner', vaultHash: VAULT_HASH }).lists()).rejects.toThrow('VITE_API_URL')
    expect(fetchMock).not.toHaveBeenCalled()
  })
})
