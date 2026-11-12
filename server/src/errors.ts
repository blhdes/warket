import type { ErrorHandler } from 'hono'
import { HTTPException } from 'hono/http-exception'
import type { ContentfulStatusCode } from 'hono/utils/http-status'
import type { AppEnv } from './types'

/** An error whose message is safe and useful to show to the user. */
export class ApiError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    readonly code: string,
    message: string,
  ) {
    super(message)
  }
}

export const errorBody = (code: string, message: string) => ({ error: { code, message } })

export const notFound = (what: string) => new ApiError(404, 'not_found', `${what} not found.`)

export const handleError: ErrorHandler<AppEnv> = (err, c) => {
  if (err instanceof ApiError) return c.json(errorBody(err.code, err.message), err.status)
  if (err instanceof HTTPException) {
    return c.json(errorBody('http_error', err.message || 'Request failed.'), err.status)
  }
  // Log the error only, never the request or its headers: they carry the vault key.
  console.error('Unhandled server error:', err instanceof Error ? (err.stack ?? err.message) : String(err))
  return c.json(errorBody('internal', 'Something went wrong on the server. Please try again.'), 500)
}
