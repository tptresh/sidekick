import AppKit
import Contacts

// Everything the address book can do, from the search field. Three ways in:
//
//  - ambient: typing a name ("claire", "claire bennett") puts the person and
//    her usual actions in the list, above sites and apps;
//  - a verb ("call claire", "message claire", "email claire", "facetime
//    claire") narrows the rows to that one way of reaching her;
//  - "contact claire" is the full card: every number, address, site, the
//    birthday, and the card itself in Contacts. Bare "contact" lists the
//    people you reach for most.
//
// Rows carry a ranking key per person and per action, so the engine learns
// that "claire" means Message and "dad" means Call. Matching runs against
// ContactIndex, an in-memory copy of the book, which is what makes a bare
// first name affordable on every keystroke.
//
// Authorization is row-driven, but only for the explicit "contact" keyword:
// an ambient or verb query stays silent without access so ordinary searches
// ("safari") never grow a permission row. Under a bare `swift build` binary
// there is no Info.plist, so TCC would deny us outright; that case gets a
// friendly "run make app" row.
enum ContactsProvider {
    // Which of a person's rows the query asked for.
    enum Verb {
        case all
        case message
        case call
        case faceTime
        case email
    }

    // How much of a person to show.
    enum Detail {
        case ambient    // the usual actions, card row last
        case full       // card row first, then every field
    }

    // MARK: - Entry point

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        if lowered == "contact" || lowered == "contacts" {
            return gateRows(dedicated: true) ?? overviewRows()
        }

        var verb = Verb.all
        var dedicated = false
        var term = ""
        if let rest = value(after: ["contact", "contacts"], in: trimmed) {
            dedicated = true
            term = rest
        } else if let rest = value(after: ["call", "ring", "dial"], in: trimmed) {
            verb = .call
            term = rest
        } else if let rest = value(after: ["message", "msg", "text", "imessage"], in: trimmed) {
            verb = .message
            term = rest
        } else if let rest = value(after: ["email", "mail", "e-mail"], in: trimmed) {
            verb = .email
            term = rest
        } else if let rest = value(after: ["facetime", "ft"], in: trimmed) {
            verb = .faceTime
            term = rest
        } else if looksLikeName(trimmed) {
            term = trimmed
        } else {
            return []
        }
        guard !term.isEmpty else { return [] }

        // Only the explicit keyword explains itself; a verb or an ambient name
        // stays quiet rather than turning every query into a permission row.
        if let gate = gateRows(dedicated: dedicated) { return gate }
        ContactIndex.shared.warmUp()

        if dedicated { return dedicatedRows(term: term) }

        // Ambient and verb queries insist on a real name match: a prefix of
        // the card name or one of its words, nothing looser.
        let people = ContactIndex.shared.match(
            term, limit: term.contains(" ") ? 2 : 1, minimumScore: 0.8
        )
        guard let first = people.first else { return [] }

