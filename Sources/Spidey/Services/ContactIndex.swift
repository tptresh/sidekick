import AppKit
import Contacts

// The whole address book, held in memory so a bare first name ("claire") can
// be matched on every keystroke. Asking CNContactStore per typed term costs an
// XPC round trip, which is why ambient lookups used to be limited to two-word
// queries; loading the book once instead makes a one-word match free and lets
// every field a card carries (numbers, addresses, sites, birthday, photo) turn
// into a row.
//
// Loading runs on a background queue the first time anything asks. The index
// reloads when the system reports the address book changed, and posts the
// shared refresh notification so a visible query re-runs against it.
final class ContactIndex {
    static let shared = ContactIndex()

    enum State: Equatable {
        case idle       // nothing asked for the book yet
        case loading
        case ready
        case failed     // the store threw, usually a stale TCC grant
    }

    private let queue = DispatchQueue(label: "dev.opensource.spidey.contactindex", qos: .userInitiated)
    private let lock = NSLock()
    private var cards: [ContactCard] = []
    private var state: State = .idle
    private var loadedAt: Date?
    private var observingChanges = false
    private var pendingReload: DispatchWorkItem?
    // Photos are pulled per card only when a row for that card is shown; a
    // whole address book of thumbnails is a lot of pixels to hold for nothing.
    // Main thread only, since rows are built there.
    private var photos: [String: NSImage] = [:]
    private var photoMisses: Set<String> = []
    private var photosInFlight: Set<String> = []
    // The book rarely changes without a change notification, but a long
    // uptime shouldn't be able to drift forever.
    private let staleAfter: TimeInterval = 1_800

    // MARK: - Loading

