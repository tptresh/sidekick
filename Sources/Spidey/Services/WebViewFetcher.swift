import Foundation
import WebKit

// Fetches a URL's text through a hidden web view instead of a plain HTTP
// client. Sites behind anti-bot walls (Cloudflare and friends) only answer
// real browsers; the web view shares the persistent cookie store where a
// previously solved challenge lives, and rides out a fresh challenge by
// polling until the page stops being an interstitial.
final class WebViewFetcher: NSObject {
    static let shared = WebViewFetcher()

    static let pollInterval: TimeInterval = 1.5
    static let pollAttempts = 12

    private var pending: [(url: URL, completion: (String?) -> Void)] = []
    private var busy = false
    private var webView: WKWebView?

    // Must be called on the main thread. Completion arrives on main.
    func fetchText(url: URL, completion: @escaping (String?) -> Void) {
        pending.append((url, completion))
        processNext()
    }

    private func processNext() {
        guard !busy, let job = pending.first else { return }
        busy = true
        pending.removeFirst()
        run(url: job.url) { [weak self] text in
            job.completion(text)
            self?.busy = false
            self?.processNext()
        }
    }

    private func run(url: URL, completion: @escaping (String?) -> Void) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 900), configuration: config)
        webView.customUserAgent = SiteSearchOpener.userAgent
        self.webView = webView
        webView.load(URLRequest(url: url, timeoutInterval: 20))
        poll(webView: webView, attemptsLeft: Self.pollAttempts) { [weak self] text in
            self?.webView?.stopLoading()
            self?.webView = nil
            completion(text)
        }
    }

    // The body text is delivered as soon as it parses as JSON; anything else
    // (a challenge page, a partial load) keeps polling until the deadline.
    private func poll(
        webView: WKWebView, attemptsLeft: Int, then: @escaping (String?) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval) {
            webView.evaluateJavaScript(
                "document.body ? document.body.innerText : ''"
            ) { value, _ in
                let text = value as? String ?? ""
                if SiteSearchAnalysis.firstResultsArray(inJSON: text) != nil {
                    then(text)
                    return
                }
                guard attemptsLeft > 0 else {
                    then(nil)
                    return
                }
                self.poll(webView: webView, attemptsLeft: attemptsLeft - 1, then: then)
            }
        }
    }
}
