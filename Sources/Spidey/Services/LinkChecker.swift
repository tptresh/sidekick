import Foundation

// Periodically verifies that the streaming services and custom media sites
// still resolve, so dead domains get flagged in results and Preferences.
final class LinkChecker: ObservableObject {
    static let shared = LinkChecker()

    struct Status: Codable, Equatable {
        var ok: Bool
        var detail: String
        var date: Date
    }

    // "Every couple of days" per the feature request.
    static let checkInterval: TimeInterval = 3 * 24 * 60 * 60
    private static let pollInterval: TimeInterval = 6 * 60 * 60

    @Published private(set) var statuses: [String: Status]
    @Published private(set) var lastRun: Date?
    @Published private(set) var isRunning = false

    private let defaults = UserDefaults.standard
    private var timer: Timer?

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
    }

    func runIfDue() {
        if let lastRun, Date().timeIntervalSince(lastRun) < Self.checkInterval { return }
        checkNow()
    }

    func checkNow() {
        guard !isRunning else { return }
        let targets = Self.targets(
            services: SettingsStore.shared.activeStreamingServices,
            customSites: SettingsStore.shared.validCustomMediaSites
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