    var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cards.count
    }

    // Safe to call from anywhere and as often as you like: it starts at most
    // one load, and does nothing at all without Contacts access (so an
    // ambient query never provokes a permission prompt).
    func warmUp() {
        guard Bundle.main.bundleIdentifier != nil,
              CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }
        startObservingChangesIfNeeded()

        lock.lock()
        let stale = loadedAt.map { Date().timeIntervalSince($0) > staleAfter } ?? true
        let shouldLoad = state != .loading && (state == .idle || stale || (state == .failed && stale))
        if shouldLoad { state = .loading }
        lock.unlock()
        guard shouldLoad else { return }

        queue.async { [weak self] in self?.load() }
    }

    // Reloads even when the current index is fresh (used after a grant lands).
    func reload() {
        lock.lock()
        loadedAt = nil
        if state != .loading { state = .idle }
        lock.unlock()
        warmUp()
    }

    private func load() {
        let loaded = Self.fetchAll()
        lock.lock()
        if let loaded {
            cards = loaded
            state = .ready
            loadedAt = Date()
        } else {
            state = .failed
            loadedAt = Date()
        }
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            // A changed book may have gained photos where it had none.
            self?.photoMisses.removeAll()
            NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
        }
    }

    // nil means the store threw, which is a real error and not an empty book.
    private static func fetchAll() -> [ContactCard]? {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true
        // A fresh store per load: an instance created before access was
        // granted can keep reporting authorization errors afterwards.
        let store = CNContactStore()
        var result: [ContactCard] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                if let card = ContactCard(contact: contact) { result.append(card) }
            }
        } catch {
            return nil
        }
        return result
    }

    private func startObservingChangesIfNeeded() {
        lock.lock()
        let already = observingChanges
        observingChanges = true
        lock.unlock()
        guard !already else { return }
        NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            // A sync can fire this many times in a row; reload once it settles.
            self.lock.lock()
            self.pendingReload?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.reload() }
            self.pendingReload = work
            self.lock.unlock()
            self.queue.asyncAfter(deadline: .now() + 2, execute: work)
        }
    }

    // MARK: - Matching

    // Best matches first. `minimumScore` lets an ambient one-word query insist
    // on a real name match while an explicit search accepts loose ones.
    func match(_ term: String, limit: Int, minimumScore: Double) -> [ContactCard] {
        let needle = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        lock.lock()
        let snapshot = cards
        lock.unlock()

        var scored: [(card: ContactCard, score: Double)] = []
        for card in snapshot {
            guard let score = Self.score(needle: needle, card: card), score >= minimumScore else { continue }
            scored.append((card, score))
        }
        scored.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.card.name.localizedCaseInsensitiveCompare($1.card.name) == .orderedAscending
        }
        return scored.prefix(limit).map(\.card)
    }

    func card(named name: String) -> ContactCard? {
        let wanted = name.lowercased()
        lock.lock()
        defer { lock.unlock() }
        return cards.first { $0.name.lowercased() == wanted }
    }

    // Everything is precomputed and lowercased at load time, so a keystroke
    // only does string comparisons. The ladder mirrors Fuzzy's: an exact name
    // beats a name prefix beats a word prefix beats a substring.
    // `needle` must already be lowercased and trimmed.
    static func score(needle: String, card: ContactCard) -> Double? {
        var best: Double?
        func offer(_ value: Double) {
            if value > (best ?? 0) { best = value }
        }

        for whole in card.wholes {
            if whole == needle { return 1.0 }
            if whole.hasPrefix(needle) { offer(0.9) }
        }
        // A whole name part on its own: "claire" for Claire Bennett. Treated
        // as good as an exact card name, since that is how people are called.
        for word in card.words where word == needle {
            offer(0.95)
            break
        }
        if (best ?? 0) < 0.9 {
            for word in card.words where word.hasPrefix(needle) {
                offer(0.8)
                break
            }
        }
        // "cb" finds Claire Bennett, but only once it can't be a name prefix.
        if (best ?? 0) < 0.8, needle.count >= 2, card.initials.hasPrefix(needle) { offer(0.72) }
        if (best ?? 0) < 0.72, needle.count >= 3 {
            for whole in card.wholes where whole.contains(needle) {
                offer(0.7)
                break
            }
        }
        // Reaching a person by what you know of them: part of an address, or
        // enough digits of a number to be deliberate.
        if needle.contains("@") {
            for email in card.loweredEmails where email.contains(needle) {
                offer(0.75)
                break
            }
        }
        let needleDigits = needle.filter(\.isNumber)
        if needleDigits.count >= 4, needleDigits.count == needle.filter({ !" -()+.".contains($0) }).count {
            for digits in card.phoneDigits where digits.contains(needleDigits) {
                offer(0.75)
                break
            }
        }
        // An employer is a weak signal: kept below the ambient threshold so it
        // only ever surfaces in an explicit contact search.
        if (best ?? 0) < 0.65, !card.loweredOrganization.isEmpty,
           card.loweredOrganization.contains(needle) {
            offer(0.6)
        }
        return best
    }

    // MARK: - Photos

    // Main thread only. Returns the cached photo, or nil while it loads.
    func photo(for card: ContactCard) -> NSImage? {
        guard card.hasPhoto else { return nil }
        if let cached = photos[card.id] { return cached }
        guard !photoMisses.contains(card.id), !photosInFlight.contains(card.id) else { return nil }
        photosInFlight.insert(card.id)
        let id = card.id
        queue.async { [weak self] in
            let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor]
            let data = try? CNContactStore().unifiedContact(withIdentifier: id, keysToFetch: keys)
                .thumbnailImageData
            let image = data.flatMap { Self.circularImage(from: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.photosInFlight.remove(id)
                guard let image else {
                    self.photoMisses.insert(id)
                    return
                }
                self.photos[id] = image
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }
        return nil
    }

    // Contact photos are arbitrary rectangles; rows want the round avatar
    // every other Apple app shows, so center-crop to a square and clip.
    private static func circularImage(from data: Data) -> NSImage? {
        guard let source = NSImage(data: data) else { return nil }
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let side = min(sourceSize.width, sourceSize.height)
        let crop = NSRect(
            x: (sourceSize.width - side) / 2,
            y: (sourceSize.height - side) / 2,
            width: side, height: side
        )
        let output = NSSize(width: 64, height: 64)
        let image = NSImage(size: output)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: output)
        NSBezierPath(ovalIn: rect).addClip()
        source.draw(in: rect, from: crop, operation: .copy, fraction: 1)
        image.unlockFocus()
        image.size = NSSize(width: 32, height: 32)
        return image
    }
}
