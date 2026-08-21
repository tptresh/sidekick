import Foundation
import WebKit

// Learns how a site's search works the way a person would find out: open the
// homepage in a hidden web view, locate the search box (clicking a "search"
// opener if the box lives in an overlay), type a well-known film title, and
// watch what happens. Three things can be learned, in order of preference:
//
// 1. The page URL changes to a search results page - that URL, with the query
//    swapped for a placeholder, becomes a regular search template.
// 2. A request fires whose URL contains the typed query - that is the site's
//    internal search API. Paired with a learned title-page pattern (see
//    SiteSearchAnalysis.titleTemplate), searches can jump straight to the top
//    matching title.
// 3. Neither - the site cannot be searched from a URL, and its result row
//    falls back to opening the homepage.
final class InteractiveSearchProber: NSObject {
    static let shared = InteractiveSearchProber()

    struct Learned {
        var pageTemplate: String?
        var apiTemplate: String?
        var titleTemplate: String?
    }

    static let probeTitle = "Interstellar"
    static let controlQuery = "qzvxkwjqzz"
    // The homepage gets this long to render before we go looking for the box.
    static let loadWait: TimeInterval = 8
    // Overlay open animations finish well within this.
    static let revealWait: TimeInterval = 2
    // Debounced search calls and result rendering after typing.
    static let resultsWait: TimeInterval = 8

    private var pending: [(homepage: URL, completion: (Learned?) -> Void)] = []
    private var busy = false
    private var webView: WKWebView?

    // Must be called on the main thread; probes run one site at a time.
    func probe(homepage: URL, completion: @escaping (Learned?) -> Void) {
        pending.append((homepage, completion))
        processNext()
    }

    private func processNext() {
        guard !busy, let job = pending.first else { return }
        busy = true
        pending.removeFirst()
        run(homepage: job.homepage) { [weak self] learned in
            job.completion(learned)
            self?.busy = false
            self?.processNext()
        }
    }

