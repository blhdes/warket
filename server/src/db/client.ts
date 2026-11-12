import { drizzle } from 'drizzle-orm/d1'

export const getDb = (env: Env) => drizzle(env.DB)
export type Db = ReturnType<typeof getDb>
