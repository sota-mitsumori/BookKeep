import SwiftUI
import SwiftData

struct BookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]

    @State private var selectedStatus: String? = nil // nil = 全て表示
    @State private var isPresentingScanner = false
    @State private var isPresentingAddSheet = false
    @State private var fetchedBook: FetchedBookInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let shelfColumns = 4

    private var books: [Book] {
        if let status = selectedStatus {
            return allBooks.filter { $0.status == status }
        }
        return allBooks
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(chunkedBooks()), id: \.self) { row in
                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        ForEach(row) { book in
                                            NavigationLink {
                                                BookDetailView(book: book)
                                            } label: {
                                                coverCard(for: book)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteBook(book)
                                                } label: {
                                                    Label("削除", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    shelfBar
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("本棚")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("ステータス", selection: $selectedStatus) {
                        Text("全て").tag(String?.none)
                        Text("積読").tag(String?.some("積読"))
                        Text("読書中").tag(String?.some("読書中"))
                        Text("読了").tag(String?.some("読了"))
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 16.0, *) {
                        Button {
                            errorMessage = nil
                            fetchedBook = nil
                            isPresentingScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if isLoading {
                    ProgressView("書籍情報を取得中…")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                } else if let message = errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $isPresentingScanner) {
                if #available(iOS 16.0, *) {
                    BarcodeScannerView { isbn in
                        isPresentingScanner = false
                        fetchBookInfo(for: isbn)
                    }
                } else {
                    VStack {
                        Text("バーコードスキャンは iOS 16 以降で利用できます。")
                            .padding()
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                if let fetchedBook {
                    AddBookView(info: fetchedBook) { savedBook in
                        modelContext.insert(savedBook)
                    }
                }
            }
        }
    }

    private func fetchBookInfo(for isbn: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let info = try await BookService.shared.fetchBook(byISBN: isbn)
                await MainActor.run {
                    self.fetchedBook = info
                    self.isLoading = false
                    self.isPresentingAddSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    switch error {
                    case BookServiceError.invalidISBN:
                        self.errorMessage = "ISBNが不正です。"
                    case BookServiceError.notFound:
                        self.errorMessage = "書籍情報が見つかりませんでした。"
                    case BookServiceError.networkError(let underlying):
                        self.errorMessage = "ネットワークエラー: \(underlying.localizedDescription)"
                    case BookServiceError.decodeError:
                        self.errorMessage = "レスポンスの解析に失敗しました。"
                    default:
                        self.errorMessage = "不明なエラーが発生しました。"
                    }
                }
            }
        }
    }

    private func deleteBook(_ book: Book) {
        modelContext.delete(book)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            if selectedStatus != nil {
                Text("該当する本がありません")
                    .font(.headline)
                Text("別のステータスを選択するか、新しい本を追加してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("まだ本が登録されていません")
                    .font(.headline)
                Text("右上のバーコードボタンから、本をスキャンして登録しましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func coverCard(for book: Book) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))

                if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        placeholderCover(title: book.title)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    placeholderCover(title: book.title)
                }
            }
            .frame(height: 140)
            .frame(width: 110)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(book.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func placeholderCover(title: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))
            Text(String(title.prefix(2)))
                .font(.title2.bold())
                .foregroundStyle(.secondary)
        }
    }

    private var shelfBar: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 6)
            .overlay(
                Rectangle()
                    .fill(Color(.secondarySystemFill))
                    .frame(height: 2),
                alignment: .bottom
            )
    }

    private func chunkedBooks(columns: Int = 3) -> [[Book]] {
        stride(from: 0, to: books.count, by: columns).map { index in
            Array(books[index..<min(index + columns, books.count)])
        }
    }
}

#Preview {
    BookListView()
        .modelContainer(for: Book.self, inMemory: true)
}


