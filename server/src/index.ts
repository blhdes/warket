import { Hono } from 'hono'
import { bodyLimit } from 'hono/body-limit'
import { cors } from 'hono/cors'
import { resolveAccess } from './auth'
import { errorBody, handleError } from './errors'
import { rateLimit } from './http'
import { assetRoutes } from './routes/assets'
import { listRoutes } from './routes/lists'
import { shareRoutes } from './routes/share'
import { transferRoutes } from './routes/transfer'
import type { AppEnv } from './types'
import { LIMITS } from './validation'

const app = new Hono<AppEnv>()

app.use('*', async (c, next) => {
  await next()
  c.header('Cache-Control', 'no-store')
})

app.use(
  '/v1/*',
  cors({
    origin: (origin, c) => {
      const allowed = String(c.env.ALLOWED_ORIGINS ?? '').split(',').map((o: string) => o.trim())
      return allowed.includes(origin) ? origin : null
    },
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Authorization', 'Content-Type'],
    maxAge: 60 * 60 * 24,
  }),
)
app.use('/v1/*', rateLimit)
app.use(
  '/v1/*',
  bodyLimit({
    maxSize: LIMITS.bodyBytes,
    onError: c => c.json(errorBody('too_large', 'The request is larger than 2 MB.'), 413),
  }),
)
app.use('/v1/*', resolveAccess)

app.get('/v1/health', c => c.json({ ok: true }))
app.get('/v1/session', c => c.json({ mode: c.get('access').mode }))
app.route('/v1/lists', listRoutes)
app.route('/v1', assetRoutes)
app.route('/v1', transferRoutes)
app.route('/v1', shareRoutes)

app.notFound(c => c.json(errorBody('not_found', 'Not found.'), 404))
app.onError(handleError)

export default app
