import SwiftUI
import VisionKit
import Vision

/// VisionKit の DataScannerViewController を SwiftUI から使うためのラッパー
/// EAN-13 (ISBN) のバーコードのみを検出する。
@available(iOS 16.0, *)
struct BarcodeScannerView: UIViewControllerRepresentable {

    /// 検出したバーコード文字列（ISBN）を返すコールバック
    var onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        // 対応デバイスかどうかをチェック
        guard DataScannerViewController.isSupported else {
            return UnsupportedScannerViewController(message: "このデバイスはバーコードスキャンに対応していません。")
        }

        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        do {
            try scanner.startScanning()
        } catch {
            // 実機上でのデバッグ用にエラーをログ出力
            print("Failed to start DataScannerViewController: \(error)")
        }

        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 今のところ更新時の特別な処理は不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }
}

@available(iOS 16.0, *)
extension BarcodeScannerView {
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onBarcodeDetected: (String) -> Void

        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(items: addedItems)
        }

        private func handle(items: [RecognizedItem]) {
            for item in items {
                if case let .barcode(barcode) = item,
                   let payload = barcode.payloadStringValue {
                    // ISBN (EAN-13) を検出したタイミングでコールバック
                    onBarcodeDetected(payload)
                    // 単一検出を想定しているので、一旦ここで break
                    break
                }
            }
        }
    }
}

/// DataScannerViewController が使えない環境向けの簡易プレースホルダー
private final class UnsupportedScannerViewController: UIViewController {
    init(message: String) {
        super.init(nibName: nil, bundle: nil)
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


