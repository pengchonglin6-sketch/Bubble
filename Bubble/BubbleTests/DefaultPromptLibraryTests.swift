import Foundation
import SwiftData
import Testing
@testable import Bubble

@Suite("Bundled prompt library")
@MainActor
struct DefaultPromptLibraryTests {
    private func withStore(_ body: (ModelContext, UserDefaults) throws -> Void) throws {
        let container = try ModelContainer(
            for: Prompt.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let name = "BubbleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(container.mainContext, defaults)
    }

    private func prompts(_ context: ModelContext) throws -> [Prompt] {
        try context.fetch(FetchDescriptor<Prompt>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test("A clean install gets all 13 complete prompts in bundled order")
    func cleanInstall() throws {
        try withStore { context, defaults in
            let entries = try DefaultPromptLibrary.load()
            #expect(entries.count == 13)
            #expect(Set(entries.map(\.title)).count == 13)
            #expect(entries.allSatisfy { !$0.content.isEmpty && $0.content.count <= 5000 })
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            let imported = try prompts(context)
            #expect(imported.map(\.title) == entries.map(\.title))
            #expect(imported.map(\.content) == entries.map(\.content))
            #expect(imported.map(\.tag) == entries.map(\.tag))
            #expect(imported.map(\.tagColor) == entries.map(\.tagColor))
            #expect(imported.map(\.sortOrder) == Array(0..<13))
            #expect(defaults.bool(forKey: DefaultPromptLibrary.importedKey))
        }
    }

    @Test("Upgrading preserves custom data and skips identical prompts")
    func upgrade() throws {
        try withStore { context, defaults in
            defaults.set(true, forKey: "hasInsertedSampleData")
            let entry = try #require(DefaultPromptLibrary.load().first)
            let custom = Prompt(title: "我的提示词", content: "我的内容", sortOrder: 7)
            let existing = Prompt(title: entry.title, content: entry.content,
                                  tag: "我的标签", tagColor: "#123456", sortOrder: 42)
            context.insert(custom)
            context.insert(existing)
            try context.save()
            let originalID = existing.id
            let originalDate = existing.updatedAt
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            let imported = try prompts(context)
            #expect(imported.count == 14)
            #expect(imported.first?.id == custom.id)
            #expect(existing.id == originalID && existing.updatedAt == originalDate)
            #expect(existing.tag == "我的标签" && existing.tagColor == "#123456")
            #expect(existing.sortOrder == 42)
            #expect(imported.dropFirst(2).map(\.sortOrder) == Array(43..<55))
        }
    }

    @Test("Restarting preserves edits and does not restore deleted prompts")
    func restart() throws {
        try withStore { context, defaults in
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            let imported = try prompts(context)
            imported[0].content = "用户修改的内容"
            context.delete(imported[1])
            try context.save()
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            #expect(try prompts(context).count == 12)
            #expect(imported[0].content == "用户修改的内容")
            for prompt in try prompts(context) { context.delete(prompt) }
            try context.save()
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            #expect(try prompts(context).isEmpty)
        }
    }

    @Test("An empty old installation also receives the library")
    func emptyUpgrade() throws {
        try withStore { context, defaults in
            defaults.set(true, forKey: "hasInsertedSampleData")
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            #expect(try prompts(context).count == 13)
        }
    }

    @Test("Missing resources do not mark import complete and can be retried")
    func failedImport() throws {
        try withStore { context, defaults in
            let emptyBundle = Bundle(for: NSObject.self)
            #expect(throws: (any Error).self) {
                try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults,
                                                       bundle: emptyBundle)
            }
            #expect(!defaults.bool(forKey: DefaultPromptLibrary.importedKey))
            #expect(try prompts(context).isEmpty)
            try DefaultPromptLibrary.importIfNeeded(into: context, defaults: defaults)
            #expect(try prompts(context).count == 13)
        }
    }
}
