import Testing
import Foundation
@testable import Bubble

@Suite("Prompt Model Tests")
struct PromptModelTests {

    @Test("Prompt initializes with correct defaults")
    func testPromptInit() {
        let prompt = Prompt(title: "Test", content: "Content")
        #expect(prompt.title == "Test")
        #expect(prompt.content == "Content")
        #expect(prompt.tag == "")
        #expect(prompt.tagColor == "#4A90D9")
        #expect(prompt.sortOrder == 0)
        #expect(prompt.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("Prompt initializes with custom tag and color")
    func testPromptWithTag() {
        let prompt = Prompt(title: "T", content: "C", tag: "写作", tagColor: "#50B83C", sortOrder: 3)
        #expect(prompt.tag == "写作")
        #expect(prompt.tagColor == "#50B83C")
        #expect(prompt.sortOrder == 3)
    }

    @Test("Prompt timestamps are set on creation")
    func testTimestamps() {
        let before = Date()
        let prompt = Prompt(title: "T", content: "C")
        let after = Date()
        #expect(prompt.createdAt >= before)
        #expect(prompt.createdAt <= after)
        #expect(prompt.updatedAt >= before)
        #expect(prompt.updatedAt <= after)
    }
}
