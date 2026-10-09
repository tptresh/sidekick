import Foundation
import Combine

// Periodically verifies that the streaming services and custom media sites
// still resolve, so dead domains get flagged in results and Preferences.
final class LinkChecker: ObservableObject {
    static let shared = LinkChecker()

    struct Status: Codable, Equatable {
        var ok: Bool
        var detail: String
        var date: Date
    }

    // Every 2 days, as promised in Preferences (which derives its copy from this).
    static let checkInterval: TimeInterval = 2 * 24 * 60 * 60
    private static let pollInterval: TimeInterval = 6 * 60 * 60

    @Published private(set) var statuses: [String: Status]
    @Published private(set) var lastRun: Date?
    @Published private(set) var isRunning = false
    // Set when the last check was skipped because every site failed at once.
    @Published private(set) var lastCheckLooksOffline = false

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var sitesSubscription: AnyCancellable?
    // Hosts currently being probed and verified - published so Preferences
    // can show that the site's search is still being set up.
    @Published private(set) var discoveringHosts: Set<String> = []
    // Hosts where no candidate survived verification, so edits don't hammer
    // the same site.
    private var undiscoverableHosts: Set<String> = []

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        // A browser user agent, because some streaming sites reject unknown clients.
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        ]
        return URLSession(configuration: config)
    }()

    private init() {
        if let data = defaults.data(forKey: "linkCheckStatuses"),
           let stored = try? JSONDecoder().decode([String: Status].self, from: data) {
            statuses = stored
        } else {
            statuses = [:]
        }
        lastRun = defaults.object(forKey: "linkCheckLastRun") as? Date
    }

    // Called at app launch: run a check if one is overdue, then keep polling
    // so long-running instances re-check every few days on their own.
    func startAutomaticChecks() {
        runIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.runIfDue()
            self?.retryFailedDiscoveries()
        }
        // Whenever a plain custom link is added or edited (debounced past the
        // keystrokes), learn how to search it.
        sitesSubscription = SettingsStore.shared.$customMediaSites
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] sites in
                self?.discoverSearchTemplates(for: sites)
            }
    }

    // A site whose learning attempt failed (down, slow, or mid-redesign) gets
    // another chance at every poll and whenever the user checks links by
    // hand, instead of staying unlearned until the next launch.
    func retryFailedDiscoveries() {
        undiscoverableHosts.removeAll()
        discoverSearchTemplates(for: SettingsStore.shared.customMediaSites)
    }

    // Learned searches rot when a site redesigns. Each check cycle re-proves
    // every learned mechanism against the live site; a broken one is cleared,
    // which automatically triggers a fresh learning pass for that site.
    func reverifyLearnedSearches() {
        for site in SettingsStore.shared.customMediaSites {
            guard site.isValid, let host = site.host, !discoveringHosts.contains(host)
            else { continue }
            if let template = site.activeDiscoveredTemplate {
                SearchTemplateVerifier.shared.firstWorking(from: [template]) { working in
                    if working == nil { self.clearLearned(siteID: site.id, host: host) }
                }
            } else if let api = site.activeDiscoveredAPI {
                SiteSearchOpener.verify(apiTemplate: api.apiTemplate) { works in
                    if !works { self.clearLearned(siteID: site.id, host: host) }
                }
            }
        }
    }

    private func clearLearned(siteID: UUID, host: String) {
        let store = SettingsStore.shared
        guard let index = store.customMediaSites.firstIndex(where: {
            $0.id == siteID && $0.host == host
        }) else { return }
        store.customMediaSites[index].discoveredTemplate = nil
        store.customMediaSites[index].discoveredAPITemplate = nil
        store.customMediaSites[index].discoveredTitleTemplate = nil
        store.customMediaSites[index].discoveredHost = nil
        // The store mutation republishes the site list, which starts a fresh
        // learning pass on its own.
        undiscoverableHosts.remove(host)
    }

    // Learn how to search the site, preferring what a real visit teaches:
    // first drive the site's own search box in a hidden web view
    // (InteractiveSearchProber), and only if that finds nothing fall back to
    // guessing common search URLs and verifying them. Whatever is learned is
    // proven against the live site before it is stored.
    func discoverSearchTemplates(for sites: [CustomMediaSite]) {
        for site in sites {
            guard site.isValid, !site.hasSearchTemplate, site.activeDiscoveredTemplate == nil,
                  site.activeDiscoveredAPI == nil,
                  let homepage = site.homepageURL, let host = site.host,
                  !discoveringHosts.contains(host), !undiscoverableHosts.contains(host)
            else { continue }
            discoveringHosts.insert(host)
            InteractiveSearchProber.shared.probe(homepage: homepage) { outcome in
                switch outcome {
                case .learned(let learned):
                    self.finishDiscovery(siteID: site.id, host: host, learned: learned)
                case .walled:
                    // URL guessing would just hit the same wall; record the
                    // wall so results and Preferences can be honest about it.
                    self.finishDiscovery(siteID: site.id, host: host, learned: nil, walled: true)
                case .nothing:
                    SearchTemplateFinder.candidates(homepage: homepage, session: self.session) { candidates in
                        DispatchQueue.main.async {
                            guard !candidates.isEmpty else {
                                self.finishDiscovery(siteID: site.id, host: host, learned: nil)
                                return
                            }
                            SearchTemplateVerifier.shared.firstWorking(from: candidates) { template in
                                self.finishDiscovery(
                                    siteID: site.id, host: host,
                                    learned: template.map {
                                        InteractiveSearchProber.Learned(pageTemplate: $0)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func finishDiscovery(
        siteID: UUID, host: String, learned: InteractiveSearchProber.Learned?,
        walled: Bool = false
    ) {
        discoveringHosts.remove(host)
        let store = SettingsStore.shared
        let index = store.customMediaSites.firstIndex { $0.id == siteID && $0.host == host }
        guard let learned else {
            undiscoverableHosts.insert(host)
            if walled, let index { store.customMediaSites[index].walledHost = host }
            return
        }
        guard let index else { return }
        if let page = learned.pageTemplate {
            store.customMediaSites[index].discoveredTemplate = page
        } else {
            store.customMediaSites[index].discoveredAPITemplate = learned.apiTemplate
            store.customMediaSites[index].discoveredTitleTemplate = learned.titleTemplate
            store.customMediaSites[index].discoveredHost = host
        }
        store.customMediaSites[index].walledHost = nil
    }

    // A flagged site is re-checked on the next poll (every few hours) rather
    // than staying flagged for days after a one-off outage.
    func runIfDue() {
        let interval = failingKeys.isEmpty ? Self.checkInterval : Self.pollInterval
        if let lastRun, Date().timeIntervalSince(lastRun) < interval { return }
        checkNow()
    }

    var failingKeys: [String] {
        statuses.filter { !$0.value.ok }.map(\.key)
    }

    func checkNow() {
        guard !isRunning else { return }
        let targets = Self.targets(
            services: SettingsStore.shared.activeStreamingServices,
            customSites: SettingsStore.shared.activeCustomMediaSites
        )
        guard !targets.isEmpty else {
            finish(results: [:], inconclusive: [])
            return
        }
        isRunning = true

        var results: [String: Status] = [:]
        var inconclusive: Set<String> = []
        let lock = NSLock()
        let group = DispatchGroup()
        for target in targets {
            group.enter()
            check(url: target.url) { status, offline in
                lock.lock()
                results[target.key] = status
                if offline { inconclusive.insert(target.key) }
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.finish(results: results, inconclusive: inconclusive)
        }
    }

    func status(forKey key: String) -> Status? { statuses[key] }

    // MARK: - Internals

    struct Target {
        let key: String
        let url: URL
    }

    static func targets(services: [StreamingService], customSites: [CustomMediaSite]) -> [Target] {
        var targets: [Target] = []
        for service in services {
            // The service only exposes a search URL; probe its origin.
            let searchURL = service.searchURL("test")
            if let host = searchURL.host, let url = URL(string: "https://\(host)") {
                targets.append(Target(key: service.id, url: url))
            }
        }
        for site in customSites {
            if let url = site.homepageURL {
                targets.append(Target(key: site.id.uuidString, url: url))
            }
        }
        return targets
    }

    // One retry after a short pause, so a single dropped request or slow
    // answer is not reported as a dead site.
    // The flag is true when the failure was this Mac being offline.
    private func check(url: URL, completion: @escaping (Status, Bool) -> Void) {
        checkOnce(url: url) { [weak self] status, offline in
            guard !status.ok, let self else { return completion(status, offline) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                self.checkOnce(url: url, completion: completion)
            }
        }
    }

    private func checkOnce(url: URL, completion: @escaping (Status, Bool) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        session.dataTask(with: request) { _, response, error in
            let status: Status
            let offline = error.map(Self.isInconclusive) ?? false
            if let error {
                status = Status(ok: false, detail: error.localizedDescription, date: Date())
            } else if let http = response as? HTTPURLResponse {
                let ok = Self.isReachable(statusCode: http.statusCode)
                status = Status(
                    ok: ok,
                    detail: ok ? "Reachable" : "Server answered HTTP \(http.statusCode)",
                    date: Date()
                )
            } else {
                status = Status(ok: true, detail: "Reachable", date: Date())
            }
            completion(status, offline)
        }.resume()
    }

    // Reachable means the server answered like a live site. Auth walls and
    // bot blockers (401/403/405/429) still prove the domain is alive; what we
    // are hunting is dead or rotated domains (DNS failures, 404/410, 5xx).
    static func isReachable(statusCode: Int) -> Bool {
        switch statusCode {
        case 200..<400: return true
        case 401, 403, 405, 429: return true
        default: return false
        }
    }

    // Errors that say this Mac had no network (just woken, Wi-Fi dropped),
    // which tell us nothing about whether the site itself is alive.
    static func isInconclusive(_ error: Error) -> Bool {
        let inconclusive: Set<Int> = [
            NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
            NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff,
            NSURLErrorCallIsActive, NSURLErrorCannotLoadFromNetwork,
        ]
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && inconclusive.contains(nsError.code)
    }

    // The statuses to keep after a check, or nil when the whole check looks
    // like an offline moment and the last real results should stand. A site
    // whose own check was inconclusive keeps its previous status (or stays
    // unflagged if it has none).
    static func merge(
        previous: [String: Status], fresh: [String: Status], inconclusive: Set<String>
    ) -> [String: Status]? {
        let conclusive = fresh.filter { !inconclusive.contains($0.key) }
        if conclusive.isEmpty, !fresh.isEmpty { return nil }
        // Every site failing at once means this Mac was offline, not that the
        // whole internet died. Counted over every fetched site, so a wake-up
        // mix of "not connected" and "timed out" still reads as offline.
        if fresh.count > 1, fresh.values.allSatisfy({ !$0.ok }) { return nil }
        var merged = conclusive
        for key in inconclusive where fresh[key] != nil {
            if let old = previous[key] { merged[key] = old }
        }
        return merged
    }

    private func finish(results: [String: Status], inconclusive: Set<String>) {
        // Offline: keep the last real results and try again at the next poll.
        guard let merged = Self.merge(previous: statuses, fresh: results, inconclusive: inconclusive) else {
            isRunning = false
            lastCheckLooksOffline = true
            return
        }
        lastCheckLooksOffline = false
        statuses = merged
        lastRun = Date()
        isRunning = false
        if let data = try? JSONEncoder().encode(merged) {
            defaults.set(data, forKey: "linkCheckStatuses")
        }
        defaults.set(lastRun, forKey: "linkCheckLastRun")
        // Every check cycle also re-proves the learned search mechanisms.
        reverifyLearnedSearches()
    }
}
