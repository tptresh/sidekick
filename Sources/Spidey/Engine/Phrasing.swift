import Foundation

// Everyday phrasing rewritten into the terse syntax the system providers
// expect: "set a timer for 5 minutes" becomes "timer 5 minutes", "turn off
// wifi" becomes "wifi off", "what's my ip" becomes "ip". A query that is
// already terse comes back unchanged, so nothing that worked before changes.
//
// Only the system providers see the rewrite. Apps, bookmarks, streaming and
// web search still get exactly what the user typed, so a rewrite can never
// change what "close encounters" searches for.
enum Phrasing {
    static func normalize(_ query: String) -> String {
        let collapsed = collapse(query)
        guard !collapsed.isEmpty else { return collapsed }
        if let rewritten = firstMatch(collapsed) { return rewritten }
        // Politeness only comes off when it reveals a real command, so
        // ordinary searches like "get lucky" stay exactly as they were.
        let stripped = stripCourtesy(collapsed)
        if stripped != collapsed, let rewritten = firstMatch(stripped) { return rewritten }
        return collapsed
    }

    private static func firstMatch(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        for rule in rules {
            if let rewritten = rule.apply(to: text) { return rewritten }
        }
        return nil
    }

    // MARK: - Rules

    private struct Rule {
        let regex: NSRegularExpression
        let template: String

        init?(_ pattern: String, _ template: String) {
            // Non-capturing wrapper so the templates can keep using $1.
            guard let regex = try? NSRegularExpression(
                pattern: "^(?:" + pattern + ")$", options: [.caseInsensitive]
            ) else { return nil }
            self.regex = regex
            self.template = template
        }

        func apply(to text: String) -> String? {
            let range = NSRange(text.startIndex..., in: text)
            guard regex.firstMatch(in: text, options: [], range: range) != nil else { return nil }
            let rewritten = regex.stringByReplacingMatches(
                in: text, options: [], range: range, withTemplate: template
            )
            return Phrasing.collapse(rewritten)
        }
    }

    // Compiled once: the whole table runs against every keystroke.
    private static let rules: [Rule] = specs.compactMap { Rule($0.0, $0.1) }

    // Nouns that show up in most spoken commands.
    private static let mine = "(?:my|the|this)"
    private static let mac = "(?:mac|macbook|mac\\s?book|computer|laptop|machine|imac)"

    // Order matters: the first rule that matches the whole query wins, so the
    // specific subjects (timers, toggles, media) come before the catch-all
    // "close <app>" shapes at the end.
    private static var specs: [(String, String)] {
        timerSpecs + powerSpecs + toggleSpecs + volumeSpecs + brightnessSpecs
            + mediaSpecs + infoSpecs + timeSpecs + windowSpecs + processSpecs
    }

    // MARK: - Timers

    private static let timerSpecs: [(String, String)] = [
        ("(?:cancel|stop|end|clear|kill|delete)\\s+(?:my|the|all|all\\s+my)?\\s*timers?", "timers"),
        ("(?:show|list|check|see)?\\s*(?:me\\s+)?(?:my|the|any)?\\s*(?:running\\s+)?timers?", "timers"),
        // "set a timer for 5 minutes", "timer for 10m", "start a new timer 90s tea"
        ("(?:set|start|create|make|put|run|add|begin)?\\s*(?:a|an|the|another|new)?\\s*(?:new\\s+)?timer\\s*(?:for|of|to)?\\s+(.+)", "timer $1"),
        // "5 minute timer", "set a 25 min timer for pasta"
        ("(?:set|start|create|make|run)?\\s*(?:a|an|the)?\\s*(\\d.*?)\\s*[-\\s]\\s*timer(?:\\s+(?:for|to|called|named|labell?ed)\\s+)?(.*)", "timer $1 $2"),
        // "an hour timer", "half an hour timer": no digits to anchor on.
        ("(?:set|start|create|make|run)?\\s*((?:half\\s+)?(?:an?\\s+)?(?:hour|minute|min|second|sec)s?)\\s+timer", "timer $1"),
        ("(?:start|set|run|do)?\\s*(?:a|an|the)?\\s*countdown\\s*(?:for|of|from)?\\s+(.+)", "timer $1"),
    ]

    // MARK: - Power and session

