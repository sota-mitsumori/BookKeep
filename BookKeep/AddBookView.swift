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
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var review: String = ""
    @State private var pageCountText: String
    @FocusState private var isPageCountFocused: Bool

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
                        .focused($isPageCountFocused)

                    Toggle("読み始め日を設定", isOn: dateSettingBinding(isOn: $hasStartDate, date: $startDate))

                    if hasStartDate {
                        DatePicker(
                            "読み始め日",
                            selection: nonOptionalDate($startDate),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }

                    Toggle("読み終わり日を設定", isOn: dateSettingBinding(isOn: $hasEndDate, date: $endDate))

                    if hasEndDate {
                        DatePicker(
                            "読み終わり日",
                            selection: nonOptionalDate($endDate),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ja_JP"))

                        Button("今日を読み終わり日にする") {
                            endDate = Date()
                        }
                        .foregroundColor(.secondary)
                    }
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
                if isPageCountFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") {
                            isPageCountFocused = false
                        }
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
        book.startDate = hasStartDate ? (startDate ?? Date()) : nil
        book.endDate = hasEndDate ? (endDate ?? Date()) : nil
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

    /// オンにした瞬間に今日を入れ、オフにした瞬間に下書きの日付を消す。
    private func dateSettingBinding(isOn: Binding<Bool>, date: Binding<Date?>) -> Binding<Bool> {
        Binding(
            get: { isOn.wrappedValue },
            set: { isEnabled in
                withAnimation {
                    isOn.wrappedValue = isEnabled
                }
                if isEnabled {
                    if date.wrappedValue == nil {
                        date.wrappedValue = Date()
                    }
                } else {
                    date.wrappedValue = nil
                }
            }
        )
    }

    private func nonOptionalDate(_ date: Binding<Date?>) -> Binding<Date> {
        Binding(
            get: { date.wrappedValue ?? Date() },
            set: { date.wrappedValue = $0 }
        )
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



