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
        "walmart": "https://www.walmart.com",
        "best buy": "https://www.bestbuy.com",
        "target": "https://www.target.com",
        "home depot": "https://www.homedepot.com",
        "costco": "https://www.costco.com",
        "lowes": "https://www.lowes.com",
        "temu": "https://www.temu.com",
        "shein": "https://www.shein.com",
        "aliexpress": "https://www.aliexpress.com",
        "wayfair": "https://www.wayfair.com",
        "sephora": "https://www.sephora.com",
        "macys": "https://www.macys.com",
        "nordstrom": "https://www.nordstrom.com",
        "h&m": "https://www2.hm.com",
        "lego": "https://www.lego.com",
        "craigslist": "https://www.craigslist.org",
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
        "gucci": "https://www.gucci.com",
        "louis vuitton": "https://www.louisvuitton.com",
        "chanel": "https://www.chanel.com",
        "hermes": "https://www.hermes.com",
        "dior": "https://www.dior.com",
        "prada": "https://www.prada.com",
        "burberry": "https://www.burberry.com",
        "tiffany": "https://www.tiffany.com",
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
        "outlook": "https://outlook.live.com",
        "hotmail": "https://outlook.live.com",
        "office": "https://www.office.com",
        "microsoft teams": "https://teams.microsoft.com",
        "onedrive": "https://onedrive.live.com",
        "yahoo": "https://www.yahoo.com",
        "yahoo mail": "https://mail.yahoo.com",
        "bing": "https://www.bing.com",
        "paypal": "https://www.paypal.com",
        "whatsapp": "https://web.whatsapp.com",
        "telegram": "https://web.telegram.org",
        "proton mail": "https://mail.proton.me",
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
        "snapchat": "https://www.snapchat.com",
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
        "cnn": "https://www.cnn.com",
        "espn": "https://www.espn.com",
        "samsung": "https://www.samsung.com",
        "adobe": "https://www.adobe.com",
        "canva": "https://www.canva.com",
        "duckduckgo": "https://duckduckgo.com",
        "tesla": "https://www.tesla.com",
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
        "chase": "https://www.chase.com",
        "bank of america": "https://www.bankofamerica.com",
        "wells fargo": "https://www.wellsfargo.com",
        "american express": "https://www.americanexpress.com",
        "capital one": "https://www.capitalone.com",
        "zillow": "https://www.zillow.com",
        "expedia": "https://www.expedia.com",
        "tripadvisor": "https://www.tripadvisor.com",
        "doordash": "https://www.doordash.com",
        "instacart": "https://www.instacart.com",
        "starbucks": "https://www.starbucks.com",
        "mcdonalds": "https://www.mcdonalds.com",
        "gov uk": "https://www.gov.uk",
        "nhs": "https://www.nhs.uk",
        "wikipedia": "https://www.wikipedia.org",
        "duolingo": "https://www.duolingo.com",
        "strava": "https://www.strava.com",
        "goodreads": "https://www.goodreads.com",
    ]

    // MARK: - Popularity tiers
    //
    // A static prior on "typing this name means the website, not a show title".
    //   3 = globally dominant consumer sites and brands (top of web traffic /
    //       brand-search rankings): typing the name almost always means the site.
    //   2 = well-known brands and mid-tier retailers (Cartier, Rimowa, Zara...).
    //   1 = everything else in the built-in directory.
    //   0 = the homepage-guess row and unknown user-added sites.
    // Tiers only add score on a strong name match (exact, or the query is a
    // full prefix of the name); fuzzy matches keep their modest scores.
    // Deliberately curated in code: deterministic and fully offline.

    static let tier3: Set<String> = [
        // Search, mail, portals
        "google", "gmail", "google maps", "google drive", "google docs",
        "bing", "yahoo", "duckduckgo", "outlook", "hotmail", "office",
        // Tech giants and AI
        "apple", "microsoft", "samsung", "adobe", "chatgpt", "openai", "github",
        // Social and messaging
        "instagram", "facebook", "reddit", "twitter", "x", "tiktok", "linkedin",
        "pinterest", "twitch", "whatsapp", "snapchat", "discord", "zoom",
        // Reference and news
        "wikipedia", "bbc", "bbc news", "cnn", "espn", "nytimes", "imdb",
        // Shopping and retail
        "amazon", "ebay", "etsy", "walmart", "best buy", "target", "home depot",
        "costco", "lowes", "temu", "shein", "aliexpress", "ikea", "zara",
        "nike", "adidas", "craigslist",
        // Money
        "paypal", "chase", "bank of america", "wells fargo",
        // Media and gaming
        "spotify", "netflix", "youtube", "disney plus", "prime video", "steam",
        "playstation", "xbox", "nintendo",
        // Travel and transport
        "uber", "airbnb", "booking", "tesla", "zillow",
        // Cloud and storage
        "dropbox", "tesco",
    ]

    static let tier2: Set<String> = [
        // Watches and luxury
        "cartier", "rolex", "omega", "tudor", "grand seiko", "seiko",
        "patek philippe", "audemars piguet", "tag heuer", "longines", "casio",
        "gucci", "louis vuitton", "chanel", "hermes", "dior", "prada",
        "burberry", "tiffany", "rimowa",
        // Fashion and shopping
        "uniqlo", "asos", "vinted", "depop", "grailed", "stockx", "farfetch",
        "ssense", "mr porter", "end clothing", "h&m", "lego", "wayfair",
        "sephora", "macys", "nordstrom", "argos", "john lewis", "currys",
        "sainsburys",
        // Food and delivery
        "deliveroo", "uber eats", "just eat", "doordash", "instacart",
        "starbucks", "mcdonalds",
        // Tech and dev
        "stack overflow", "hacker news", "figma", "notion", "slack", "canva",
        "telegram", "aws", "cloudflare", "anthropic", "claude", "onedrive",
        "microsoft teams", "google calendar", "yahoo mail", "proton mail",
        // News
        "guardian", "financial times", "economist", "sky news", "the verge",
        "wired",
        // Streaming and entertainment
        "apple tv", "bbc iplayer", "channel 4", "itv", "now tv", "crunchyroll",
        "hulu", "epic games", "soundcloud", "goodreads",
        // Travel and life
        "skyscanner", "trainline", "national rail", "tfl", "expedia",
        "tripadvisor", "rightmove", "zoopla", "monzo", "revolut", "wise",
        "american express", "capital one", "gov uk", "nhs", "duolingo",
        "strava",
    ]

    // Tier for a directory (or user) site name. Built-in names not listed in a
    // curated set are tier 1; unknown names (user sites.json entries the
    // curation has never heard of) are tier 0.
    static func tier(forName name: String) -> Int {
        let key = name.lowercased()
        if tier3.contains(key) { return 3 }
        if tier2.contains(key) { return 2 }
        if builtIn[key] != nil { return 1 }
        return 0
    }

    // MARK: - Matching

    // Best fuzzy score between the query and a site name, also comparing the
    // space-stripped forms so "bestbuy" hits "best buy" (and vice versa).
    static func matchScore(query: String, name: String) -> Double? {
        let direct = Fuzzy.score(query: query, candidate: name) ?? 0
        let squashedQuery = query.replacingOccurrences(of: " ", with: "")
        let squashedName = name.replacingOccurrences(of: " ", with: "")
        let squashed = Fuzzy.score(query: squashedQuery, candidate: squashedName) ?? 0
        let best = max(direct, squashed)
        return best > 0 ? best : nil
    }

    // Strong = exact match, or a full prefix of the name once the query is
    // long enough to be deliberate (2-char prefixes are too ambiguous to
    // trigger the big tier boosts).
    static func isStrongMatch(_ match: Double, queryLength: Int) -> Bool {
        match >= 1.0 || (match >= 0.92 && queryLength >= 3)
    }

    // Highest popularity tier among sites whose name the query strongly
    // matches, or nil when nothing matches strongly. StreamingProvider uses
    // this to demote "Watch ... on Netflix" rows when the query is far more
    // likely a famous site name than a show title.
    static func popularityTier(matching query: String) -> Int? {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return nil }
        var best: Int?
        for name in merged.keys {
            guard let match = matchScore(query: trimmed, name: name),
                  isStrongMatch(match, queryLength: trimmed.count) else { continue }
            let tier = tier(forName: name)
            if tier > (best ?? -1) { best = tier }
        }
        return best
    }

    // MARK: - Scoring
    //
    // Bands (all static, deterministic; the engine's learned frecency boost is
    // ADDED on top, so the ceiling stays under keyword commands at ~950-960):
    //   tier 3 strong match: 900 + match*45   -> 941...945
    //   tier 2 strong match: 830 + match*45   -> 871...875
    //   tier 0/1 or fuzzy:   500 + match*240  -> 644...740
    //   homepage guess:      220 / 150
    static func score(match: Double, tier: Int, queryLength: Int) -> Double {
        if isStrongMatch(match, queryLength: queryLength) {
            if tier >= 3 { return 900 + match * 45 }
            if tier == 2 { return 830 + match * 45 }
        }
        return 500 + match * 240
    }

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
            guard let match = matchScore(query: trimmed, name: name), match >= 0.6,
                  let url = URL(string: urlString) else { continue }
            if match >= 0.9 { hadStrongMatch = true }
            let host = url.host ?? urlString
            items.append(ResultItem(
                title: "Open \(name.capitalized)",
                subtitle: "\(host) in \(BrowserLauncher.targetName)",
                icon: FaviconStore.shared.resultIcon(for: urlString, fallbackSymbol: "globe"),
                score: score(match: match, tier: tier(forName: name), queryLength: trimmed.count),
                rankingKey: "site:\(host)",
                action: { BrowserLauncher.open(url) }
            ))
        }
        items = Array(items.sorted { $0.score > $1.score }.prefix(3))

        // Unknown name: offer a homepage guess like grandseiko.com.
        if includeGuess, !hadStrongMatch, trimmed.count >= 3, trimmed.rangeOfCharacter(from: .letters) != nil,
           let guess = guessURL(for: trimmed) {
            // A single word reads as a site name, so it outranks the streaming
            // suggestions (score 200); multi-word queries read as show titles
            // and stay below them.
            let looksLikeSiteName = !trimmed.contains(" ")
            items.append(ResultItem(
                title: "Open \(guess.host ?? trimmed)",
                subtitle: "Guess the homepage in \(BrowserLauncher.targetName)",
                icon: .symbol("globe"),
                score: looksLikeSiteName ? 220 : 150,
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
