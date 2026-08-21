import Contacts
import Foundation

// One person (or company) from the address book, flattened into exactly what
// a result row needs, with the match targets lowercased once at load time.
struct ContactCard {
    struct Field: Equatable {
        let label: String
        let value: String
    }

    let id: String
    let name: String
    let nickname: String
    let organization: String
    let jobTitle: String
    let phones: [Field]
    let emails: [Field]
    // Addresses arrive multi-line from the formatter; these are the one-line
    // form a row can show and Maps can take as a query.
    let addresses: [Field]
    let urls: [Field]
    let birthday: DateComponents?
    let hasPhoto: Bool

    // Precomputed match targets. `wholes` are complete names to prefix-match,
    // `words` their individual parts.
    let wholes: [String]
    let words: [String]
    let initials: String
    let loweredEmails: [String]
    let phoneDigits: [String]
    let loweredOrganization: String

    init(
        id: String,
        name: String,
        nickname: String = "",
        organization: String = "",
        jobTitle: String = "",
        phones: [Field] = [],
        emails: [Field] = [],
        addresses: [Field] = [],
        urls: [Field] = [],
        birthday: DateComponents? = nil,
        hasPhoto: Bool = false
    ) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.organization = organization
        self.jobTitle = jobTitle
        self.phones = phones
        self.emails = emails
        self.addresses = addresses
        self.urls = urls
        self.birthday = birthday
        self.hasPhoto = hasPhoto

        var wholes = [name.lowercased()]
        if !nickname.isEmpty { wholes.append(nickname.lowercased()) }
        self.wholes = wholes
        words = wholes.flatMap {
            $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        initials = String(name.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .compactMap(\.first))
        loweredEmails = emails.map { $0.value.lowercased() }
        phoneDigits = phones.map { $0.value.filter(\.isNumber) }
        loweredOrganization = organization.lowercased()
    }

    // MARK: - Derived display

    var primaryPhone: Field? {
        // The line Messages and FaceTime most likely reach.
        phones.first {
            let label = $0.label.lowercased()
            return label.contains("mobile") || label.contains("iphone")
        } ?? phones.first
    }

    var primaryEmail: Field? { emails.first }

    // A card whose name is just its company ("Odessa Dry Cleaners"). Kept out
    // of the top ambient rank so a card named after a site or an app can't
    // displace the real thing when that word is typed.
    var isCompany: Bool { !organization.isEmpty && name == organization }

    // iMessage and FaceTime take a number or an Apple ID address.
    var reachable: String? { primaryPhone?.value ?? primaryEmail?.value }

    var subtitleDetail: String {
        var parts: [String] = []
        if !jobTitle.isEmpty { parts.append(jobTitle) }
        if !organization.isEmpty, organization != name { parts.append(organization) }
        if parts.isEmpty, let phone = primaryPhone { parts.append(phone.value) }
        if parts.isEmpty, let email = primaryEmail { parts.append(email.value) }
        return parts.joined(separator: " \u{00B7} ")
    }

    var birthdayText: String? {
        guard let birthday, let month = birthday.month, let day = birthday.day else { return nil }
        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = birthday.year ?? 2000
        guard let date = Calendar.current.date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(birthday.year == nil ? "MMMMd" : "MMMMdyyyy")
        return formatter.string(from: date)
    }

    // Everything the card holds, as the plain text block a Cmd+Return copy
    // should produce.
    var plainTextCard: String {
        var lines = [name]
        if !jobTitle.isEmpty || !organization.isEmpty {
            lines.append([jobTitle, organization].filter { !$0.isEmpty }.joined(separator: ", "))
        }
        for phone in phones { lines.append(labelled(phone)) }
        for email in emails { lines.append(labelled(email)) }
        for address in addresses { lines.append(labelled(address)) }
        for url in urls { lines.append(labelled(url)) }
        if let birthdayText { lines.append("Birthday: \(birthdayText)") }
        return lines.joined(separator: "\n")
    }

    private func labelled(_ field: Field) -> String {
        field.label.isEmpty ? field.value : "\(field.label): \(field.value)"
    }
}

extension ContactCard {
    // nil for a card with no usable name, or nothing on it to act on.
    init?(contact: CNContact) {
        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        let fallback = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }.joined(separator: " ")
        let name = [formatted, fallback, contact.nickname, contact.organizationName]
            .first { !$0.isEmpty } ?? ""
        guard !name.isEmpty else { return nil }

        let phones = contact.phoneNumbers.map {
            Field(label: Self.localizedLabel($0.label), value: $0.value.stringValue)
        }
        let emails = contact.emailAddresses.map {
            Field(label: Self.localizedLabel($0.label), value: $0.value as String)
        }
        let addresses = contact.postalAddresses.map { labeled -> Field in
            let text = CNPostalAddressFormatter.string(from: labeled.value, style: .mailingAddress)
                .split(separator: "\n").joined(separator: ", ")
            return Field(label: Self.localizedLabel(labeled.label), value: text)
        }.filter { !$0.value.isEmpty }
        let urls = contact.urlAddresses.map {
            Field(label: Self.localizedLabel($0.label), value: $0.value as String)
        }
        guard !phones.isEmpty || !emails.isEmpty || !addresses.isEmpty || !urls.isEmpty else { return nil }

        self.init(
            id: contact.identifier,
            name: name,
            nickname: contact.nickname,
            organization: contact.organizationName,
            jobTitle: contact.jobTitle,
            phones: phones,
            emails: emails,
            addresses: addresses,
            urls: urls,
            birthday: contact.birthday,
            hasPhoto: contact.imageDataAvailable
        )
    }

    private static func localizedLabel(_ label: String?) -> String {
        guard let label, !label.isEmpty else { return "" }
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    }
}
