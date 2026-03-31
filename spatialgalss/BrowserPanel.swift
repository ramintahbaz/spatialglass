import SwiftUI
import WebKit

struct BrowserPanel: View {
    @State private var urlString = "https://wikipedia.org"
    @State private var committedURL = "https://wikipedia.org"
    @State private var isLoading = false
    @State private var extractedItems: [PageItem] = []
    @State private var showRaw = false
    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        return wv
    }()

    var body: some View {
        VStack(spacing: 0) {
            // address bar
            HStack(spacing: 10) {
                TextField("Search or enter URL", text: $urlString)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { load() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: { showRaw.toggle() }) {
                    Image(systemName: showRaw ? "list.bullet" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }

                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            }
            .padding(.bottom, 10)

            if showRaw {
                // raw webview with transparent bg
                WebViewRepresentable(
                    urlString: $committedURL,
                    isLoading: $isLoading,
                    onItemsExtracted: { items in extractedItems = items },
                    webView: webView
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // glass list view — the reference screenshot look
                ScrollView {
                    if extractedItems.isEmpty && !isLoading {
                        Text("loading content...")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 1) {
                            ForEach(extractedItems) { item in
                                GlassRow(item: item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 440)
            }
        }
    }

    func load() {
        var raw = urlString.trimmingCharacters(in: .whitespaces)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            if raw.contains(".") {
                raw = "https://" + raw
            } else {
                raw = "https://www.google.com/search?q=" + (raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)
            }
        }
        committedURL = raw
        urlString = raw
        showRaw = false
    }
}

// MARK: - Glass row (the key component)
struct GlassRow: View {
    let item: PageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            if let sub = item.subtitle {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(2)
            }
            if let meta = item.meta {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(meta)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Data model
struct PageItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let meta: String?
}

// MARK: - WebView (hidden, just extracts content)
struct WebViewRepresentable: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    var onItemsExtracted: ([PageItem]) -> Void
    let webView: WKWebView

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator

        // inject CSS for raw view fallback
        let css = "* { background: transparent !important; color: white !important; } body { background: transparent !important; } a { color: rgba(255,255,255,0.8) !important; }"
        let js = "var s=document.createElement('style');s.innerHTML=`\(css)`;document.head.appendChild(s);"
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)

        load(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        load(uiView)
    }

    private func load(_ wv: WKWebView) {
        guard let url = URL(string: urlString) else { return }
        if wv.url?.absoluteString != urlString {
            wv.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            extractContent(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        // pulls headings + paragraphs out of the page and maps to PageItems
        func extractContent(from webView: WKWebView) {
            let js = """
            (function() {
                var items = [];
                var host = window.location.hostname.replace('www.','');

                // try headings first (h1-h3)
                var headings = document.querySelectorAll('h1,h2,h3,h4');
                headings.forEach(function(h) {
                    var title = h.innerText.trim();
                    if (!title || title.length < 3) return;
                    var next = h.nextElementSibling;
                    var sub = null;
                    if (next && (next.tagName === 'P' || next.tagName === 'SPAN')) {
                        sub = next.innerText.trim().substring(0, 80);
                    }
                    items.push({ title: title, subtitle: sub, meta: host });
                });

                // fallback to list items
                if (items.length < 3) {
                    var lis = document.querySelectorAll('li a, article a');
                    lis.forEach(function(a) {
                        var title = a.innerText.trim();
                        if (!title || title.length < 3) return;
                        items.push({ title: title, subtitle: null, meta: host });
                    });
                }

                return JSON.stringify(items.slice(0, 30));
            })()
            """

            webView.evaluateJavaScript(js) { result, _ in
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else { return }

                let items = raw.compactMap { dict -> PageItem? in
                    guard let title = dict["title"] as? String else { return nil }
                    return PageItem(
                        title: title,
                        subtitle: dict["subtitle"] as? String,
                        meta: dict["meta"] as? String
                    )
                }

                DispatchQueue.main.async {
                    self.parent.onItemsExtracted(items)
                }
            }
        }
    }
}
