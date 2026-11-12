import { sql } from 'drizzle-orm'
import { index, integer, sqliteTable, text } from 'drizzle-orm/sqlite-core'
import type { Resource } from '../validation'

// Column keys are snake_case so rows already use the API's field names.
// `vault_id` is SHA-256 of the vault hash: the hash itself is never stored.

export const lists = sqliteTable(
  'lists',
  {
    id: text('id').primaryKey(),
    vault_id: text('vault_id').notNull(),
    name: text('name').notNull(),
    tags: text('tags', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
    position: integer('position').notNull().default(0),
    created_at: text('created_at').notNull(),
    updated_at: text('updated_at').notNull(),
  },
  table => [index('lists_vault_position').on(table.vault_id, table.position)],
)

export const assets = sqliteTable(
  'assets',
  {
    id: text('id').primaryKey(),
    list_id: text('list_id')
      .notNull()
      .references(() => lists.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    ticker: text('ticker').notNull().default(''),
    summary: text('summary').notNull().default(''),
    description: text('description').notNull().default(''),
    tags: text('tags', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
    resources: text('resources', { mode: 'json' }).$type<Resource[]>().notNull().default(sql`'[]'`),
    image_url: text('image_url'),
    position: integer('position').notNull().default(0),
    created_at: text('created_at').notNull(),
  },
  table => [index('assets_list_position').on(table.list_id, table.position)],
)

export const shares = sqliteTable('shares', {
  vault_id: text('vault_id').primaryKey(),
  share_id: text('share_id').notNull().unique(),
  created_at: text('created_at').notNull(),
})

export type ListRow = typeof lists.$inferSelect
export type AssetRow = typeof assets.$inferSelect
