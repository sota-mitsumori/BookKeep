import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \Book.createdAt, order: .forward) private var books: [Book]

    private var monthlyBooks: [MonthlyMetric] {
        aggregateMetrics().map { MonthlyMetric(month: $0.key, books: $0.value.books, pages: $0.value.pages) }
            .sorted { $0.month < $1.month }
    }

    private var monthlyPages: [MonthlyMetric] {
        monthlyBooks
    }

    private var totalBooks: Int {
        aggregateMetrics().values.reduce(0) { $0 + $1.books }
    }

    private var totalPages: Int {
        aggregateMetrics().values.reduce(0) { $0 + $1.pages }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Totals
                    VStack(alignment: .leading, spacing: 4) {
                        Text("これまでに読んだ本")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(totalBooks) 冊 / \(totalPages) ページ")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    sectionTitle("月間読了冊数")
                    chartBooks
                    Divider().overlay(Color.secondary.opacity(0.25))
                    sectionTitle("月間読了ページ数")
                    chartPages
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("分析")
        }
    }

    // MARK: - Charts

    private var chartBooks: some View {
        chart(metrics: monthlyBooks, valueKey: "冊数") { metric in
            metric.books
        }
    }

    private var chartPages: some View {
        chart(metrics: monthlyPages, valueKey: "ページ") { metric in
            metric.pages
        }
    }

    private func chart(metrics: [MonthlyMetric], valueKey: String, value: @escaping (MonthlyMetric) -> Int) -> some View {
        Group {
            if metrics.isEmpty {
                emptyState
            } else {
                Chart(metrics) { item in
                    LineMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value(valueKey, value(item))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value(valueKey, value(item))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.year().month(.defaultDigits))
                    }
                }
                .frame(height: 240)
            }
        }
    }

    // MARK: - Helpers

    private func aggregateMetrics() -> [Date: (books: Int, pages: Int)] {
        let calendar = Calendar.current
        // endDateが存在する本を「読了」としてカウント
        // startDateとendDateが同じ日（0日）や1日違いでも問題なくカウントされる
        let finished = books.filter { book in
            // endDateが存在すれば「読了」として扱う
            if let endDate = book.endDate {
                // startDateが存在する場合、endDateがstartDate以降であることを確認
                if let startDate = book.startDate {
                    return calendar.compare(startDate, to: endDate, toGranularity: .day) != .orderedDescending
                }
                // startDateがなくてもendDateがあれば「読了」として扱う
                return true
            }
            return false
        }

        return finished.reduce(into: [Date: (books: Int, pages: Int)]()) { dict, book in
            guard let endDate = book.endDate else { return }
            let comps = calendar.dateComponents([.year, .month], from: endDate)
            guard let monthDate = calendar.date(from: comps) else { return }

            let pages = book.pageCount ?? 0
            let current = dict[monthDate] ?? (books: 0, pages: 0)
            dict[monthDate] = (books: current.books + 1, pages: current.pages + pages)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var emptyState: some View {
        Text("データがありません")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Model

private struct MonthlyMetric: Identifiable {
    let month: Date
    let books: Int
    let pages: Int
    var id: Date { month }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Book.self, configurations: config)
    let context = container.mainContext
    let calendar = Calendar.current
    for offset in 0..<6 {
        let date = calendar.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
        let book = Book(
            isbn: "97812345678\(offset)",
            title: "Book \(offset)",
            authors: ["Author \(offset)"],
            pageCount: 200 + offset * 20,
            category: offset % 2 == 0 ? "技術書" : "小説"
        )
        book.status = "読了"
        book.endDate = date
        context.insert(book)
    }
    return AnalyticsView()
        .modelContainer(container)
}


