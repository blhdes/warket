import Foundation
import Supabase

/// Resolves a read-only share key back to its vault hash. Mirrors
/// `resolveShareKey` in the web app's `src/lib/queries.ts`. The `vault_shares`
/// table has an open SELECT policy, so no vault header is needed here.
enum ShareResolver {
    static func resolve(shareHash: String) async throws -> String? {
        let client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        let rows: [ShareRow] = try await client
            .from("vault_shares")
            .select("vault_hash")
            .eq("share_hash", value: shareHash)
            .limit(1)
            .execute()
            .value
        return rows.first?.vaultHash
    }

    private struct ShareRow: Decodable {
        let vaultHash: String
        enum CodingKeys: String, CodingKey { case vaultHash = "vault_hash" }
    }
}
