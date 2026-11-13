import { describe, it, expect } from 'vitest'
import { generateSeedPhrase, hashSeedPhrase } from '@src/features/auth/seedPhrase'

// Two distinct 12-word phrases used as fixtures throughout the suite.
const PHRASE_A = 'abandon ability able about above absent absorb abstract absurd abuse access accident'
const PHRASE_B = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zone'

/** Build a space-joined phrase of n copies of "word". */
function nWords(n: number): string {
  return Array(n).fill('word').join(' ')
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

// ─── Fixed test vector (shared with iOS and the server) ──────────────────────

describe('hash recipe – fixed test vector', () => {
  // Public phrase. Never keep real data in this vault. iOS and server tests use the same
  // values, so a change here means the apps would open different vaults for the same words.
  // The share key for this vault is now made by the server and checked in server/test.
  const MESSY_PHRASE = '  Legal  Winner THANK year wave sausage worth useful legal winner thank yellow  '
  const VAULT_HASH = 'ecb0e7ba498c5920991f0b3483e91f7abafa9ecc6bd82a9a51494589592b1a8f'

  it('hashSeedPhrase gives the known vault hash', async () => {
    expect(await hashSeedPhrase(MESSY_PHRASE)).toBe(VAULT_HASH)
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
