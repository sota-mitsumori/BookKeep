import SwiftUI

struct AddBookView: View {
    let info: FetchedBookInfo
    /// 保存された Book を呼び出し元に渡す
    var onSave: (Book) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var category: String
    @State private var status: String = "積読"
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var review: String = ""
    @State private var pageCountText: String

    init(info: FetchedBookInfo, onSave: @escaping (Book) -> Void) {
        self.info = info
        self.onSave = onSave
        _category = State(initialValue: info.category)
        _pageCountText = State(initialValue: info.pageCount.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("書籍情報") {
                    // 表紙画像
                    HStack {
                        Spacer()
                        coverImage
                            .frame(width: 200, height: 280)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Text(info.title)
                        .font(.headline)
                    if !info.authors.isEmpty {
                        Text(info.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("ISBN: \(info.isbn)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    if let summary = info.summary, !summary.isEmpty {
                        Divider()
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                    }
                }

                Section("読書情報") {
                    Picker("ステータス", selection: $status) {
                        Text("積読").tag("積読")
                        Text("読書中").tag("読書中")
                        Text("読了").tag("読了")
                    }

                    TextField("カテゴリ", text: $category)

                    TextField("ページ数 (任意)", text: $pageCountText)
                        .keyboardType(.numberPad)

                    DatePicker(
                        "読み始め日",
                        selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                    DatePicker(
                        "読み終わり日",
                        selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section("メモ") {
                    TextEditor(text: $review)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("本を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveBook()
                    }
                }
            }
        }
    }

    private func saveBook() {
        let book = Book(
            isbn: info.isbn,
            title: info.title,
            authors: info.authors,
            category: category.isEmpty ? "未分類" : category
        )
        book.status = status
        book.startDate = startDate
        book.endDate = endDate
        book.review = review
        if let pages = Int(pageCountText) {
            book.pageCount = pages
        }
        if let summary = info.summary {
            book.summary = summary
        }
        book.coverImageUrl = info.coverImageUrl

        onSave(book)
        dismiss()
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            if let urlString = info.coverImageUrl, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderCover
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                placeholderCover
            }
        }
    }

    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemFill))
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(String(info.title.prefix(2)))
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let sample = FetchedBookInfo(
        isbn: "9781234567890",
        title: "サンプル本",
        authors: ["山田 太郎"],
        coverImageUrl: nil,
        pageCount: 320,
        summary: "これはサンプル本の概要テキストです。Google Books API の description 相当の情報がここに表示されます。",
        category: "技術書"
    )
    AddBookView(info: sample) { _ in }
}



