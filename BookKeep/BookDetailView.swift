import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var book: Book

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var pageCountText: String = ""

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
            }

            Section("読書情報") {
                Picker("ステータス", selection: $book.status) {
                    Text("積読").tag("積読")
                    Text("読書中").tag("読書中")
                    Text("読了").tag("読了")
                }

                TextField("カテゴリ", text: $book.category)

                DatePicker(
                    "読み始め日",
                    selection: Binding(
                        get: { book.startDate ?? Date() },
                        set: { book.startDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))

                Button("読み始め日をクリア") {
                    book.startDate = nil
                }
                .foregroundColor(.secondary)

                DatePicker(
                    "読み終わり日",
                    selection: Binding(
                        get: { book.endDate ?? Date() },
                        set: { book.endDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))

                Button("読み終わり日をクリア") {
                    book.endDate = nil
                }
                .foregroundColor(.secondary)
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

            if let saveError {
                Section {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("本の編集")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveChanges()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            if let pageCount = book.pageCount {
                pageCountText = String(pageCount)
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        saveError = nil
        if let pages = Int(pageCountText) {
            book.pageCount = pages
        } else {
            book.pageCount = nil
        }
        Task {
            do {
                try modelContext.save()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = "保存に失敗しました: \(error.localizedDescription)"
                }
            }
        }
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


