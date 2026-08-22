import Foundation
import SwiftData

/// Versioned schema so future model changes can migrate existing installs instead of crashing.
/// V1 == the models as shipped in 1.0/1.1 (plus additive, defaulted fields added in 1.2, which
/// SwiftData handles as lightweight changes).
enum SpendZeroSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [UserProfile.self, SpendingLog.self, ChallengeEntry.self, SavingsEntry.self,
         DailyRecord.self, ImpulseLog.self, GameProfile.self, Quest.self, BadgeInstance.self]
    }
}

enum SpendZeroMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SpendZeroSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum SpendZeroStore {
    /// The live container, for code outside the SwiftUI environment (notification actions, intents).
    @MainActor static var container: ModelContainer?

    /// Builds the production container. If the on-disk store cannot be opened (corruption or an
    /// incompatible schema), the broken store is moved aside and a fresh one created so the app
    /// still launches; the last-resort fallback is an in-memory store.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SpendZeroSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: SpendZeroMigrationPlan.self, configurations: [config])
        } catch {
            NSLog("SpendZero: failed to open store (\(error)); moving it aside")
            moveStoreAside(config.url)
            do {
                return try ModelContainer(for: schema, migrationPlan: SpendZeroMigrationPlan.self, configurations: [config])
            } catch {
                NSLog("SpendZero: fresh store failed too (\(error)); using in-memory store")
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                // A schema that fails in memory is a programming error, so crashing here is correct.
                return try! ModelContainer(for: schema, configurations: [memory])
            }
        }
    }

    private static func moveStoreAside(_ url: URL) {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: url.path + ".corrupt-\(stamp)" + suffix)
            try? fm.moveItem(at: src, to: dst)
        }
    }
}
