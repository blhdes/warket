import { z } from 'zod'
import { ApiError } from './errors'

/** Generous guard rails (API contract, section "Limits"). */
export const LIMITS = {
  name: 200,
  ticker: 20,
  tags: 30,
  tag: 40,
  summary: 250,
  description: 100_000,
  resources: 100,
  resourceTitle: 500,
  url: 2_000,
  listsPerVault: 500,
  assetsPerList: 2_000,
  bodyBytes: 2 * 1024 * 1024,
} as const

/** Counts characters the way the database does (code points), not UTF-16 units. */
const codePoints = (s: string) => [...s].length

const maxChars = (label: string, limit: number) =>
  z.string().refine(s => codePoints(s) <= limit, `${label} is longer than ${limit} characters`)

/** Trim, lowercase, drop empties and repeats, keep the first-seen order. */
const tidyTags = (tags: string[]) => [...new Set(tags.map(t => t.trim().toLowerCase()).filter(Boolean))]

const Name = z
  .string({ error: 'missing name' })
  .trim()
  .min(1, 'missing name')
  .refine(s => codePoints(s) <= LIMITS.name, `name is longer than ${LIMITS.name} characters`)

// Missing or null text fields become "" (a missing ticker is allowed, decision D3).
const Ticker = maxChars('ticker', LIMITS.ticker)
  .nullable()
  .transform(v => (v ?? '').trim().toUpperCase())
const Summary = maxChars('summary', LIMITS.summary).nullable().transform(v => v ?? '')
const Description = maxChars('description', LIMITS.description).nullable().transform(v => v ?? '')

const Tags = z
  .array(z.string())
  .transform(tidyTags)
  .refine(tags => tags.length <= LIMITS.tags, `more than ${LIMITS.tags} tags`)
  .refine(tags => tags.every(t => codePoints(t) <= LIMITS.tag), `a tag is longer than ${LIMITS.tag} characters`)

const ResourceSchema = z.object({
  title: maxChars('resource title', LIMITS.resourceTitle).default(''),
  url: maxChars('resource url', LIMITS.url),
  favicon: maxChars('resource favicon', LIMITS.url).default(''),
})
export type Resource = z.infer<typeof ResourceSchema>

const Resources = z.array(ResourceSchema).max(LIMITS.resources, `more than ${LIMITS.resources} resources`)

// "" and null both clear the image.
const ImageUrl = maxChars('image_url', LIMITS.url)
  .nullable()
  .transform(v => v?.trim() || null)

export const ListCreateSchema = z.object({ name: Name, tags: Tags.optional() })
export const ListPatchSchema = ListCreateSchema.partial()

export const AssetCreateSchema = z.object({
  name: Name,
  ticker: Ticker.optional(),
  summary: Summary.optional(),
  description: Description.optional(),
  tags: Tags.optional(),
  resources: Resources.optional(),
  image_url: ImageUrl.optional(),
})
export const AssetPatchSchema = AssetCreateSchema.partial()

export const ReorderSchema = z.object({
  ids: z.array(z.string()).max(LIMITS.assetsPerList, 'too many ids'),
})

const ImportAsset = AssetCreateSchema
const ImportList = z.object({
  name: Name,
  tags: Tags.optional(),
  assets: z.array(ImportAsset).max(LIMITS.assetsPerList, `more than ${LIMITS.assetsPerList} assets`).optional(),
})

/** The export file format (version 1), shared with both apps. */
export const VaultExportSchema = z.object({
  version: z.number({ error: 'missing version' }),
  app: z.string().optional(),
  exported_at: z.string().optional(),
  lists: z.array(ImportList, { error: 'missing lists' }).max(LIMITS.listsPerVault, `more than ${LIMITS.listsPerVault} lists`),
})
export type VaultImport = z.infer<typeof VaultExportSchema>

const PATH_LABELS: Record<string, string> = { lists: 'List', assets: 'asset', resources: 'resource' }

/** Turns the first problem into one plain sentence, e.g. "List 2, asset 3: summary is longer than 250 characters". */
export function describeIssue(error: z.ZodError): string {
  const issue = error.issues[0]
  if (!issue) return 'The request is not valid.'
  const where: string[] = []
  let field: string | undefined
  for (let i = 0; i < issue.path.length; i++) {
    const key = issue.path[i]
    const next = issue.path[i + 1]
    if (typeof key === 'string' && PATH_LABELS[key] && typeof next === 'number') {
      where.push(`${PATH_LABELS[key]} ${next + 1}`)
      i++
      continue
    }
    if (typeof key === 'string') field = key
  }
  const mentionsField = field !== undefined && issue.message.toLowerCase().includes(field.replace('_', ' '))
  const message = field && !mentionsField ? `${field}: ${issue.message}` : issue.message
  return where.length ? `${where.join(', ')}: ${message}` : message
}

export function parseInput<T extends z.ZodType>(schema: T, data: unknown): z.output<T> {
  const result = schema.safeParse(data)
  if (!result.success) throw new ApiError(400, 'invalid_input', describeIssue(result.error))
  return result.data
}
