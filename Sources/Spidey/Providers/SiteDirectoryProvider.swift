import Foundation

// Curated directory of mainstream sites: typing a name opens the homepage in Brave.
// Users can add their own entries in ~/Library/Application Support/Spidey/sites.json
// as {"name": "url"} pairs; those merge over the built-in list.
enum SiteDirectoryProvider {
    static let builtIn: [String: String] = [
        // Shopping and fashion
        "vinted": "https://www.vinted.co.uk",
        "rimowa": "https://www.rimowa.com",
        "amazon": "https://www.amazon.co.uk",
        "ebay": "https://www.ebay.co.uk",
        "etsy": "https://www.etsy.com",
        "asos": "https://www.asos.com",
        "zara": "https://www.zara.com",
        "uniqlo": "https://www.uniqlo.com",
        "nike": "https://www.nike.com",
        "adidas": "https://www.adidas.co.uk",
        "depop": "https://www.depop.com",
        "grailed": "https://www.grailed.com",
        "stockx": "https://www.stockx.com",
        "end clothing": "https://www.endclothing.com",
        "mr porter": "https://www.mrporter.com",
        "ssense": "https://www.ssense.com",
        "farfetch": "https://www.farfetch.com",
        "argos": "https://www.argos.co.uk",
        "john lewis": "https://www.johnlewis.com",
        "ikea": "https://www.ikea.com",
        "currys": "https://www.currys.co.uk",
        "tesco": "https://www.tesco.com",
        "sainsburys": "https://www.sainsburys.co.uk",
        "deliveroo": "https://deliveroo.co.uk",
        "uber eats": "https://www.ubereats.com",
        "just eat": "https://www.just-eat.co.uk",
        // Watches and luxury
        "grand seiko": "https://www.grand-seiko.com",
        "seiko": "https://www.seikowatches.com",
        "rolex": "https://www.rolex.com",
        "omega": "https://www.omegawatches.com",
        "tudor": "https://www.tudorwatch.com",
        "cartier": "https://www.cartier.com",
        "patek philippe": "https://www.patek.com",
        "audemars piguet": "https://www.audemarspiguet.com",
        "tag heuer": "https://www.tagheuer.com",
        "longines": "https://www.longines.com",
        "casio": "https://www.casio.com",
        "chrono24": "https://www.chrono24.co.uk",
        "watchfinder": "https://www.watchfinder.co.uk",
        "hodinkee": "https://www.hodinkee.com",
        // Tech and dev
        "github": "https://github.com",
        "stack overflow": "https://stackoverflow.com",
        "hacker news": "https://news.ycombinator.com",
        "apple": "https://www.apple.com",
        "google": "https://www.google.com",
        "gmail": "https://mail.google.com",
        "google drive": "https://drive.google.com",
        "google docs": "https://docs.google.com",
        "google calendar": "https://calendar.google.com",
        "anthropic": "https://www.anthropic.com",
        "claude": "https://claude.ai",
        "chatgpt": "https://chatgpt.com",
        "openai": "https://openai.com",
        "microsoft": "https://www.microsoft.com",
        "figma": "https://www.figma.com",
        "notion": "https://www.notion.so",
        "slack": "https://slack.com",
        "discord": "https://discord.com",
        "zoom": "https://zoom.us",
        "dropbox": "https://www.dropbox.com",
        "vercel": "https://vercel.com",
        "cloudflare": "https://www.cloudflare.com",
        "aws": "https://aws.amazon.com",
        "linear": "https://linear.app",
        "raspberry pi": "https://www.raspberrypi.com",
        // Social and media
        "twitter": "https://x.com",
        "x": "https://x.com",
        "instagram": "https://www.instagram.com",
        "facebook": "https://www.facebook.com",
        "reddit": "https://www.reddit.com",
        "tiktok": "https://www.tiktok.com",
        "linkedin": "https://www.linkedin.com",
        "pinterest": "https://www.pinterest.com",
        "twitch": "https://www.twitch.tv",
        "spotify": "https://open.spotify.com",
        "soundcloud": "https://soundcloud.com",
        "bbc": "https://www.bbc.co.uk",
        "bbc news": "https://www.bbc.co.uk/news",
        "guardian": "https://www.theguardian.com",
        "financial times": "https://www.ft.com",
        "economist": "https://www.economist.com",
        "nytimes": "https://www.nytimes.com",
        "sky news": "https://news.sky.com",
        "the verge": "https://www.theverge.com",
        "wired": "https://www.wired.com",
        // Streaming and entertainment
        "disney plus": "https://www.disneyplus.com",
        "prime video": "https://www.primevideo.com",
        "apple tv": "https://tv.apple.com",
        "bbc iplayer": "https://www.bbc.co.uk/iplayer",
        "channel 4": "https://www.channel4.com",
        "itv": "https://www.itv.com",
        "now tv": "https://www.nowtv.com",
        "letterboxd": "https://letterboxd.com",
        "imdb": "https://www.imdb.com",
        "myanimelist": "https://myanimelist.net",
        "anilist": "https://anilist.co",
        "steam": "https://store.steampowered.com",
        "epic games": "https://store.epicgames.com",
        "playstation": "https://www.playstation.com",
        "nintendo": "https://www.nintendo.co.uk",
        "xbox": "https://www.xbox.com",
        // Travel and life
        "airbnb": "https://www.airbnb.co.uk",
        "booking": "https://www.booking.com",
        "skyscanner": "https://www.skyscanner.net",
        "trainline": "https://www.thetrainline.com",
        "national rail": "https://www.nationalrail.co.uk",
        "tfl": "https://tfl.gov.uk",
        "citymapper": "https://citymapper.com",
        "uber": "https://www.uber.com",
        "google maps": "https://www.google.com/maps",
        "rightmove": "https://www.rightmove.co.uk",
        "zoopla": "https://www.zoopla.co.uk",
        "monzo": "https://monzo.com",
        "revolut": "https://www.revolut.com",
        "wise": "https://wise.com",
        "gov uk": "https://www.gov.uk",
        "nhs": "https://www.nhs.uk",
        "wikipedia": "https://www.wikipedia.org",
        "duolingo": "https://www.duolingo.com",
        "strava": "https://www.strava.com",
        "goodreads": "https://www.goodreads.com",
    ]

