import SwiftUI

/// Step5: TabView で「本棚 / スキャン / 分析」を構成するエントリーポイント。
struct ContentView: View {
    var body: some View {
        TabView {
            BookListView()
                .tabItem {
                    Label("本棚", systemImage: "books.vertical")
                }

            ScanView()
                .tabItem {
                    Label("スキャン", systemImage: "barcode.viewfinder")
                }

            AnalyticsView()
                .tabItem {
                    Label("分析", systemImage: "chart.pie")
                }
        }
    }
}

#Preview {
    ContentView()
}

