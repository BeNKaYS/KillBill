import SwiftUI
import WebKit

/// Sercan Özdemir (BeNKaYS) Geliştirici Kartını görüntüleyen WebKit bileşeni
struct DeveloperCardView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        var loaded = false
        if let url = Bundle.main.url(forResource: "developer_card", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            loaded = true
        }
        if !loaded {
            // Geliştirme sırasında proje dizininden yükle
            let paths = [
                "Sources/KillBill/Resources/developer_card.html",
                "Resources/developer_card.html",
                "KillBill.app/Contents/Resources/developer_card.html"
            ]
            for p in paths {
                let url = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: url.path) {
                    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                    break
                }
            }
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
