import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var isbn: String
    var title: String
    var authors: [String]
    var coverImageUrl: String?
    var pageCount: Int?
    /// 書籍の概要（Google Books の description 相当）
    var summary: String?
    var category: String
    var startDate: Date?
    var endDate: Date?
    var review: String
    var status: String   // "積読", "読書中", "読了"
    var createdAt: Date

    init(
        isbn: String,
        title: String,
        authors: [String],
        pageCount: Int? = nil,
        category: String = "未分類"
    ) {
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.coverImageUrl = nil
        self.pageCount = pageCount
        self.summary = nil
        self.category = category
        self.startDate = nil
        self.endDate = nil
        self.review = ""
        self.status = "積読"
        self.createdAt = Date()
    }
}