    private static var powerSpecs: [(String, String)] {
        [
            ("(?:put|send)\\s+\(mine)?\\s*\(mac)\\s+(?:in)?to\\s+sleep", "sleep"),
            ("go\\s+to\\s+sleep", "sleep"),
            ("sleep\\s+(?:\(mine)\\s*)?\(mac)", "sleep"),
            ("lock\\s*(?:\(mine)\\s*)?(?:screen|display|\(mac)|it)?", "lock screen"),
            ("(?:restart|reboot)\\s*(?:\(mine)\\s*)?(?:\(mac))?", "restart"),
            ("(?:shut\\s*down|power\\s*off|power\\s*down)\\s*(?:\(mine)\\s*)?(?:\(mac))?", "shut down"),
            ("turn\\s+off\\s+\(mine)\\s+\(mac)", "shut down"),
            ("(?:log|sign)\\s+(?:me\\s+)?out(?:\\s+of\\s+(?:\(mine)\\s*)?(?:\(mac)|account))?", "log out"),
            ("(?:empty|clear|delete|take\\s+out|dump)\\s+(?:the|my)?\\s*(?:trash|bin|garbage|rubbish)", "empty trash"),
            ("(?:start|show|run|activate|launch)?\\s*(?:the\\s+)?screen\\s*saver", "screensaver"),
            ("eject\\s*(?:all\\s+)?(?:my\\s+)?(?:disks?|drives?|volumes?|usb|external|everything)?", "eject"),
        ]
    }

    // MARK: - Toggles

    // The same nine shapes for every on/off subject: "turn off wifi",
    // "wifi off", "disable wifi", and so on.
    private static func onOffSpecs(_ subject: String, _ canonical: String) -> [(String, String)] {
        [
            ("(?:turn|switch|shut)\\s+off\\s+(?:my|the)?\\s*\(subject)", "\(canonical) off"),
            ("(?:turn|switch)\\s+(?:my|the)?\\s*\(subject)\\s+off", "\(canonical) off"),
            ("(?:disable|deactivate|kill)\\s+(?:my|the)?\\s*\(subject)", "\(canonical) off"),
            ("\(subject)\\s+off", "\(canonical) off"),
            ("(?:turn|switch)\\s+on\\s+(?:my|the)?\\s*\(subject)", "\(canonical) on"),
            ("(?:turn|switch)\\s+(?:my|the)?\\s*\(subject)\\s+on", "\(canonical) on"),
            ("(?:enable|activate|start)\\s+(?:my|the)?\\s*\(subject)", "\(canonical) on"),
            ("\(subject)\\s+on", "\(canonical) on"),
            ("toggle\\s+(?:my|the)?\\s*\(subject)", canonical),
        ]
    }

    // Every on/off subject: the pattern that names it, and the word the
    // providers know it by.
    private static var subjects: [(pattern: String, canonical: String)] {
        [
            ("(?:wi\\s?-?\\s?fi|wireless)", "wifi"),
            ("(?:blue\\s?tooth)", "bluetooth"),
            ("(?:dark\\s*mode|night\\s*mode)", "dark mode"),
            ("(?:do\\s+not\\s+disturb|dnd)", "dnd"),
            ("(?:caffeinate|insomnia)", "caffeinate"),
        ]
    }

    private static var toggleSpecs: [(String, String)] {
        var specs = subjects.flatMap { onOffSpecs($0.pattern, $0.canonical) }
        // Phrasings that carry their own direction, ahead of the bare
        // subjects below so "keep my mac awake" never reads as a flip.
        specs += [
            ("(?:switch|change|go|set\\s+it)\\s+to\\s+dark\\s*mode", "dark mode on"),
            ("(?:switch|change|go|set\\s+it)\\s+to\\s+light\\s*mode", "dark mode off"),
            ("(?:make\\s+it\\s+dark|go\\s+dark)", "dark mode on"),
            ("(?:make\\s+it\\s+light|go\\s+light|light\\s*mode)", "dark mode off"),
            ("keep\\s+(?:\(mine)\\s+)?(?:\(mac)|screen|display|it)?\\s*awake", "caffeinate on"),
            ("stay\\s+awake", "caffeinate on"),
            ("don'?t\\s+let\\s+(?:\(mine)\\s*)?(?:\(mac)|it)\\s+sleep", "caffeinate on"),
            ("(?:stop|quit)\\s+keeping\\s+(?:\(mine)\\s*)?(?:\(mac)|it)?\\s*awake", "caffeinate off"),
            ("(?:let|allow)\\s+(?:\(mine)\\s*)?(?:\(mac)|it)\\s+sleep", "caffeinate off"),
            // Notifications read backwards from the Focus they need: turning
            // them off means turning Do Not Disturb on.
            ("(?:turn|switch)\\s+off\\s+(?:my|the)?\\s*notifications", "dnd on"),
            ("(?:silence|mute|disable|stop|hide)\\s+(?:my|the)?\\s*notifications", "dnd on"),
            ("(?:turn|switch)\\s+on\\s+(?:my|the)?\\s*notifications", "dnd off"),
            ("(?:enable|allow|unmute|unsilence)\\s+(?:my|the)?\\s*notifications", "dnd off"),
            ("(?:clear|empty|wipe|delete|forget)\\s+(?:my|the)?\\s*clipboard(?:\\s+history)?", "clear clipboard"),
        ]
        // The subject on its own flips whatever state it is in.
        specs += subjects.map { ($0.pattern, $0.canonical) }
        return specs
    }

