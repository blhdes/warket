import type { Asset, ListWithCount, Resource, VaultList } from './types'
import type { VaultExport } from './vaultExport'

/** Who is calling: the owner (full access) or a viewer holding a share key (read only). */
export type Access =
  | { kind: 'owner'; vaultHash: string }
  | { kind: 'shared'; shareKey: string }

/** Fields the app may send when creating an asset. The server tidies them (trim, casing, limits). */
export interface AssetInput {
  name: string
  ticker?: string
  summary?: string
  description?: string
  tags?: string[]
  resources?: Resource[]
  /** `""` or `null` clears the image. */
  image_url?: string | null
}

/** An error answer from the server. `message` is safe to show to the user. */
export class ApiError extends Error {
  readonly status: number
  readonly code: string
  constructor(status: number, code: string, message: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

/** Reads `{ error: { code, message } }` from a failed answer, if it has that shape. */
const readServerError = (payload: unknown): { code?: string; message?: string } => {
  if (typeof payload !== 'object' || payload === null || !('error' in payload)) return {}
  const error = payload.error
  if (typeof error !== 'object' || error === null) return {}
  return {
    code: 'code' in error && typeof error.code === 'string' ? error.code : undefined,
    message: 'message' in error && typeof error.message === 'string' ? error.message : undefined,
  }
}

const request = async <T>(access: Access, method: string, path: string, body?: unknown): Promise<T> => {
  const apiUrl = import.meta.env.VITE_API_URL as string | undefined
  if (!apiUrl) throw new Error('Missing VITE_API_URL. Copy .env.example to .env and set the server address.')

  const authorization = access.kind === 'owner' ? `Bearer ${access.vaultHash}` : `Share ${access.shareKey}`
  let response: Response
  try {
    response = await fetch(`${apiUrl}${path}`, {
      method,
      headers: { Authorization: authorization, ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch (e) {
    console.error(`Network error on ${method} ${path}`, e)
    throw new ApiError(0, 'network', 'Could not reach the server. Check your connection and try again.')
  }

  if (response.status === 204) return undefined as T

  const text = await response.text()
  let payload: unknown = null
  if (text) {
    try {
      payload = JSON.parse(text)
    } catch (e) {
      console.error(`The answer to ${method} ${path} (status ${response.status}) is not JSON`, e)
    }
  }

  if (response.ok && payload !== null) return payload as T
  if (response.ok) throw new ApiError(response.status, 'invalid_response', 'The server sent an answer the app could not read.')

  const error = readServerError(payload)
  throw new ApiError(response.status, error.code ?? 'unknown', error.message ?? 'Something went wrong. Please try again.')
}

/** Every call the web app makes to the warket server. One object per vault or share key. */
export const createVaultApi = (access: Access) => {
  const call = <T,>(method: string, path: string, body?: unknown) => request<T>(access, method, path, body)
  return {
    readOnly: access.kind === 'shared',
    session: () => call<{ mode: 'owner' | 'shared' }>('GET', '/v1/session'),
    lists: () => call<ListWithCount[]>('GET', '/v1/lists'),
    createList: (input: { name: string; tags: string[] }) => call<VaultList>('POST', '/v1/lists', input),
    updateList: (id: string, patch: { name?: string; tags?: string[] }) => call<VaultList>('PATCH', `/v1/lists/${id}`, patch),
    deleteList: (id: string) => call<void>('DELETE', `/v1/lists/${id}`),
    reorderLists: (ids: string[]) => call<void>('PUT', '/v1/lists/order', { ids }),
    assets: (listId: string) => call<Asset[]>('GET', `/v1/lists/${listId}/assets`),
    assetIndex: () => call<{ list_id: string; name: string; ticker: string }[]>('GET', '/v1/assets/index'),
    createAsset: (listId: string, input: AssetInput) => call<Asset>('POST', `/v1/lists/${listId}/assets`, input),
    updateAsset: (id: string, patch: Partial<AssetInput>) => call<Asset>('PATCH', `/v1/assets/${id}`, patch),
    deleteAsset: (id: string) => call<void>('DELETE', `/v1/assets/${id}`),
    reorderAssets: (listId: string, ids: string[]) => call<void>('PUT', `/v1/lists/${listId}/assets/order`, { ids }),
    exportVault: (listIds?: string[]) =>
      call<VaultExport>('GET', `/v1/export${listIds?.length ? `?lists=${encodeURIComponent(listIds.join(','))}` : ''}`),
    importVault: (data: VaultExport) => call<{ lists_imported: number; assets_imported: number }>('POST', '/v1/import', data),
    shareStatus: () => call<{ shared: boolean }>('GET', '/v1/share'),
    share: () => call<{ share_key: string }>('PUT', '/v1/share'),
    unshare: () => call<void>('DELETE', '/v1/share'),
    deleteVault: () => call<void>('DELETE', '/v1/vault'),
  }
}

export type VaultApi = ReturnType<typeof createVaultApi>

/** The text to show the user for any caught error. */
export const errorMessage = (e: unknown, fallback = 'Something went wrong. Please try again.') =>
  e instanceof Error ? e.message : fallback
