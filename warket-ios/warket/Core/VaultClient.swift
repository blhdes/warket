import Foundation
import Supabase

/// Reads the Supabase URL + anon key injected via Secrets.xcconfig → Info.plist.
enum AppConfig {
    static let supabaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw)
        else {
            fatalError("SUPABASE_URL missing/invalid in Info.plist — check Secrets.xcconfig")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist — check Secrets.xcconfig")
        }
        return key
    }()
}

/// Builds a Supabase client scoped to one vault. Every request carries the
/// `x-vault-hash` header so the database's RLS policies filter rows to that vault
/// — same trick as the web app's `vaultClient()` in `src/lib/supabase.ts`.
enum VaultClient {
    static func make(vaultHash: String) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["x-vault-hash": vaultHash]
                )
            )
        )
    }
}