    static func userSites() -> [String: String] {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = base.appendingPathComponent("Spidey/sites.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return decoded
    }

    private static var mergedCache: [String: String]?

    static var merged: [String: String] {
        if let mergedCache { return mergedCache }
        let combined = builtIn.merging(userSites()) { _, user in user }
        mergedCache = combined
        return combined
    }

    static func results(for query: String, includeGuess: Bool = true) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return [] }
        var items: [ResultItem] = []
        var hadStrongMatch = false

        for (name, urlString) in merged {
            guard let match = Fuzzy.score(query: trimmed, candidate: name), match >= 0.6,
                  let url = URL(string: urlString) else { continue }
            if match >= 0.9 { hadStrongMatch = true }
            let host = url.host ?? urlString
            items.append(ResultItem(
                title: "Open \(name.capitalized)",
                subtitle: "\(host) in \(BrowserLauncher.targetName)",
                icon: .symbol("globe"),
                score: 500 + match * 240,
                action: { BrowserLauncher.open(url) }
            ))
        }
        items = Array(items.sorted { $0.score > $1.score }.prefix(3))

        // Unknown name: offer a homepage guess like grandseiko.com.
        if includeGuess, !hadStrongMatch, trimmed.count >= 3, trimmed.rangeOfCharacter(from: .letters) != nil,
           let guess = guessURL(for: trimmed) {
            items.append(ResultItem(
                title: "Open \(guess.host ?? trimmed)",
                subtitle: "Guess the homepage in \(BrowserLauncher.targetName)",
                icon: .symbol("globe"),
                score: 150,
                action: { BrowserLauncher.open(guess) }
            ))
        }
        return items
    }

    static func guessURL(for name: String) -> URL? {
        let slug = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        guard !slug.isEmpty else { return nil }
        return URL(string: "https://www.\(slug).com")
    }
}
