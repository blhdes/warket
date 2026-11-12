# warket API (v1)

The contract both apps use. Base path `/v1`. JSON in and out. Every response has `Cache-Control: no-store`.

## Who is calling

One header, never the URL:

- **Owner:** `Authorization: Bearer <vault hash>` (64 lowercase hex characters). Full access.
- **Viewer:** `Authorization: Share <share key>` (64 lowercase hex characters). Read only.

The server never stores the vault hash. It stores `vault_id = SHA-256(vault hash)` and
`share_id = SHA-256(share key)`. The share key itself is `SHA-256(vault hash + ":share")`, the same
recipe both apps used before, so old share keys keep working.

## Endpoints

| Method and path | Body | Answer | Who |
|---|---|---|---|
| `GET /v1/health` | | `{ "ok": true }` | anyone, no header |
| `GET /v1/session` | | `{ "mode": "owner" }` or `{ "mode": "shared" }`. 404 when a share key is unknown | both |
| `GET /v1/lists` | | `ListWithCount[]`, ordered by position then creation time | both |
| `POST /v1/lists` | `{ name, tags? }` | 201, the new `List`, placed last | owner |
| `PATCH /v1/lists/:id` | `{ name?, tags? }` | the updated `List` | owner |
| `DELETE /v1/lists/:id` | | 204. Its assets go with it | owner |
| `PUT /v1/lists/order` | `{ ids: string[] }` | 204. `ids` must be exactly the vault's list ids, in the new order | owner |
| `GET /v1/lists/:id/assets` | | `Asset[]`, ordered | both |
| `POST /v1/lists/:id/assets` | `{ name, ticker?, summary?, description?, tags?, resources?, image_url? }` | 201, the new `Asset`, placed last | owner |
| `PUT /v1/lists/:id/assets/order` | `{ ids: string[] }` | 204. `ids` must be exactly the list's asset ids | owner |
| `GET /v1/assets/index` | | `{ list_id, name, ticker }[]` for search | both |
| `PATCH /v1/assets/:id` | any subset of the asset fields | the updated `Asset`. Fields not sent stay as they are. `image_url` of `""` or `null` clears it | owner |
| `DELETE /v1/assets/:id` | | 204 | owner |
| `GET /v1/export?lists=id,id` | | the export file (format below). No `lists` means everything | both |
| `POST /v1/import` | an export file | `{ "lists_imported": n, "assets_imported": n }`. All or nothing | owner |
| `GET /v1/share` | | `{ "shared": boolean }` | owner |
| `PUT /v1/share` | | `{ "share_key": "..." }`. Creates the share or keeps the existing one | owner |
| `DELETE /v1/share` | | 204. The share key stops working | owner |
| `DELETE /v1/vault` | | 204. Removes every list, asset and the share | owner |

## Shapes

- `List`: `{ id, name, tags: string[], position, created_at, updated_at }`. `ListWithCount` adds `asset_count`.
- `Asset`: `{ id, list_id, name, ticker, summary, description, tags: string[], resources: Resource[], image_url: string | null, position, created_at }`.
- `Resource`: `{ title, url, favicon }`.
- Export file: `{ version: 1, app: "warket", exported_at, lists: [{ name, tags, assets: [{ name, ticker, summary, description, tags, resources, image_url? }] }] }`. `image_url` is left out when empty.

## Errors

`{ "error": { "code": "...", "message": "plain sentence a user can read" } }`

| Status | When | Codes |
|---|---|---|
| 400 | bad input | `invalid_input`, `invalid_json`, `invalid_order`, `too_many_lists`, `too_many_assets` |
| 401 | missing or malformed `Authorization` header | `unauthorized` |
| 403 | a viewer tried to write, or to use an owner-only route | `read_only` |
| 404 | unknown list, asset, route or share key | `not_found`, `share_not_found` |
| 413 | request body over 2 MB | `too_large` |
| 429 | too many requests from one address | `rate_limited` |
| 500 | server fault | `internal` |

Import messages say where the problem is, for example `List 2, asset 3: summary is longer than 250 characters`.

## Input tidying

Done by the server, so both apps behave the same: names are trimmed, tags are trimmed, lowercased and
de-duplicated, tickers are trimmed and uppercased, a missing ticker becomes `""`.

## Limits

Name 200 characters, ticker 20, 30 tags of 40 characters, summary 250 characters, description 100,000,
100 resources per asset (title 500, url 2,000), image URL 2,000, 500 lists per vault, 2,000 assets per
list, request body 2 MB. Characters are counted as Unicode code points, like the database does.

Rate limits per visitor address: 300 requests a minute, of which at most 60 may write.

## Import rules

Lists are matched by name without regard to case, against existing lists and against lists earlier in
the same file. Matched lists get the new assets at the end. New lists go after the existing ones.
Everything is written in one batch, so a failure writes nothing.
