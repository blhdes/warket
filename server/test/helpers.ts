import { exports } from 'cloudflare:workers'

/** Public test vector from the plan (section 2). Never real data. */
export const KNOWN_VAULT_HASH = 'ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f'
export const KNOWN_SHARE_KEY = '4aedbd98322b258ec221d52e62bed851cd76131c7e9452e125eaeecd169c8e7f'

export type ListOut = {
  id: string
  name: string
  tags: string[]
  position: number
  created_at: string
  updated_at: string
  asset_count?: number
}

export type AssetOut = {
  id: string
  list_id: string
  name: string
  ticker: string
  summary: string
  description: string
  tags: string[]
  resources: { title: string; url: string; favicon: string }[]
  image_url: string | null
  position: number
  created_at: string
}

export type ErrorOut = { error: { code: string; message: string } }

export type Reply<T> = { status: number; text: string; json: T; headers: Headers }

/** A fresh, made-up vault hash (64 lowercase hex characters), so each test has its own vault. */
export function randomHash(): string {
  return [...crypto.getRandomValues(new Uint8Array(32))].map(b => b.toString(16).padStart(2, '0')).join('')
}

export async function call<T = unknown>(
  method: string,
  path: string,
  options: { auth?: string; body?: unknown; headers?: Record<string, string> } = {},
): Promise<Reply<T>> {
  const headers: Record<string, string> = { ...options.headers }
  if (options.auth) headers.Authorization = options.auth
  let body: string | undefined
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = typeof options.body === 'string' ? options.body : JSON.stringify(options.body)
  }
  const res = await exports.default.fetch(`https://api.test${path}`, { method, headers, body })
  const text = await res.text()
  return { status: res.status, text, json: (text ? JSON.parse(text) : null) as T, headers: res.headers }
}

/** Calls as one caller: `client(owner(hash)).get('/v1/lists')`. */
export function client(auth?: string) {
  return {
    get: <T = unknown>(path: string) => call<T>('GET', path, { auth }),
    post: <T = unknown>(path: string, body?: unknown) => call<T>('POST', path, { auth, body }),
    put: <T = unknown>(path: string, body?: unknown) => call<T>('PUT', path, { auth, body }),
    patch: <T = unknown>(path: string, body?: unknown) => call<T>('PATCH', path, { auth, body }),
    del: <T = unknown>(path: string) => call<T>('DELETE', path, { auth }),
  }
}

export const owner = (vaultHash: string) => `Bearer ${vaultHash}`
export const viewer = (shareKey: string) => `Share ${shareKey}`
