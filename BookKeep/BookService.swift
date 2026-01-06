import Foundation

/// 外部APIから取得した書籍情報をアプリ内で扱うためのDTO
struct FetchedBookInfo {
    let isbn: String
    let title: String
    let authors: [String]
    let coverImageUrl: String?
    let pageCount: Int?
    let summary: String?
    let category: String
}

enum BookServiceError: Error {
    case invalidISBN
    case notFound
    case networkError(Error)
    case decodeError(Error)
}

/// Google Books API（メイン） + openBD（フォールバック）で
/// ISBN から書籍情報を取得するサービス。
final class BookService {
    static let shared = BookService()
    private init() {}

    // MARK: - Public

    /// ISBN から書籍情報を取得する（Google Books 優先 → openBD フォールバック）
    func fetchBook(byISBN isbn: String) async throws -> FetchedBookInfo {
        let normalizedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedISBN.isEmpty else {
            throw BookServiceError.invalidISBN
        }

        // 1. Google Books で試す
        if let googleResult = try? await fetchFromGoogleBooks(isbn: normalizedISBN) {
            return googleResult
        }

        // 2. openBD でフォールバック
        if let openBDResult = try? await fetchFromOpenBD(isbn: normalizedISBN) {
            return openBDResult
        }

        throw BookServiceError.notFound
    }

    // MARK: - Google Books

    private struct GoogleBooksResponse: Decodable {
        struct Volume: Decodable {
            struct VolumeInfo: Decodable {
                let title: String?
                let authors: [String]?
                let categories: [String]?
                let pageCount: Int?
                let description: String?
                struct ImageLinks: Decodable {
                    let thumbnail: String?
                }
                let imageLinks: ImageLinks?
            }
            let volumeInfo: VolumeInfo
        }

        let items: [Volume]?
    }

    private func fetchFromGoogleBooks(isbn: String) async throws -> FetchedBookInfo {
        let query = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        guard let url = URL(string: query) else {
            throw BookServiceError.invalidISBN
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // デバッグ: 実際のAPIレスポンスを確認
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📚 Google Books API レスポンス (最初の500文字):")
                print(String(jsonString.prefix(500)))
            }
            
            let decoded = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)

            guard let first = decoded.items?.first else {
                throw BookServiceError.notFound
            }

            let info = first.volumeInfo
            let title = info.title ?? "タイトル不明"
            let authors = info.authors ?? []
            let category = info.categories?.first ?? "未分類"
            let cover = normalizeCoverURL(info.imageLinks?.thumbnail)
            let pageCount = info.pageCount
            
            // デバッグ: ページ数の取得状況を確認
            if let pageCount = pageCount {
                print("📖 Google Books API: ページ数取得成功 - \(pageCount)ページ")
            } else {
                print("⚠️ Google Books API: ページ数が取得できませんでした")
            }

            return FetchedBookInfo(
                isbn: isbn,
                title: title,
                authors: authors,
                coverImageUrl: cover,
                pageCount: pageCount,
                summary: info.description,
                category: category
            )
        } catch let error as DecodingError {
            throw BookServiceError.decodeError(error)
        } catch {
            throw BookServiceError.networkError(error)
        }
    }

    // MARK: - openBD

    /// openBD のレスポンスは柔軟なJSONだが、ここではよく使うフィールドだけを拾う
    private struct OpenBDResponseElement: Decodable {
        struct Summary: Decodable {
            let title: String?
            let author: String?
            let cover: String?
            let subject: String?
        }
        let summary: Summary?
    }

    private func fetchFromOpenBD(isbn: String) async throws -> FetchedBookInfo {
        let query = "https://api.openbd.jp/v1/get?isbn=\(isbn)"
        guard let url = URL(string: query) else {
            throw BookServiceError.invalidISBN
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([OpenBDResponseElement?].self, from: data)

            // openBD は [null] を返すことがある
            guard let element = decoded.first ?? nil,
                  let summary = element.summary else {
                throw BookServiceError.notFound
            }

            let title = summary.title ?? "タイトル不明"
            let authors: [String]
            if let author = summary.author, !author.isEmpty {
                // 「著者1, 著者2」のようなケースを軽く分割
                authors = author
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            } else {
                authors = []
            }

            let category = summary.subject ?? "未分類"
            let cover = normalizeCoverURL(summary.cover)
            let pageCount: Int? = nil

            return FetchedBookInfo(
                isbn: isbn,
                title: title,
                authors: authors,
                coverImageUrl: cover,
                pageCount: pageCount,
                summary: nil,
                category: category
            )
        } catch let error as DecodingError {
            throw BookServiceError.decodeError(error)
        } catch {
            throw BookServiceError.networkError(error)
        }
    }

    // MARK: - Helpers

    /// HTTP のサムネイル URL を HTTPS に揃えるなど簡易的に整形する
    private func normalizeCoverURL(_ urlString: String?) -> String? {
        guard let urlString, !urlString.isEmpty else { return nil }

        if urlString.hasPrefix("http://") {
            return "https://" + urlString.dropFirst("http://".count)
        }
        return urlString
    }
}

