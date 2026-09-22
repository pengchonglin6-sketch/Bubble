import Foundation
import SwiftData

enum DefaultPromptLibrary {
    // A one-time import: deleting or editing a bundled prompt is permanent.
    static let importedKey = "hasImportedDefaultPromptLibraryV1"

    struct Entry: Decodable, Equatable {
        let title: String
        let content: String
        let tag: String
        let tagColor: String
    }

    static func load(bundle: Bundle = .main) throws -> [Entry] {
        guard let url = bundle.url(forResource: "DefaultPrompts", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    @MainActor
    static func importIfNeeded(
        into context: ModelContext,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) throws {
        guard !defaults.bool(forKey: importedKey) else { return }
        let entries = try load(bundle: bundle)
        let existing = try context.fetch(FetchDescriptor<Prompt>())
        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1

        do {
            for entry in entries {
                // The author's library (or an existing identical copy) stays intact.
                guard !existing.contains(where: {
                    $0.title == entry.title && $0.content == entry.content
                }) else { continue }

                context.insert(Prompt(
                    title: entry.title,
                    content: entry.content,
                    tag: entry.tag,
                    tagColor: entry.tagColor,
                    sortOrder: nextOrder
                ))
                nextOrder += 1
            }
            try context.save()
            // Only mark success after persistence, so a failed import can be retried.
            defaults.set(true, forKey: importedKey)
        } catch {
            context.rollback()
            throw error
        }
    }
}
