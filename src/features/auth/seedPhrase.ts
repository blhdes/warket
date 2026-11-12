import { WORDLIST } from './wordlist'

/**
 * Generate a random 12-word seed phrase from the curated wordlist.
 */
export function generateSeedPhrase(): string {
  const words: string[] = []
  // Reject values above the largest multiple of the list size so every word is equally likely.
  const limit = Math.floor(0x100000000 / WORDLIST.length) * WORDLIST.length
  const buffer = new Uint32Array(1)
  while (words.length < 12) {
    crypto.getRandomValues(buffer)
    if (buffer[0] >= limit) continue
    words.push(WORDLIST[buffer[0] % WORDLIST.length])
  }
  return words.join(' ')
}

/**
 * Hash a seed phrase using SHA-256.
 * Normalizes input (lowercase, trim, collapse spaces) first.
 */
export async function hashSeedPhrase(phrase: string): Promise<string> {
  const normalized = phrase
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')

  const wordCount = normalized === '' ? 0 : normalized.split(' ').length
  if (wordCount !== 12) {
    throw new Error(`Seed phrase must be exactly 12 words, got ${wordCount}`)
  }

  const encoder = new TextEncoder()
  const data = encoder.encode(normalized)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)

  // Convert ArrayBuffer to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

  return hashHex
}

/**
 * Derive a deterministic share hash from a vault hash.
 * Uses domain separation (":share" suffix) so the share hash
 * cannot be reversed to the vault hash.
 */
export async function deriveShareHash(vaultHash: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(vaultHash + ':share')
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}