    // MARK: - Volume

    private static let sound = "(?:volume|sound|audio)"

    private static var volumeSpecs: [(String, String)] {
        [
            ("(?:turn|crank|bump)\\s+up\\s+(?:the|my)?\\s*\(sound)", "volume up"),
            ("(?:turn|crank|bump)\\s+(?:the|my)?\\s*\(sound)\\s+up", "volume up"),
            ("\(sound)\\s+up", "volume up"),
            ("(?:make\\s+it\\s+)?louder", "volume up"),
            ("(?:turn|bring)\\s+down\\s+(?:the|my)?\\s*\(sound)", "volume down"),
            ("(?:turn|bring)\\s+(?:the|my|it)?\\s*\(sound)?\\s*down", "volume down"),
            ("\(sound)\\s+down", "volume down"),
            ("(?:make\\s+it\\s+)?(?:quieter|softer)", "volume down"),
            ("(?:set|change|put)\\s+(?:the|my)?\\s*\(sound)\\s+(?:to|at)\\s+(\\d{1,3})\\s*%?", "volume $1"),
            ("\(sound)\\s+(?:to|at)\\s+(\\d{1,3})\\s*%?", "volume $1"),
            ("\(sound)\\s+(\\d{1,3})\\s*%", "volume $1"),
            ("(?:max|maximum|full)\\s+\(sound)", "volume 100"),
            ("\(sound)\\s+(?:max|maximum|full|all\\s+the\\s+way\\s+up)", "volume 100"),
            ("(?:mute|silence)\\s*(?:the|my)?\\s*(?:\(sound)|\(mac)|everything|it)?", "mute"),
            ("un-?mute\\s*(?:the|my)?\\s*(?:\(sound)|it)?", "unmute"),
        ]
    }

    // MARK: - Brightness

    private static let display = "(?:screen|display)"

    private static var brightnessSpecs: [(String, String)] {
        [
            ("(?:turn|bump|crank)\\s+up\\s+(?:the|my)?\\s*(?:\(display)\\s+)?brightness", "brightness up"),
            ("(?:turn|bump|crank)\\s+(?:the|my)?\\s*(?:\(display)\\s+)?brightness\\s+up", "brightness up"),
            ("brightness\\s+up", "brightness up"),
            ("(?:make\\s+)?(?:the\\s+|my\\s+)?\(display)\\s+brighter", "brightness up"),
            ("brighten\\s+(?:the\\s+|my\\s+)?\(display)", "brightness up"),
            ("brighter", "brightness up"),
            ("(?:turn|bring)\\s+down\\s+(?:the|my)?\\s*(?:\(display)\\s+)?brightness", "brightness down"),
            ("(?:turn|bring)\\s+(?:the|my)?\\s*(?:\(display)\\s+)?brightness\\s+down", "brightness down"),
            ("brightness\\s+down", "brightness down"),
            ("(?:dim|darken)\\s*(?:the|my)?\\s*(?:\(display))?", "brightness down"),
            ("(?:make\\s+)?(?:the\\s+|my\\s+)?\(display)\\s+(?:dimmer|darker|less\\s+bright)", "brightness down"),
            ("(?:set|change|put)\\s+(?:the|my)?\\s*brightness\\s+(?:to|at)\\s+(\\d{1,3})\\s*%?", "brightness $1"),
            ("brightness\\s+(?:to|at)\\s+(\\d{1,3})\\s*%?", "brightness $1"),
            ("brightness\\s+(\\d{1,3})\\s*%", "brightness $1"),
            ("(?:max|maximum|full)\\s+brightness", "brightness 100"),
            ("brightness\\s+(?:max|maximum|full)", "brightness 100"),
        ]
    }

    // MARK: - Music

    private static let tunes = "(?:music|song|songs|tunes|track|playback|spotify)"

    private static var mediaSpecs: [(String, String)] {
        [
            ("(?:play|resume|start|unpause)\\s+(?:the\\s+|my\\s+)?\(tunes)", "play"),
            ("(?:pause|stop)\\s+(?:the\\s+|my\\s+)?\(tunes)", "pause"),
            ("(?:next|skip)\\s+(?:the\\s+|this\\s+)?(?:song|track)", "next"),
            ("skip\\s+(?:this|it|ahead)", "next"),
            ("(?:previous|last|go\\s+back\\s+a)\\s+(?:song|track)", "prev"),
            ("(?:what'?s\\s+)?(?:currently\\s+)?playing(?:\\s+(?:right\\s+)?now)?", "now playing"),
            ("what\\s+song\\s+is\\s+(?:this|playing)", "now playing"),
        ]
    }

