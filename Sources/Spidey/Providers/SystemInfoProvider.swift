import AppKit
import Darwin
import IOKit.ps

// "ip" for local and public addresses, "battery" for charge state, and
// "disk"/"storage" for free space. Rows copy their value.
enum SystemInfoProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        switch lowered {
        case "ip", "ip address", "my ip":
            return ipResults()
        case "battery", "battery level", "charge":
            return batteryResults()
        case "disk", "storage", "disk space", "free space":
            return diskResults()
        default:
            return []
        }
    }

    private static func copyRow(
        _ value: String, subtitle: String, icon: String, score: Double
    ) -> ResultItem {
        ResultItem(
            title: value,
            subtitle: subtitle,
            icon: .symbol(icon),
            score: score,
            action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
            }
        )
    }

    // MARK: - IP addresses

    static func localIPAddresses() -> [(interface: String, address: String)] {
        var results: [(interface: String, address: String)] = []
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let start = first else { return [] }
        defer { freeifaddrs(first) }
        for pointer in sequence(first: start, next: { $0.pointee.ifa_next }) {
            let ifa = pointer.pointee
            guard let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  (ifa.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            results.append((String(cString: ifa.ifa_name), String(cString: host)))
        }
        // en0 (the built-in interface) first, virtual bridges and tunnels last.
        return sortedByInterface(results)
    }

    // en* interfaces (real Ethernet/Wi-Fi ports) ahead of anpi/awdl/bridge/
    // utun noise; numeric-aware within each group so en0 precedes en1.
    static func sortedByInterface(
        _ addresses: [(interface: String, address: String)]
    ) -> [(interface: String, address: String)] {
        addresses.sorted { a, b in
            let aEn = a.interface.hasPrefix("en")
            let bEn = b.interface.hasPrefix("en")
            if aEn != bEn { return aEn }
            return a.interface.localizedStandardCompare(b.interface) == .orderedAscending
        }
    }

    private static func ipResults() -> [ResultItem] {
        var items: [ResultItem] = []
        var score = 955.0
        for (interface, address) in localIPAddresses() {
            items.append(copyRow(
                address,
                subtitle: "Local IP on \(interface). Return copies it.",
                icon: "network", score: score
            ))
            score -= 1
        }
        if items.isEmpty {
            items.append(ResultItem(
                title: "No local IP address",
                subtitle: "No active network interface found",
                icon: .symbol("network.slash"), score: 955, action: {}
            ))
        }
        if let publicIP = PublicIPStore.shared.address {
            items.append(copyRow(
                publicIP, subtitle: "Public IP. Return copies it.",
                icon: "globe", score: score
            ))
        } else if PublicIPStore.shared.isUnavailable {
            items.append(ResultItem(
                title: "Public IP: unavailable",
                subtitle: "Lookup via ipify.org failed. Return retries now.",
                icon: .symbol("globe"), score: score,
                action: { PublicIPStore.shared.retry() }
            ))
        } else {
            PublicIPStore.shared.refreshIfStale()
            items.append(ResultItem(
                title: "Public IP: fetching…",
                subtitle: "Looking it up via ipify.org",
                icon: .symbol("globe"), score: score, action: {}
            ))
        }
        return items
    }

    // MARK: - Battery

    static func batteryStatus() -> (percent: Int, charging: Bool, source: String)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let state = info[kIOPSPowerSourceStateKey] as? String ?? ""
            return (current * 100 / max, charging, state)
        }
        return nil
    }

    private static func batteryResults() -> [ResultItem] {
        guard let status = batteryStatus() else {
            return [ResultItem(
                title: "No battery",
                subtitle: "This Mac has no battery to report on",
                icon: .symbol("powerplug"), score: 955, action: {}
            )]
        }
        let onAC = status.source == kIOPSACPowerValue
        let state = status.charging ? "charging"
            : (onAC ? "on AC power, not charging" : "on battery")
        let symbol: String
        switch (status.charging, status.percent) {
        case (true, _): symbol = "battery.100.bolt"
        case (_, ..<20): symbol = "battery.25"
        case (_, ..<60): symbol = "battery.50"
        default: symbol = "battery.100"
        }
        return [copyRow(
            "\(status.percent)%",
            subtitle: "Battery is \(state). Return copies the percentage.",
            icon: symbol, score: 955
        )]
    }

    // MARK: - Disk

    static func diskSpace() -> (free: Int64, total: Int64)? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
        ]), let free = values.volumeAvailableCapacityForImportantUsage,
            let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
    }

    private static func diskResults() -> [ResultItem] {
        guard let space = diskSpace() else { return [] }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let free = formatter.string(fromByteCount: space.free)
        let total = formatter.string(fromByteCount: space.total)
        return [copyRow(
            "\(free) free of \(total)",
            subtitle: "Startup disk. Return copies it.",
            icon: "internaldrive", score: 955
        )]
    }
}

// The public IP, cached for five minutes. Fetch completion posts the existing
// favicon notification, which QueryEngine already observes to re-run providers,
// so the "fetching…" row fills in without any engine changes.
final class PublicIPStore {
    static let shared = PublicIPStore()

    private(set) var cached: String?
    private var fetchedAt: Date?
    private var failedAt: Date?
    private var fetching = false
    private let failureBackoff: TimeInterval = 60

    var address: String? {
        guard let fetchedAt, Date().timeIntervalSince(fetchedAt) < 5 * 60 else { return nil }
        return cached
    }

    // A recent lookup failed and its backoff hasn't elapsed: show the
    // "unavailable" row instead of retrying on every keystroke.
    var isUnavailable: Bool {
        guard address == nil, let failedAt else { return false }
        return Date().timeIntervalSince(failedAt) < failureBackoff
    }

    func refreshIfStale() {
        guard address == nil, !isUnavailable else { return }
        refresh()
    }

    // Return on the "unavailable" row: retry immediately, ignoring the backoff.
    func retry() {
        refresh()
    }

    private func refresh() {
        guard !fetching, let url = URL(string: "https://api.ipify.org") else { return }
        fetching = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.fetching = false
                if let data,
                   let text = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty, text.count < 64 {
                    self.cached = text
                    self.fetchedAt = Date()
                    self.failedAt = nil
                } else {
                    // Cache the failure too, so an offline Mac doesn't show a
                    // permanent "fetching…" row or retry per keystroke.
                    self.failedAt = Date()
                }
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }.resume()
    }
}
