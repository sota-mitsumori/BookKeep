import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book

    @State private var pageCountText: String = ""
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false

    var body: some View {
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
                
                TextField("タイトル", text: $book.title)
                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("ISBN: \(book.isbn)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("ページ数", text: $pageCountText)
                    .keyboardType(.numberPad)
                    .onChange(of: pageCountText) { _, newValue in
                        book.pageCount = Int(newValue)
                    }
            }

            Section("読書情報") {
                Picker("ステータス", selection: $book.status) {
                    Text("積読").tag("積読")
                    Text("読書中").tag("読書中")
                    Text("読了").tag("読了")
                }

                TextField("カテゴリ", text: $book.category)

                Toggle("読み始め日を設定", isOn: dateSettingBinding(isOn: $hasStartDate, date: $book.startDate))

                if hasStartDate {
                    DatePicker(
                        "読み始め日",
                        selection: nonOptionalDate($book.startDate),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Toggle("読み終わり日を設定", isOn: dateSettingBinding(isOn: $hasEndDate, date: $book.endDate))

                if hasEndDate {
                    DatePicker(
                        "読み終わり日",
                        selection: nonOptionalDate($book.endDate),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                    Button("今日を読み終わり日にする") {
                        book.endDate = Date()
                    }
                    .foregroundColor(.secondary)
                }
            }

            Section("概要") {
                TextEditor(
                    text: Binding(
                        get: { book.summary ?? "" },
                        set: { book.summary = $0.isEmpty ? nil : $0 }
                    )
                )
                .frame(minHeight: 120)
            }

            Section("メモ") {
                TextEditor(text: $book.review)
                    .frame(minHeight: 140)
            }

        }
        .navigationTitle("本の編集")
        .onAppear {
            if pageCountText.isEmpty, let pageCount = book.pageCount {
                pageCountText = String(pageCount)
            }
            hasStartDate = book.startDate != nil
            hasEndDate = book.endDate != nil
        }
    }

    /// オンにした瞬間に今日を入れ、オフにした瞬間に日付を消す。変更はすぐ本に反映される。
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

            if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
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
                Text(String(book.title.prefix(2)))
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Book.self, configurations: config)
    let context = container.mainContext
    let sample = Book(
        isbn: "9781234567890",
        title: "サンプル本",
        authors: ["山田 太郎"],
        category: "技術書"
    )
    sample.pageCount = 320
    context.insert(sample)
    return NavigationStack {
        BookDetailView(book: sample)
    }
    .modelContainer(container)
}


