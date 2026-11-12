import { describe, it, expect } from 'vitest'
import { generateSeedPhrase, hashSeedPhrase, deriveShareHash } from '@src/features/auth/seedPhrase'

// Two distinct 12-word phrases used as fixtures throughout the suite.
const PHRASE_A = 'abandon ability able about above absent absorb abstract absurd abuse access accident'
const PHRASE_B = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zone'

/** Build a space-joined phrase of n copies of "word". */
function nWords(n: number): string {
  return Array(n).fill('word').join(' ')
}

/** Independently compute SHA-256 of a string via the same WebCrypto API. */
async function sha256(input: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

// ─── hashSeedPhrase – output format ──────────────────────────────────────────

describe('hashSeedPhrase – output format', () => {
  it('returns a 64-character lowercase hex string', async () => {
    const hash = await hashSeedPhrase(PHRASE_A)
    expect(hash).toMatch(/^[0-9a-f]{64}$/)
  })
})

// ─── hashSeedPhrase – determinism ────────────────────────────────────────────

describe('hashSeedPhrase – determinism', () => {
  it('returns identical hashes across independent calls', async () => {
    const first = await hashSeedPhrase(PHRASE_A)
    const second = await hashSeedPhrase(PHRASE_A)
    expect(first).toBe(second)
  })

  it('produces distinct hashes for distinct phrases', async () => {
    const a = await hashSeedPhrase(PHRASE_A)
    const b = await hashSeedPhrase(PHRASE_B)
    expect(a).not.toBe(b)
  })
})

// ─── hashSeedPhrase – normalization ──────────────────────────────────────────

describe('hashSeedPhrase – normalization', () => {
  it('lowercases before hashing', async () => {
    const lower = await hashSeedPhrase(PHRASE_A)
    const upper = await hashSeedPhrase(PHRASE_A.toUpperCase())
    expect(upper).toBe(lower)
  })

  it('trims leading and trailing whitespace', async () => {
    const plain = await hashSeedPhrase(PHRASE_A)
    const padded = await hashSeedPhrase(`   ${PHRASE_A}   `)
    expect(padded).toBe(plain)
  })

  it('collapses multiple internal spaces to one', async () => {
    const plain = await hashSeedPhrase(PHRASE_A)
    const spaced = await hashSeedPhrase(PHRASE_A.replace(/ /g, '   '))
    expect(spaced).toBe(plain)
  })

  it('treats tabs as word separators (same hash as spaces)', async () => {
    const plain = await hashSeedPhrase(PHRASE_A)
    const tabbed = await hashSeedPhrase(PHRASE_A.replace(/ /g, '\t'))
    expect(tabbed).toBe(plain)
  })

  it('treats newlines as word separators (same hash as spaces)', async () => {
    const plain = await hashSeedPhrase(PHRASE_A)
    const multiline = await hashSeedPhrase(PHRASE_A.replace(/ /g, '\n'))
    expect(multiline).toBe(plain)
  })
})

// ─── hashSeedPhrase – validation ─────────────────────────────────────────────

describe('hashSeedPhrase – validation', () => {
  it('rejects an 11-word phrase with an Error naming "12 words"', async () => {
    await expect(hashSeedPhrase(nWords(11))).rejects.toThrow('12 words')
  })

  it('rejects a 13-word phrase with an Error naming "12 words"', async () => {
    await expect(hashSeedPhrase(nWords(13))).rejects.toThrow('12 words')
  })

  it('rejects an empty string', async () => {
    await expect(hashSeedPhrase('')).rejects.toThrow('12 words')
  })

  it('accepts exactly 12 words', async () => {
    await expect(hashSeedPhrase(nWords(12))).resolves.toMatch(/^[0-9a-f]{64}$/)
  })

  it('error is an instance of Error', async () => {
    await expect(hashSeedPhrase(nWords(11))).rejects.toBeInstanceOf(Error)
  })
})

// ─── deriveShareHash – determinism ───────────────────────────────────────────

describe('deriveShareHash – determinism', () => {
  it('is deterministic for the same vault hash', async () => {
    const vaultHash = await hashSeedPhrase(PHRASE_A)
    const a = await deriveShareHash(vaultHash)
    const b = await deriveShareHash(vaultHash)
    expect(a).toBe(b)
  })

  it('produces different share hashes for different vault hashes', async () => {
    const v1 = await hashSeedPhrase(PHRASE_A)
    const v2 = await hashSeedPhrase(PHRASE_B)
    const s1 = await deriveShareHash(v1)
    const s2 = await deriveShareHash(v2)
    expect(s1).not.toBe(s2)
  })
})

// ─── deriveShareHash – domain separation ─────────────────────────────────────

describe('deriveShareHash – domain separation', () => {
  it('share hash is never equal to the vault hash (no hash reuse)', async () => {
    const vaultHash = await hashSeedPhrase(PHRASE_A)
    const shareHash = await deriveShareHash(vaultHash)
    expect(shareHash).not.toBe(vaultHash)
  })

  it('preimage is exactly vaultHash + ":share" — verified against independent SHA-256', async () => {
    // This test locks in the separator format. If the suffix, its position, or the
    // encoding ever changes, this assertion catches the regression immediately.
    const vaultHash = 'a'.repeat(64) // synthetic 64-char hex string (no real phrase needed)
    const expected = await sha256(vaultHash + ':share')
    expect(await deriveShareHash(vaultHash)).toBe(expected)
  })

  it('the colon separator cannot appear in a vault hash (hex-only)', async () => {
    // Vault hashes are SHA-256 outputs: strictly [0-9a-f]{64}. A colon is
    // structurally impossible, so the ":share" suffix is unambiguously delimited.
    const vaultHash = await hashSeedPhrase(PHRASE_A)
    expect(vaultHash).toMatch(/^[0-9a-f]{64}$/)
    expect(vaultHash).not.toContain(':')
  })

  it('applying deriveShareHash to a share hash gives a distinct result (cross-protocol safety)', async () => {
    // An attacker who holds a shareHash and uses it as a vaultHash cannot produce
    // a second shareHash that collides with the first. This would require SHA-256
    // to have a fixed point under the transform x → SHA-256(x + ":share").
    const vaultHash = await hashSeedPhrase(PHRASE_A)
    const shareHash = await deriveShareHash(vaultHash)
    const doubleShare = await deriveShareHash(shareHash)
    expect(doubleShare).not.toBe(shareHash)
  })
})

// ─── Fixed test vector (shared with iOS) ─────────────────────────────────────

describe('hash recipe – fixed test vector', () => {
  // Public phrase. Never keep real data in this vault. iOS tests use the same values,
  // so a change here means both apps would open different vaults for the same words.
  const MESSY_PHRASE = '  Legal  Winner THANK year wave sausage worth useful legal winner thank yellow  '
  const VAULT_HASH = 'ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f'
  const SHARE_HASH = '4aedbd98322b258ec221d52e62bed851cd76131c7e9452e125eaeecd169c8e7f'

  it('hashSeedPhrase gives the known vault hash', async () => {
    expect(await hashSeedPhrase(MESSY_PHRASE)).toBe(VAULT_HASH)
  })

  it('deriveShareHash gives the known share hash', async () => {
    expect(await deriveShareHash(VAULT_HASH)).toBe(SHARE_HASH)
  })
})

// ─── generateSeedPhrase ───────────────────────────────────────────────────────

describe('generateSeedPhrase', () => {
  it('returns exactly 12 words', () => {
    expect(generateSeedPhrase().split(' ')).toHaveLength(12)
  })

  it('produces output that hashSeedPhrase accepts without error', async () => {
    const phrase = generateSeedPhrase()
    await expect(hashSeedPhrase(phrase)).resolves.toMatch(/^[0-9a-f]{64}$/)
  })

  it('generates unique phrases across calls (probabilistic)', () => {
    const phrases = Array.from({ length: 10 }, generateSeedPhrase)
    expect(new Set(phrases).size).toBeGreaterThan(1)
  })
})
