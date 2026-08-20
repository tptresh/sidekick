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
        renderedText(template: template, query: Self.probeTitle) { [weak self] probeText in
            guard let self, let probeText else {
                completion(false)
                return
            }
            self.renderedText(template: template, query: Self.controlQuery) { controlText in
                guard let controlText else {
                    completion(false)
                    return
                }
                completion(Self.searchWorks(probeText: probeText, controlText: controlText))
            }
        }
    }

    // The decision is deliberately independent of any one site's catalogue,
    // so it holds even when the probe film isn't stocked:
    // 1. Echo — the page displaying the nonsense query proves it reads the
    //    query parameter ("No results for qzvxkwjqzz").
    // 2. Title — the probe film renders for the real search but not the
    //    nonsense one.
    // 3. Difference — failing both, the two result pages must at least
    //    differ substantially; identical content means the query was
    //    ignored and the page shows the same default for any URL.
    static func searchWorks(probeText: String, controlText: String) -> Bool {
        let probe = probeText.lowercased()
        let control = controlText.lowercased()
        if control.contains(controlQuery.lowercased()) { return true }
        let marker = probeTitle.lowercased()
        if probe.contains(marker), !control.contains(marker) { return true }
        return substantiallyDifferent(probe, control)
    }

    // Word-set overlap below 60% counts as reacting to the query. Shared
    // page chrome (menus, footers) keeps ignored-parameter pages well above
    // this, while results-versus-no-results pages fall far below it.
    static func substantiallyDifferent(_ a: String, _ b: String) -> Bool {
        let wordsA = Set(a.split { !$0.isLetter && !$0.isNumber })
        let wordsB = Set(b.split { !$0.isLetter && !$0.isNumber })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return false }
        let overlap = Double(wordsA.intersection(wordsB).count)
            / Double(wordsA.union(wordsB).count)
        return overlap < 0.6
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
            // Include the tab title too — some sites echo the query there.
            webView.evaluateJavaScript(
                "document.title + '\\n' + (document.body ? document.body.innerText : '')"
            ) { value, _ in
                self?.currentWebView = nil
                webView.stopLoading()
                completion(value as? String)
            }
        }
    }
}
