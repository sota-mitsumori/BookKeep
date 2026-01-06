import SwiftUI
import SwiftData

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingScanner = false
    @State private var isPresentingAddSheet = false
    @State private var fetchedBook: FetchedBookInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("97からはじまるバーコードをスキャンして書籍を追加")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                if isLoading {
                    ProgressView("書籍情報を取得中…")
                }

                if let message = errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if #available(iOS 16.0, *) {
                    Button {
                        errorMessage = nil
                        fetchedBook = nil
                        isPresentingScanner = true
                    } label: {
                        Label("バーコードをスキャン", systemImage: "barcode.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Text("バーコードスキャンは iOS 16 以降で利用できます。")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("スキャン")
            .sheet(isPresented: $isPresentingScanner) {
                if #available(iOS 16.0, *) {
                    BarcodeScannerView { isbn in
                        isPresentingScanner = false
                        fetchBookInfo(for: isbn)
                    }
                } else {
                    VStack {
                        Text("この機能は iOS 16 以降で利用できます。")
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
}

#Preview {
    ScanView()
        .modelContainer(for: Book.self, inMemory: true)
}