    private func run(homepage: URL, completion: @escaping (Learned?) -> Void) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addUserScript(WKUserScript(
            source: Self.instrumentationJS, injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 900), configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        self.webView = webView
        webView.load(URLRequest(url: homepage, timeoutInterval: 20))

        let finish: (Learned?) -> Void = { [weak self] learned in
            self?.webView?.stopLoading()
            self?.webView = nil
            completion(learned)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadWait) {
            webView.evaluateJavaScript(Self.openSearchJS) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealWait) {
                    let typeJS = Self.typeJS(query: Self.probeTitle)
                    webView.evaluateJavaScript(typeJS) { typed, _ in
                        guard (typed as? Bool) == true else {
                            finish(nil)
                            return
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.resultsWait) {
                            webView.evaluateJavaScript(Self.collectJS) { value, _ in
                                self.analyze(
                                    collected: value as? [String: Any], homepage: homepage,
                                    completion: finish
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Turn the raw observations into learned templates, then prove the search
    // API against the live site with a control query before trusting it.
    private func analyze(
        collected: [String: Any]?, homepage: URL, completion: @escaping (Learned?) -> Void
    ) {
        guard let collected, let host = homepage.host else {
            completion(nil)
            return
        }
        let requests = collected["requests"] as? [String] ?? []
        let bodies = collected["bodies"] as? [String: String] ?? [:]
        let anchors = collected["anchors"] as? [String] ?? []
        let href = collected["href"] as? String ?? ""
        let navs = collected["navs"] as? [String] ?? []

        // Best case: typing moved the page to a real results URL.
        for candidate in [href] + navs {
            if let template = SiteSearchAnalysis.pageTemplate(
                finalURL: candidate, homepage: homepage, probeQuery: Self.probeTitle
            ) {
                completion(Learned(pageTemplate: template))
                return
            }
        }

        let apiTemplates = SiteSearchAnalysis.apiTemplates(
            recordedURLs: requests, probeQuery: Self.probeTitle, host: host
        )
        guard let apiTemplate = apiTemplates.first,
              let titleTemplate = SiteSearchAnalysis.titleTemplate(
                jsonBodies: Array(bodies.values), routes: anchors + requests, host: host
              )
        else {
            completion(nil)
            return
        }
        verifyAPI(template: apiTemplate) { works in
            completion(works
                ? Learned(apiTemplate: apiTemplate, titleTemplate: titleTemplate)
                : nil)
        }
    }

    // The probe search must return a list of titles containing the probe film;
    // the nonsense search must not, and must differ - otherwise the endpoint
    // is ignoring the query.
    private func verifyAPI(template: String, completion: @escaping (Bool) -> Void) {
        fetchResults(template: template, query: Self.probeTitle) { probe in
            guard let probe, !probe.isEmpty,
                  SiteSearchAnalysis.resultsText(probe).localizedCaseInsensitiveContains(Self.probeTitle)
            else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.fetchResults(template: template, query: Self.controlQuery) { control in
                let controlText = control.map(SiteSearchAnalysis.resultsText) ?? ""
                let works = !controlText.localizedCaseInsensitiveContains(Self.probeTitle)
                    && controlText != SiteSearchAnalysis.resultsText(probe)
                DispatchQueue.main.async { completion(works) }
            }
        }
    }

    private func fetchResults(
        template: String, query: String, completion: @escaping ([[String: Any]]?) -> Void
    ) {
        guard let url = URL(string: template.replacingOccurrences(
            of: CustomMediaSite.queryPlaceholder, with: BrowserLauncher.encodeQuery(query)
        )) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(SiteSearchOpener.userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(SiteSearchAnalysis.firstResultsArray(inJSON: text) ?? [])
        }.resume()
    }

    // MARK: - Injected scripts

    // Records every request URL, textual response bodies, and client-side
    // navigations, so the collect step can see how the site reacted.
    private static let instrumentationJS = #"""
    (() => {
      if (window.__spidey) { return; }
      const W = window.__spidey = { requests: [], bodies: {}, navs: [] };
      const rec = u => { try { if (W.requests.length < 400) W.requests.push(String(u)); } catch (e) {} };
      const keepBody = (u, t) => {
        try {
          if (t && t.length < 250000 && Object.keys(W.bodies).length < 20) W.bodies[String(u)] = t;
        } catch (e) {}
      };
      const origFetch = window.fetch;
      window.fetch = function () {
        const u = arguments[0] && arguments[0].url ? arguments[0].url : arguments[0];
        rec(u);
        const p = origFetch.apply(this, arguments);
        p.then(r => {
          try {
            const c = r.clone();
            const ct = c.headers.get('content-type') || '';
            if (/json|text/i.test(ct)) c.text().then(t => keepBody(u, t)).catch(() => {});
          } catch (e) {}
        }).catch(() => {});
        return p;
      };
      const origXHROpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function (m, u) {
        this.__spideyURL = String(u);
        rec(u);
        return origXHROpen.apply(this, arguments);
      };
      const origXHRSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function () {
        this.addEventListener('load', () => {
          try {
            if (this.responseType === '' || this.responseType === 'text')
              keepBody(this.__spideyURL, this.responseText);
          } catch (e) {}
        });
        return origXHRSend.apply(this, arguments);
      };
      const origPush = history.pushState;
      history.pushState = function (s, t, u) {
        if (u) W.navs.push(String(new URL(u, location.href)));
        return origPush.apply(this, arguments);
      };
      const origReplace = history.replaceState;
      history.replaceState = function (s, t, u) {
        if (u) W.navs.push(String(new URL(u, location.href)));
        return origReplace.apply(this, arguments);
      };
      const origOpen = window.open;
      window.open = function (u) { if (u) W.navs.push(String(u)); return null; };
    })();
    """#

    // Find a usable text box; when the search lives behind an opener (a button
    // or link labelled search), click it so the box appears.
    private static let openSearchJS = #"""
    (() => {
      const typable = e => {
        const type = (e.getAttribute('type') || 'text').toLowerCase();
        return e.tagName === 'TEXTAREA' || ['text', 'search'].includes(type);
      };
      const inputs = Array.from(document.querySelectorAll('input, textarea')).filter(typable);
      if (inputs.length > 0) { return 'input-present'; }
      const searchy = e => {
        const s = [e.getAttribute('aria-label'), e.getAttribute('title'), e.id,
                   typeof e.className === 'string' ? e.className : (e.className && e.className.baseVal)
                  ].join(' ');
        return /search/i.test(s);
      };
      const visible = e => {
        const r = e.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      };
      const opener = Array.from(document.querySelectorAll('button, a, [role=button]'))
        .filter(visible).find(searchy);
      if (opener) { opener.click(); return 'opened'; }
      return 'nothing';
    })();
    """#

    // Type like a framework expects: set the value through the native setter,
    // then announce it with an input event so React-style listeners fire.
    private static func typeJS(query: String) -> String {
        #"""
        (() => {
          const typable = e => {
            const type = (e.getAttribute('type') || 'text').toLowerCase();
            return e.tagName === 'TEXTAREA' || ['text', 'search'].includes(type);
          };
          const boxes = Array.from(document.querySelectorAll('input, textarea')).filter(typable);
          const searchy = e => /search|find|title|movie|show/i.test(
            [e.getAttribute('placeholder'), e.getAttribute('aria-label'), e.id, e.name].join(' ')
          );
          const input = boxes.find(searchy) || boxes[0];
          if (!input) { return false; }
          const proto = input.tagName === 'TEXTAREA'
            ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
          input.focus();
          setter.call(input, QUERY);
          input.dispatchEvent(new Event('input', { bubbles: true }));
          return true;
        })();
        """#.replacingOccurrences(of: "QUERY", with: jsString(query))
    }

    private static let collectJS = #"""
    (() => {
      const W = window.__spidey || { requests: [], bodies: {}, navs: [] };
      const anchors = Array.from(document.querySelectorAll('a[href]'))
        .map(a => a.getAttribute('href')).filter(h => h).slice(0, 300);
      return { href: location.href, requests: W.requests, bodies: W.bodies,
               navs: W.navs, anchors: anchors };
    })();
    """#

    private static func jsString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escaped)'"
    }
}
