import AppKit
import Contacts

// "contact tanush" (dedicated, more rows) or typing a two-word name (ambient,
// max 2 matches): searches the macOS address book. Each match yields action
// rows - Message, Call, FaceTime, Email - whose Return performs the action and
// Cmd+Return copies the number or address; each carries a ranking key so the
// engine learns which action the user actually picks for a name. A matched
// person ranks above site and app rows so typing a contact's name puts the
// person first, not a website. Fetches run on a background queue against
// CNContactStore with an in-memory per-term cache; when a fetch lands it posts
// the shared refresh notification so the visible query re-runs against the
// warm cache.
//
// Authorization mirrors FindMyProvider's row-driven flow, but only for the
// explicit "contact" keyword - an ambient name-shaped query stays silent when
// access is missing so ordinary app searches ("safari") don't grow a
// permission row. Under a bare `swift build` binary there is no Info.plist,
// so TCC would deny us outright; that case gets a friendly "run make app" row.
enum ContactsProvider {
    struct Person {
        let name: String
        let phones: [(label: String, value: String)]
        let emails: [(label: String, value: String)]
    }

    // MARK: - Cache

    private static let fetchQueue = DispatchQueue(label: "dev.opensource.spidey.contacts", qos: .userInitiated)
    private static let lock = NSLock()
    // people == nil records a failed fetch, kept separately from "no matches"
    // so an error never masquerades as an empty address book.
    private static var cache: [String: (people: [Person]?, fetchedAt: Date)] = [:]
    private static var inFlight: Set<String> = []
    private static var pendingFetch: DispatchWorkItem?
    private static let cacheTTL: TimeInterval = 300
    private static let failureTTL: TimeInterval = 10
    private static let maxCacheEntries = 64
    private static let debounceInterval: TimeInterval = 0.3
    private static var observingChanges = false

    // MARK: - Entry point

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        let dedicated: Bool
        let term: String
        if lowered == "contact" || lowered == "contacts" {
            return gateRows(dedicated: true) ?? [ResultItem(
                title: "Search contacts",
                subtitle: "Type a name, e.g. contact tanush",
                icon: .symbol("person.crop.circle"),
                score: 950,
                action: {}
            )]
        } else if lowered.hasPrefix("contact ") {
            dedicated = true
            term = String(trimmed.dropFirst("contact ".count)).trimmingCharacters(in: .whitespaces)
        } else if looksLikeName(trimmed) {
            dedicated = false
            term = trimmed
        } else {
            return []
        }
        guard !term.isEmpty else { return [] }

        if let gate = gateRows(dedicated: dedicated) {
            return gate
        }

        startObservingChangesIfNeeded()
        guard let entry = cachedEntry(for: term) else {
            scheduleFetch(term: term)
            return dedicated ? [ResultItem(
                title: "Searching contacts\u{2026}",
                subtitle: "Looking for \u{201C}\(term)\u{201D} in your address book",
                icon: .symbol("person.crop.circle"),
                score: 950,
                action: {}
            )] : []
        }

        guard let people = entry else {
            // The fetch itself failed even though the authorization status
            // reads as granted. The usual cause is a stale grant: each
            // make app re-signs the bundle, so an old grant in System
            // Settings no longer matches the running binary.
            return dedicated ? [ResultItem(
                title: "Contacts search failed",
                subtitle: "Return opens Privacy settings - toggle Sidekick off and on there, then try again",
                icon: .symbol("exclamationmark.triangle"),
                score: 950,
                action: { openPrivacySettings() }
            )] : []
        }

        if people.isEmpty {
            return dedicated ? [ResultItem(
                title: "No contacts match \u{201C}\(term)\u{201D}",
                subtitle: "Try a first or last name",
                icon: .symbol("person.crop.circle.badge.questionmark"),
                score: 950,
                action: {}
            )] : []
        }