    // MARK: - Machine readouts

    // What a question form leaves behind once "what's" is peeled off.
    private static let owned = "(?:my\\s+|the\\s+)?"

    private static var infoSpecs: [(String, String)] {
        [
            ("\(owned)(?:public|external|local|wifi)?\\s*ip(?:\\s+address)?", "ip"),
            ("\(owned)battery(?:\\s+(?:level|percentage|percent|status|life|health|remaining|left))?", "battery"),
            ("(?:how\\s+much\\s+)?\(owned)(?:battery|charge)(?:\\s+(?:is\\s+)?(?:left|remaining|do\\s+i\\s+have))?", "battery"),
            ("\(owned)(?:disk|drive|storage|hard\\s+drive)(?:\\s+space)?(?:\\s+(?:is\\s+)?(?:usage|used|free|left|remaining|do\\s+i\\s+have))?", "disk"),
            ("\(owned)(?:free|available|remaining)\\s+(?:disk\\s+|drive\\s+)?(?:space|storage)", "disk"),
            ("(?:how\\s+much\\s+)?\(owned)(?:space|storage)(?:\\s+(?:is\\s+)?(?:left|free|remaining|do\\s+i\\s+have))?", "disk"),
        ]
    }

    // MARK: - World clock

    private static var timeSpecs: [(String, String)] {
        [
            ("(?:what\\s+)?time\\s+is\\s+it\\s+in\\s+(.+)", "time in $1"),
            ("\(owned)(?:current|local)\\s+time\\s+in\\s+(.+)", "time in $1"),
            ("\(owned)time\\s+(?:in|at|for)\\s+(.+)", "time in $1"),
        ]
    }

    // MARK: - Window snapping

    private static let windowSpecs: [(String, String)] = [
        ("(?:snap|move|put|send|push)\\s+(?:this\\s+|the\\s+)?(?:window\\s+)?(?:to\\s+the\\s+)?(top|bottom)\\s+(left|right)(?:\\s+corner)?", "$1 $2"),
        ("(?:snap|move|put|send|push)\\s+(?:this\\s+|the\\s+)?(?:window\\s+)?(?:to\\s+the\\s+)?(left|right|top|bottom)(?:\\s+half)?", "$1 half"),
        ("(?:maximize|maximise|fullscreen|full\\s+screen)\\s+(?:this\\s+|the\\s+)?window", "maximize"),
        ("(?:make\\s+)?(?:this\\s+|the\\s+)?window\\s+(?:full\\s*screen|fullscreen|bigger)", "maximize"),
        ("(?:center|centre)\\s+(?:this\\s+|the\\s+)?window", "center"),
    ]

    // MARK: - Apps and processes

    private static let appTarget = "(?:the\\s+)?(.+?)(?:\\s+app)?"

    private static var processSpecs: [(String, String)] {
        [
            ("force\\s+(?:close|kill|stop)\\s+\(appTarget)", "force quit $1"),
            ("force\\s+quit\\s+\(appTarget)", "force quit $1"),
            ("(?:close|exit)\\s+\(appTarget)", "quit $1"),
            ("(?:quit|shut\\s*down)\\s+\(appTarget)", "quit $1"),
            ("kill\\s+\(appTarget)", "kill $1"),
        ]
    }

    // MARK: - Cleanup

    // Politeness and filler that carries no meaning for a command.
    // Longest first: "show me" has to win before "show".
    private static let leadingFiller = [
        "hey spidey", "ok spidey", "okay spidey", "spidey", "please", "pls",
        "can you", "could you", "would you", "will you", "i want you to",
        "i want to", "i need you to", "i need to", "i'd like to", "id like to",
        "let's", "lets", "just", "quickly", "hey", "yo", "now",
        "what is", "what's", "whats", "how much", "how many",
        "show me", "tell me", "give me", "show", "check", "get",
    ]

    private static let trailingFiller = [
        "please", "for me", "right now", "now", "thanks", "thank you", "ok", "okay",
    ]

    private static func stripCourtesy(_ text: String) -> String {
        var working = text
        while let last = working.last, last == "?" || last == "!" || last == "." {
            working.removeLast()
        }
        working = collapse(working)

        var changed = true
        while changed {
            changed = false
            let lowered = working.lowercased()
            for filler in leadingFiller where lowered.hasPrefix(filler + " ") {
                working = collapse(String(working.dropFirst(filler.count + 1)))
                changed = true
                break
            }
            if changed { continue }
            let loweredNow = working.lowercased()
            for filler in trailingFiller where loweredNow.hasSuffix(" " + filler) {
                working = collapse(String(working.dropLast(filler.count + 1)))
                changed = true
                break
            }
        }
        return working
    }

    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