        // An exact name outranks every site row (a tier 3 strong match tops
        // out at 945) and every app row (max 900), so the person is option
        // one. A mere prefix sits just under the apps: "cla" more often means
        // an app than a contact, until the ranking learns otherwise.
        let exact = (ContactIndex.score(needle: term.lowercased(), card: first) ?? 0) >= 0.95
            && !first.isCompany
        var items = rows(for: first, verb: verb, detail: .ambient, baseScore: exact ? 960 : 880)
        for other in people.dropFirst() {
            items.append(cardRow(for: other, score: (exact ? 960 : 880) - 50))
        }
        return items
    }

    // "contact claire" -> "claire". nil when the query isn't that keyword.
    private static func value(after keywords: [String], in query: String) -> String? {
        let lowered = query.lowercased()
        for keyword in keywords where lowered.hasPrefix(keyword + " ") {
            let rest = String(query.dropFirst(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }
        return nil
    }

    // MARK: - Dedicated search

    private static func dedicatedRows(term: String) -> [ResultItem] {
        let index = ContactIndex.shared
        let people = index.match(term, limit: 5, minimumScore: 0.5)
        if people.isEmpty {
            switch index.currentState {
            case .idle, .loading:
                return [ResultItem(
                    title: "Searching contacts\u{2026}",
                    subtitle: "Looking for \u{201C}\(term)\u{201D} in your address book",
                    icon: .symbol("person.crop.circle"),
                    score: 950,
                    action: {}
                )]
            case .failed:
                // Authorization reads as granted but the store still refused.
                // The usual cause is a stale grant: each make app re-signs the
                // bundle, so an old grant no longer matches this binary.
                return [ResultItem(
                    title: "Contacts search failed",
                    subtitle: "Return opens Privacy settings - toggle Sidekick off and on there, then try again",
                    icon: .symbol("exclamationmark.triangle"),
                    score: 950,
                    action: { openPrivacySettings() }
                )]
            case .ready:
                return [ResultItem(
                    title: "No contacts match \u{201C}\(term)\u{201D}",
                    subtitle: "Try a first or last name, a company, an address, or a number",
                    icon: .symbol("person.crop.circle.badge.questionmark"),
                    score: 950,
                    action: {}
                )]
            }
        }
        // The best match gets everything it has; the rest are one row each, so
        // a common surname lists the people rather than a wall of numbers.
        var items = rows(for: people[0], verb: .all, detail: .full, baseScore: 950)
        var score: Double = 880
        for person in people.dropFirst() {
            items.append(cardRow(for: person, score: score))
            score -= 1
        }
        return items
    }

    // Bare "contact": the people this search field has actually been used to
    // reach, most-used first, so the keyword is a shortcut rather than a
    // prompt to type more.
    private static func overviewRows() -> [ResultItem] {
        ContactIndex.shared.warmUp()
        let index = ContactIndex.shared
        var seen = Set<String>()
        var items: [ResultItem] = []
        var score: Double = 950
        for key in UsageStore.shared.topKeys(prefix: "contact:", limit: 24) {
            // Keys look like "contact:message:claire bennett", and rows for a
            // second number add ":<number>" after the name.
            let parts = key.split(separator: ":")
            guard parts.count >= 3 else { continue }
            let name = String(parts[2])
            guard !name.isEmpty, seen.insert(name).inserted, let card = index.card(named: name) else { continue }
            items.append(cardRow(for: card, score: score))
            score -= 1
            if items.count == 5 { break }
        }
        let known = index.count
        items.append(ResultItem(
            title: "Search contacts",
            subtitle: known > 0
                ? "\(known) contacts - type a name, a company, an address, or a number"
                : "Type a name, e.g. contact claire",
            icon: .symbol("person.crop.circle"),
            score: score - 1,
            action: {}
        ))
        return items
    }

    // MARK: - Authorization gate

    // nil means access is usable; otherwise the rows to show instead.
    private static func gateRows(dedicated: Bool) -> [ResultItem]? {
        guard Bundle.main.bundleIdentifier != nil else {
            // No bundle, no Info.plist usage string, no TCC prompt possible.
            return dedicated ? [ResultItem(
                title: "Contacts search requires the bundled app",
                subtitle: "Run make app - a bare swift build binary can't be granted Contacts access",
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
                subtitle: "Return opens Privacy settings - enable the app, then try again",
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
            // Load the book at once so the grant takes effect without another
            // keystroke; the reload posts the refresh notification itself.
            ContactIndex.shared.reload()
        }
    }

    private static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Name detection

    // A short run of purely alphabetic words reads like a person's name;
    // digits or symbols mean it's math, a URL, or a command with arguments.
    // One word is enough now that matching happens against the in-memory
    // index rather than a Contacts fetch per typed prefix.
    static func looksLikeName(_ query: String) -> Bool {
        guard query.count >= 3, query.count <= 40 else { return false }
        let words = query.split(separator: " ")
        guard (1...3).contains(words.count) else { return false }
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "'\u{2019}-."))
        for word in words {
            guard word.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        }
        return true
    }

    // MARK: - Rows

    static func rows(
        for person: ContactCard, verb: Verb, detail: Detail, baseScore: Double
    ) -> [ResultItem] {
        var items: [ResultItem] = []
        var score = baseScore
        func add(_ item: ResultItem) {
            items.append(item)
            score -= 1
        }
        func wants(_ kind: Verb) -> Bool { verb == .all || verb == kind }

        let phone = person.primaryPhone
        let email = person.primaryEmail
        let reachable = person.reachable
        let key = person.name.lowercased()

        if detail == .full {
            add(cardRow(for: person, score: score))
        }

        if wants(.message), let reachable {
            add(ResultItem(
                title: "Message \(person.name)",
                subtitle: "\(reachable) \u{00B7} Return opens Messages \u{00B7} \u{2318}Return copies",
                icon: .symbol("message.fill"),
                score: score,
                rankingKey: "contact:message:\(key)",
                secondaryAction: { copy(reachable) },
                action: { message(reachable) }
            ))
        }
        if wants(.call), let phone {
            add(ResultItem(
                title: "Call \(person.name)",
                subtitle: "\(labelled(phone)) \u{00B7} Return calls \u{00B7} \u{2318}Return copies",
                icon: .symbol("phone.fill"),
                score: score,
                rankingKey: "contact:call:\(key)",
                secondaryAction: { copy(phone.value) },
                action: { call(phone.value) }
            ))
        }
        if wants(.faceTime), let reachable {
            add(ResultItem(
                title: "FaceTime \(person.name)",
                subtitle: "\(reachable) \u{00B7} Return starts the video call \u{00B7} \u{2318}Return copies",
                icon: .symbol("video.fill"),
                score: score,
                rankingKey: "contact:facetime:\(key)",
                secondaryAction: { copy(reachable) },
                action: { faceTime(reachable) }
            ))
        }
        // The audio call is a distinct row rather than a modifier: FaceTime
        // audio is how you reach someone with no phone number at all.
        if verb == .faceTime || detail == .full, let reachable {
            add(ResultItem(
                title: "FaceTime Audio \(person.name)",
                subtitle: "\(reachable) \u{00B7} Return starts the audio call \u{00B7} \u{2318}Return copies",
                icon: .symbol("phone.arrow.up.right.fill"),
                score: score,
                rankingKey: "contact:facetimeaudio:\(key)",
                secondaryAction: { copy(reachable) },
                action: { faceTimeAudio(reachable) }
            ))
        }
        if wants(.email), let email {
            add(ResultItem(
                title: "Email \(person.name)",
                subtitle: "\(labelled(email)) \u{00B7} Return opens Mail \u{00B7} \u{2318}Return copies",
                icon: .symbol("envelope.fill"),
                score: score,
                rankingKey: "contact:email:\(key)",
                secondaryAction: { copy(email.value) },
                action: { compose(email.value) }
            ))
        }

        // Verb rows cover every matching field, not just the primary one, so
        // "call claire" can reach her work line too.
        if verb == .call || (verb == .all && detail == .full) {
            for extra in person.phones where extra.value != phone?.value {
                add(ResultItem(
                    title: "Call \(person.name) \u{00B7} \(extra.label.isEmpty ? "other" : extra.label)",
                    subtitle: "\(extra.value) \u{00B7} Return calls \u{00B7} \u{2318}Return copies",
                    icon: .symbol("phone"),
                    score: score,
                    rankingKey: "contact:call:\(key):\(extra.value)",
                    secondaryAction: { copy(extra.value) },
                    action: { call(extra.value) }
                ))
            }
        }
        if verb == .message {
            for extra in person.phones where extra.value != phone?.value {
                add(ResultItem(
                    title: "Message \(person.name) \u{00B7} \(extra.label.isEmpty ? "other" : extra.label)",
                    subtitle: "\(extra.value) \u{00B7} Return opens Messages \u{00B7} \u{2318}Return copies",
                    icon: .symbol("message"),
                    score: score,
                    rankingKey: "contact:message:\(key):\(extra.value)",
                    secondaryAction: { copy(extra.value) },
                    action: { message(extra.value) }
                ))
            }
        }
        if verb == .email || (verb == .all && detail == .full) {
            for extra in person.emails where extra.value != email?.value {
                add(ResultItem(
                    title: "Email \(person.name) \u{00B7} \(extra.label.isEmpty ? "other" : extra.label)",
                    subtitle: "\(extra.value) \u{00B7} Return opens Mail \u{00B7} \u{2318}Return copies",
                    icon: .symbol("envelope"),
                    score: score,
                    rankingKey: "contact:email:\(key):\(extra.value)",
                    secondaryAction: { copy(extra.value) },
                    action: { compose(extra.value) }
                ))
            }
        }

        if detail == .full, verb == .all {
            for address in person.addresses {
                let label = address.label.isEmpty ? "address" : address.label.lowercased()
                add(ResultItem(
                    title: "\(person.name)'s \(label) in Maps",
                    subtitle: "\(address.value) \u{00B7} Return opens Maps \u{00B7} \u{2318}Return copies",
                    icon: .symbol("mappin.and.ellipse"),
                    score: score,
                    rankingKey: "contact:map:\(key)",
                    secondaryAction: { copy(address.value) },
                    action: { openMap(address.value) }
                ))
            }
            for site in person.urls {
                add(ResultItem(
                    title: "\(person.name) \u{00B7} \(site.label.isEmpty ? "website" : site.label)",
                    subtitle: "\(site.value) \u{00B7} Return opens it \u{00B7} \u{2318}Return copies",
                    icon: .symbol("safari"),
                    score: score,
                    rankingKey: "contact:url:\(key)",
                    secondaryAction: { copy(site.value) },
                    action: { openSite(site.value) }
                ))
            }
            if let birthday = person.birthdayText {
                add(ResultItem(
                    title: "\(person.name)'s birthday \u{00B7} \(birthday)",
                    subtitle: "Return copies the date",
                    icon: .symbol("gift"),
                    score: score,
                    action: { copy(birthday) }
                ))
            }
        }

        if detail == .ambient, !items.isEmpty {
            add(cardRow(for: person, score: score))
        }
        return items
    }

    // The person themselves: photo, what they do, and the card in Contacts.
    private static func cardRow(for person: ContactCard, score: Double) -> ResultItem {
        let detail = person.subtitleDetail
        let suffix = "Return opens the card in Contacts \u{00B7} \u{2318}Return copies it"
        return ResultItem(
            title: person.name,
            subtitle: detail.isEmpty ? suffix : "\(detail) \u{00B7} \(suffix)",
            icon: ContactIndex.shared.photo(for: person).map { ResultIcon.appIcon($0) }
                ?? .symbol("person.crop.circle"),
            score: score,
            rankingKey: "contact:card:\(person.name.lowercased())",
            secondaryAction: { copy(person.plainTextCard) },
            action: { openCard(person) }
        )
    }

    private static func labelled(_ field: ContactCard.Field) -> String {
        field.label.isEmpty ? field.value : "\(field.label) \u{00B7} \(field.value)"
    }

    // MARK: - Actions

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

    private static func faceTimeAudio(_ recipient: String) {
        guard let target = urlTarget(for: recipient),
              let url = URL(string: "facetime-audio://\(target)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func compose(_ email: String) {
        let escaped = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        guard let url = URL(string: "mailto:\(escaped)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func openMap(_ address: String) {
        let escaped = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        guard let url = URL(string: "maps://?q=\(escaped)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func openSite(_ site: String) {
        let text = site.contains("://") ? site : "https://\(site)"
        guard let url = URL(string: text) else { return }
        BrowserLauncher.open(url)
    }

    // Contacts registers the addressbook scheme; the identifier carries a
    // colon (".:ABPerson"), so it has to be escaped before it can be a host.
    private static func openCard(_ person: ContactCard) {
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let escaped = person.id.addingPercentEncoding(withAllowedCharacters: unreserved) ?? person.id
        if let url = URL(string: "addressbook://\(escaped)"), NSWorkspace.shared.open(url) { return }
        if let contacts = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.AddressBook") {
            NSWorkspace.shared.openApplication(at: contacts, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