        return rows(
            for: dedicated ? Array(people.prefix(8)) : Array(people.prefix(2)),
            allDetails: dedicated,
            // Ambient: a name that really matches a contact outranks every
            // site row (tier 3 strong match tops out at 945) and app row
            // (max 900), so the person is option one, not a website.
            baseScore: dedicated ? 950 : 960
        )
    }

    // MARK: - Authorization gate

    // nil means access is usable; otherwise the rows to show instead.
    private static func gateRows(dedicated: Bool) -> [ResultItem]? {
        guard Bundle.main.bundleIdentifier != nil else {
            // No bundle, no Info.plist usage string, no TCC prompt possible.
            return dedicated ? [ResultItem(
                title: "Contacts search requires the bundled app",
                subtitle: "Run make app \u{2014} a bare swift build binary can't be granted Contacts access",
                icon: .symbol("shippingbox"),
                score: 950,
                action: {}
            )] : []
        }
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            return dedicated ? [ResultItem(
                title: "Search contacts: needs Contacts access",
                subtitle: "Return opens the permission prompt, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { requestAccess() }
            )] : []
        case .denied, .restricted:
            return dedicated ? [ResultItem(
                title: "Search contacts: Contacts access denied",
                subtitle: "Return opens Privacy settings \u{2014} enable the app, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { openPrivacySettings() }
            )] : []
        default:
            return nil
        }
    }

    private static func requestAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { _, _ in
            // Keep the store alive until the request resolves.
            _ = store
            // Drop results cached while access was missing, then re-run the
            // visible query so the grant takes effect at once.
            lock.lock()
            cache.removeAll()
            lock.unlock()
            NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
        }
    }

    private static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Name detection

    // A short run of purely alphabetic words reads like a person's name; digits
    // or symbols mean it's math, a URL, or a command with arguments. Ambient
    // lookups need at least two words ("tanush pandey") so every single-word
    // query on the way to an app or command doesn't cost a Contacts XPC fetch;
    // single-word lookups go through the explicit "contact " keyword.
    static func looksLikeName(_ query: String) -> Bool {
        guard query.count >= 3, query.count <= 40 else { return false }
        let words = query.split(separator: " ")
        guard (2...3).contains(words.count) else { return false }
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "'\u{2019}-."))
        for word in words {
            guard word.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        }
        return true
    }

    // MARK: - Rows

    // The number Messages/FaceTime most likely reach: prefer a mobile line.
    private static func primaryPhone(of person: Person) -> (label: String, value: String)? {
        person.phones.first {
            let label = $0.label.lowercased()
            return label.contains("mobile") || label.contains("iphone")
        } ?? person.phones.first
    }

    private static func rows(for people: [Person], allDetails: Bool, baseScore: Double) -> [ResultItem] {
        var items: [ResultItem] = []
        var personScore = baseScore
        for person in people {
            let phone = primaryPhone(of: person)
            let email = person.emails.first
            // iMessage and FaceTime reach a phone number or an Apple ID email.
            let reachable = phone?.value ?? email?.value
            let key = person.name.lowercased()
            var score = personScore

            if let reachable {
                items.append(ResultItem(
                    title: "Message \(person.name)",
                    subtitle: "\(reachable) \u{00B7} Return opens Messages \u{00B7} \u{2318}Return copies",
                    icon: .symbol("message.fill"),
                    score: score,
                    rankingKey: "contact:message:\(key)",
                    secondaryAction: { copy(reachable) },
                    action: { message(reachable) }
                ))
                score -= 1
            }
            if let phone {
                items.append(ResultItem(
                    title: "Call \(person.name)",
                    subtitle: "\(phone.value) \u{00B7} Return calls \u{00B7} \u{2318}Return copies",
                    icon: .symbol("phone.fill"),
                    score: score,
                    rankingKey: "contact:call:\(key)",
                    secondaryAction: { copy(phone.value) },
                    action: { call(phone.value) }
                ))
                score -= 1
            }
            if let reachable {
                items.append(ResultItem(
                    title: "FaceTime \(person.name)",
                    subtitle: "\(reachable) \u{00B7} Return starts the call \u{00B7} \u{2318}Return copies",
                    icon: .symbol("video.fill"),
                    score: score,
                    rankingKey: "contact:facetime:\(key)",
                    secondaryAction: { copy(reachable) },
                    action: { faceTime(reachable) }
                ))
                score -= 1
            }
            if let email {
                items.append(ResultItem(
                    title: "Email \(person.name)",
                    subtitle: "\(email.value) \u{00B7} Return opens Mail \u{00B7} \u{2318}Return copies",
                    icon: .symbol("envelope.fill"),
                    score: score,
                    rankingKey: "contact:email:\(key)",
                    secondaryAction: { copy(email.value) },
                    action: { compose(email.value) }
                ))
                score -= 1
            }

            // Dedicated searches also list any further numbers and addresses
            // as copy rows, below the action rows.
            if allDetails {
                for extra in person.phones where extra.value != phone?.value {
                    let label = extra.label.isEmpty ? "" : "\(extra.label) \u{00B7} "
                    items.append(ResultItem(
                        title: "\(person.name) - \(extra.value)",
                        subtitle: "\(label)Return copies the number \u{00B7} \u{2318}Return calls it",
                        icon: .symbol("phone"),
                        score: score,
                        secondaryAction: { call(extra.value) },
                        action: { copy(extra.value) }
                    ))
                    score -= 1
                }
                for extra in person.emails where extra.value != email?.value {
                    let label = extra.label.isEmpty ? "" : "\(extra.label) \u{00B7} "
                    items.append(ResultItem(
                        title: "\(person.name) - \(extra.value)",
                        subtitle: "\(label)Return copies the address \u{00B7} \u{2318}Return opens Mail",
                        icon: .symbol("envelope"),
                        score: score,
                        secondaryAction: { compose(extra.value) },
                        action: { copy(extra.value) }
                    ))
                    score -= 1
                }
            }
            // Room for every row of one person before the next one starts.
            personScore -= 10
        }
        return items
    }

    private static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func call(_ number: String) {
        let digits = number.filter { "0123456789+".contains($0) }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        NSWorkspace.shared.open(url)
    }

    // Messages and FaceTime take a phone number or an email Apple ID.
    private static func urlTarget(for recipient: String) -> String? {
        if recipient.contains("@") {
            return recipient.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? recipient
        }
        let digits = recipient.filter { "0123456789+".contains($0) }
        return digits.isEmpty ? nil : digits
    }

    private static func message(_ recipient: String) {
        guard let target = urlTarget(for: recipient),
              let url = URL(string: "imessage://\(target)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func faceTime(_ recipient: String) {
        guard let target = urlTarget(for: recipient),
              let url = URL(string: "facetime://\(target)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func compose(_ email: String) {
        let escaped = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        guard let url = URL(string: "mailto:\(escaped)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Fetching

    // Outer nil: no fresh entry, a fetch is needed. Inner nil: the last
    // fetch failed (kept only briefly so a transient error retries soon).
    private static func cachedEntry(for term: String) -> [Person]?? {
        let key = term.lowercased()
        lock.lock()
        defer { lock.unlock() }
        guard let entry = cache[key] else { return nil }
        let ttl = entry.people == nil ? failureTTL : cacheTTL
        guard Date().timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return .some(entry.people)
    }

    private static func scheduleFetch(term: String) {
        let key = term.lowercased()
        lock.lock()
        let alreadyRunning = inFlight.contains(key)
        // Debounce: a newer keystroke replaces the pending lookup, so only
        // the term the user settled on reaches CNContactStore instead of one
        // XPC fetch per typed prefix.
        if !alreadyRunning {
            pendingFetch?.cancel()
            let work = DispatchWorkItem { performFetch(term: term) }
            pendingFetch = work
            fetchQueue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
        lock.unlock()
    }

    private static func performFetch(term: String) {
        let key = term.lowercased()
        lock.lock()
        let alreadyRunning = inFlight.contains(key)
        if !alreadyRunning { inFlight.insert(key) }
        lock.unlock()
        guard !alreadyRunning else { return }

        let people = fetchPeople(matching: term)
        lock.lock()
        // Keep the per-term cache bounded; dropping it wholesale is fine
        // since a fetch repopulates the live term in one go.
        if cache.count >= maxCacheEntries, cache[key] == nil {
            cache.removeAll()
        }
        cache[key] = (people, Date())
        inFlight.remove(key)
        lock.unlock()
        // Nudge the query engine to re-run against the warm cache.
        NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
    }

    // nil means the store threw (a real error), distinct from no matches.
    private static func fetchPeople(matching term: String) -> [Person]? {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
        let predicate = CNContact.predicateForContacts(matchingName: term)
        // A fresh store per fetch: an instance created before access was
        // granted can keep reporting authorization errors afterwards.
        let store = CNContactStore()
        guard let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keys) else {
            return nil
        }
        return contacts.compactMap { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty else { return nil }
            let phones = contact.phoneNumbers.map { labeled -> (String, String) in
                (localizedLabel(labeled.label), labeled.value.stringValue)
            }
            let emails = contact.emailAddresses.map { labeled -> (String, String) in
                (localizedLabel(labeled.label), labeled.value as String)
            }
            guard !phones.isEmpty || !emails.isEmpty else { return nil }
            return Person(name: name, phones: phones, emails: emails)
        }
    }

    private static func localizedLabel(_ label: String?) -> String {
        guard let label, !label.isEmpty else { return "" }
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    }

    private static func startObservingChangesIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !observingChanges else { return }
        observingChanges = true
        NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange, object: nil, queue: nil
        ) { _ in
            lock.lock()
            cache.removeAll()
            lock.unlock()
        }
    }
}
