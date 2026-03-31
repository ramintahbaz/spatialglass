import SwiftUI
import WebKit

struct BrowserPanel: View {
    @State private var urlString = "https://wikipedia.org"
    @State private var committedURL = "https://wikipedia.org"
    @State private var isLoading = false
    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isOpaque = false
        return wv
    }()

    var body: some View {
        VStack(spacing: 0) {
            // address bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search or enter URL", text: $urlString)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit { load() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )

                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Button(action: { load() }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.bottom, 10)

            // web content
            LiveWebView(
                urlString: $committedURL,
                isLoading: $isLoading,
                webView: webView
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    func load() {
        var raw = urlString.trimmingCharacters(in: .whitespaces)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            if raw.contains(".") && !raw.contains(" ") {
                raw = "https://" + raw
            } else {
                raw = "https://www.google.com/search?q=" + (raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)
            }
        }
        committedURL = raw
        urlString = raw
    }
}

struct LiveWebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    let webView: WKWebView

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator

        // make page backgrounds transparent
        let css = """
            html, body {
                background: transparent !important;
                background-color: transparent !important;
            }
        """
        let js = """
            (function() {
                var style = document.createElement('style');
                style.textContent = `\(css)`;
                document.head.appendChild(style);
            })();
        """
        let script = WKUserScript(
            source: js,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(script)

        loadURL()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url?.absoluteString != urlString {
            loadURL()
        }
    }

    private func loadURL() {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LiveWebView
        init(_ parent: LiveWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            // update address bar with final URL (handles redirects)
            if let url = webView.url?.absoluteString {
                DispatchQueue.main.async {
                    self.parent.urlString = url
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
