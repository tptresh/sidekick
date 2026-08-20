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
        }
        // Whenever a plain custom link is added or edited (debounced past the
        // keystrokes), try to find the site's own search page for it.
        sitesSubscription = SettingsStore.shared.$customMediaSites
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] sites in
                self?.discoverSearchTemplates(for: sites)
            }
    }

    // Find candidate search URLs for the site, then prove one against the
    // live site in a hidden web view before storing it. Only a candidate
    // where searching really returns results is ever used.
    func discoverSearchTemplates(for sites: [CustomMediaSite]) {
        for site in sites {
            guard site.isValid, !site.hasSearchTemplate, site.activeDiscoveredTemplate == nil,
                  let homepage = site.homepageURL, let host = site.host,
                  !discoveringHosts.contains(host), !undiscoverableHosts.contains(host)
            else { continue }
            discoveringHosts.insert(host)
            SearchTemplateFinder.candidates(homepage: homepage, session: session) { candidates in
                DispatchQueue.main.async {
                    guard !candidates.isEmpty else {
                        self.finishDiscovery(siteID: site.id, host: host, template: nil)
                        return
                    }
                    SearchTemplateVerifier.shared.firstWorking(from: candidates) { template in
                        self.finishDiscovery(siteID: site.id, host: host, template: template)
                    }
                }
            }
        }
    }

    private func finishDiscovery(siteID: UUID, host: String, template: String?) {
        discoveringHosts.remove(host)
        guard let template else {
            undiscoverableHosts.insert(host)
            return
        }
        let store = SettingsStore.shared
        guard let index = store.customMediaSites.firstIndex(where: {
            $0.id == siteID && $0.host == host
        }) else { return }
        store.customMediaSites[index].discoveredTemplate = template
    }

    func runIfDue() {
        if let lastRun, Date().timeIntervalSince(lastRun) < Self.checkInterval { return }
        checkNow()
    }

    func checkNow() {
        guard !isRunning else { return }
        let targets = Self.targets(
            services: SettingsStore.shared.activeStreamingServices,
            customSites: SettingsStore.shared.activeCustomMediaSites
        )
        guard !targets.isEmpty else {
            finish(results: [:])
            return
        }
        isRunning = true

        var results: [String: Status] = [:]
        let lock = NSLock()
        let group = DispatchGroup()
        for target in targets {
            group.enter()
            check(url: target.url) { status in
                lock.lock()
                results[target.key] = status
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.finish(results: results)
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

    private func check(url: URL, completion: @escaping (Status) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        session.dataTask(with: request) { _, response, error in
            let status: Status
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
            completion(status)
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

    private func finish(results: [String: Status]) {
        statuses = results
        lastRun = Date()
        isRunning = false
        if let data = try? JSONEncoder().encode(results) {
            defaults.set(data, forKey: "linkCheckStatuses")
        }
        defaults.set(lastRun, forKey: "linkCheckLastRun")
    }
}
