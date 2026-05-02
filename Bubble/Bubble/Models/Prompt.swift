import Foundation
import SwiftData

@Model
final class Prompt {
    var id: UUID
    var title: String
    var content: String
    var tag: String
    var tagColor: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    init(
        title: String,
        content: String,
        tag: String = "",
        tagColor: String = "#4A90D9",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.tag = tag
        self.tagColor = tagColor
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = sortOrder
    }
}
