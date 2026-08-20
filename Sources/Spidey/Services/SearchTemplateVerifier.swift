import Foundation
import WebKit

// Proves a candidate search template actually works on the live site before
// Spidey trusts it. Each candidate is loaded in a hidden web view (so
// JavaScript-rendered sites count too): a search for a well-known film must
// render its title, and a nonsense search must not — which catches sites
// that ignore the parameter and show the same default content for any URL.
// A verification takes roughly half a minute per candidate; it runs in the
// background after a link is added.
final class SearchTemplateVerifier: NSObject {
    static let shared = SearchTemplateVerifier()

    // A title virtually every media site can find, unlikely to be echoed by
    // a page that ignored the query.
    static let probeTitle = "Interstellar"
    static let controlQuery = "qzvxkwjqzz"
    // How long a page gets to fetch and render results before we read it.
    static let renderWait: TimeInterval = 15

    private var pending: [(candidates: [String], completion: (String?) -> Void)] = []
    private var busy = false
    private var currentWebView: WKWebView?

    // Runs candidates in order on a single hidden web view and hands back the
    // first one that verifies, or nil. Must be called on the main thread.
    func firstWorking(from candidates: [String], completion: @escaping (String?) -> Void) {
        pending.append((candidates, completion))
        processNext()
    }

    private func processNext() {
        guard !busy, !pending.isEmpty else { return }
        busy = true
        let job = pending.removeFirst()
        tryCandidate(at: 0, of: job.candidates) { [weak self] template in
            job.completion(template)
            self?.busy = false
            self?.processNext()
        }
    }

    private func tryCandidate(
        at index: Int, of candidates: [String], completion: @escaping (String?) -> Void
    ) {
        guard index < candidates.count else {
            completion(nil)
            return
        }
        verify(template: candidates[index]) { [weak self] works in
            if works {
                completion(candidates[index])
            } else {
                self?.tryCandidate(at: index + 1, of: candidates, completion: completion)
            }
        }
    }

    private func verify(template: String, completion: @escaping (Bool) -> Void) {
        let marker = Self.probeTitle.lowercased()
        renderedText(template: template, query: Self.probeTitle) { [weak self] probeText in
            guard let self, let probeText, probeText.lowercased().contains(marker) else {
                completion(false)
                return
            }
            self.renderedText(template: template, query: Self.controlQuery) { controlText in
                guard let controlText else {
                    completion(false)
                    return
                }
                completion(!controlText.lowercased().contains(marker))
            }
        }
    }

    // Load the filled template off-screen, give scripts time to render, then
    // read the visible text.
    private func renderedText(
        template: String, query: String, completion: @escaping (String?) -> Void
    ) {
        let filled = template.replacingOccurrences(
            of: CustomMediaSite.queryPlaceholder,
            with: BrowserLauncher.encodeQuery(query)
        )
        guard let url = URL(string: filled) else {
            completion(nil)
            return
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 900))
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        currentWebView = webView
        webView.load(URLRequest(url: url, timeoutInterval: 20))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.renderWait) { [weak self] in
            webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { value, _ in
                self?.currentWebView = nil
                webView.stopLoading()
                completion(value as? String)
            }
        }
    }
}
