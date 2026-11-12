/** Who is calling. Owners hold the vault hash; viewers hold a read-only share key. */
export type OwnerAccess = { mode: 'owner'; vaultId: string; vaultHash: string }
export type SharedAccess = { mode: 'shared'; vaultId: string }
export type Access = OwnerAccess | SharedAccess

export type AppEnv = {
  Bindings: Env
  Variables: { access: Access }
}
