import AppKit

// "emoji fire": search a curated emoji set by name or keyword, Return copies.
enum EmojiProvider {
    struct Entry {
        let char: String
        let name: String
        let keywords: String
    }

    static let entries: [Entry] = [
        // Faces
        Entry(char: "😀", name: "Grinning Face", keywords: "smile happy grin"),
        Entry(char: "😂", name: "Tears of Joy", keywords: "laugh lol funny crying"),
        Entry(char: "🤣", name: "Rolling on the Floor", keywords: "laugh rofl funny"),
        Entry(char: "😊", name: "Smiling Face", keywords: "happy blush warm"),
        Entry(char: "😍", name: "Heart Eyes", keywords: "love adore crush"),
        Entry(char: "🥰", name: "Smiling with Hearts", keywords: "love adore affection"),
        Entry(char: "😘", name: "Blowing a Kiss", keywords: "love kiss"),
        Entry(char: "😎", name: "Sunglasses", keywords: "cool shades"),
        Entry(char: "🤔", name: "Thinking Face", keywords: "hmm wonder consider"),
        Entry(char: "🤨", name: "Raised Eyebrow", keywords: "suspicious skeptical doubt"),
        Entry(char: "😐", name: "Neutral Face", keywords: "meh blank"),
        Entry(char: "🙄", name: "Eye Roll", keywords: "annoyed whatever"),
        Entry(char: "😴", name: "Sleeping Face", keywords: "tired sleep zzz"),
        Entry(char: "🥱", name: "Yawning Face", keywords: "tired bored sleepy"),
        Entry(char: "😢", name: "Crying Face", keywords: "sad tear upset"),
        Entry(char: "😭", name: "Loudly Crying", keywords: "sad sob bawling"),
        Entry(char: "😤", name: "Steam from Nose", keywords: "frustrated angry huff"),
        Entry(char: "😡", name: "Angry Face", keywords: "mad rage furious"),
        Entry(char: "🤬", name: "Cursing Face", keywords: "swearing angry rage"),
        Entry(char: "🤯", name: "Exploding Head", keywords: "mind blown shocked wow"),
        Entry(char: "😱", name: "Screaming in Fear", keywords: "shocked scared scream"),
        Entry(char: "🥳", name: "Partying Face", keywords: "party celebrate birthday"),
        Entry(char: "😇", name: "Halo Face", keywords: "angel innocent"),
        Entry(char: "🤗", name: "Hugging Face", keywords: "hug warm"),
        Entry(char: "🤫", name: "Shushing Face", keywords: "quiet secret shh"),
        Entry(char: "🤡", name: "Clown Face", keywords: "joke silly circus"),
        Entry(char: "😷", name: "Face with Mask", keywords: "sick ill mask"),
        Entry(char: "🤒", name: "Face with Thermometer", keywords: "sick ill fever"),
        Entry(char: "🥶", name: "Cold Face", keywords: "freezing cold ice"),
        Entry(char: "🥵", name: "Hot Face", keywords: "heat sweating hot"),
        Entry(char: "😈", name: "Smiling Devil", keywords: "evil devil mischief"),
        Entry(char: "💀", name: "Skull", keywords: "dead death dying funny"),
        Entry(char: "👻", name: "Ghost", keywords: "spooky halloween boo"),
        Entry(char: "🤖", name: "Robot", keywords: "bot machine ai"),
        Entry(char: "👽", name: "Alien", keywords: "ufo space extraterrestrial"),
        // Gestures and people
        Entry(char: "👍", name: "Thumbs Up", keywords: "yes approve like ok good"),
        Entry(char: "👎", name: "Thumbs Down", keywords: "no disapprove dislike bad"),
        Entry(char: "👌", name: "OK Hand", keywords: "perfect fine agree"),
        Entry(char: "✌️", name: "Victory Hand", keywords: "peace two"),
        Entry(char: "🤞", name: "Crossed Fingers", keywords: "luck hope wish"),
        Entry(char: "🤙", name: "Call Me Hand", keywords: "shaka hang loose"),
        Entry(char: "👏", name: "Clapping Hands", keywords: "applause bravo congrats"),
        Entry(char: "🙌", name: "Raising Hands", keywords: "celebrate hooray praise"),
        Entry(char: "🙏", name: "Folded Hands", keywords: "please thanks pray namaste"),
        Entry(char: "🤝", name: "Handshake", keywords: "deal agreement partner"),
        Entry(char: "💪", name: "Flexed Biceps", keywords: "strong muscle gym power"),
        Entry(char: "👉", name: "Pointing Right", keywords: "point direction this"),
        Entry(char: "👀", name: "Eyes", keywords: "look watching sus"),
        Entry(char: "🧠", name: "Brain", keywords: "smart mind think"),
        Entry(char: "🫡", name: "Saluting Face", keywords: "salute respect yes sir"),
        Entry(char: "🤷", name: "Shrug", keywords: "dunno whatever unsure"),
        Entry(char: "🤦", name: "Facepalm", keywords: "doh frustrated disbelief"),
        Entry(char: "🏃", name: "Runner", keywords: "run running exercise fast"),
        Entry(char: "🧑‍💻", name: "Technologist", keywords: "coder programmer developer laptop"),
        // Hearts and symbols
        Entry(char: "❤️", name: "Red Heart", keywords: "love like heart"),
        Entry(char: "🧡", name: "Orange Heart", keywords: "love heart"),
        Entry(char: "💛", name: "Yellow Heart", keywords: "love heart friendship"),
        Entry(char: "💚", name: "Green Heart", keywords: "love heart nature"),
        Entry(char: "💙", name: "Blue Heart", keywords: "love heart trust"),
        Entry(char: "💜", name: "Purple Heart", keywords: "love heart"),
        Entry(char: "🖤", name: "Black Heart", keywords: "love heart dark"),
        Entry(char: "🤍", name: "White Heart", keywords: "love heart pure"),
        Entry(char: "💔", name: "Broken Heart", keywords: "sad heartbreak breakup"),
        Entry(char: "✨", name: "Sparkles", keywords: "shiny magic new clean"),
        Entry(char: "⭐", name: "Star", keywords: "favorite rating"),
        Entry(char: "🌟", name: "Glowing Star", keywords: "shining special"),
        Entry(char: "🌠", name: "Shooting Star", keywords: "wish night sky"),
        Entry(char: "💯", name: "Hundred Points", keywords: "perfect score keep it real"),
        Entry(char: "✅", name: "Check Mark", keywords: "done yes correct complete tick"),
        Entry(char: "❌", name: "Cross Mark", keywords: "no wrong incorrect x"),
        Entry(char: "⚠️", name: "Warning", keywords: "caution alert danger"),
        Entry(char: "❗", name: "Exclamation Mark", keywords: "important alert"),
        Entry(char: "❓", name: "Question Mark", keywords: "what confused help"),
        Entry(char: "♻️", name: "Recycling", keywords: "recycle green environment"),
        Entry(char: "🔥", name: "Fire", keywords: "flame hot lit burn"),
        Entry(char: "💧", name: "Droplet", keywords: "water rain drop"),
        Entry(char: "⚡", name: "Lightning Bolt", keywords: "electric fast power zap"),
        Entry(char: "💥", name: "Collision", keywords: "boom explosion bang"),
        Entry(char: "💫", name: "Dizzy", keywords: "stars spinning"),
        Entry(char: "💤", name: "Zzz", keywords: "sleep tired snore"),
        Entry(char: "🎉", name: "Party Popper", keywords: "celebrate congrats tada party"),
        Entry(char: "🎊", name: "Confetti Ball", keywords: "celebrate party"),
        Entry(char: "🎈", name: "Balloon", keywords: "party birthday"),
        Entry(char: "🎁", name: "Wrapped Gift", keywords: "present birthday christmas"),
        Entry(char: "🏆", name: "Trophy", keywords: "winner champion prize first"),
        Entry(char: "🥇", name: "Gold Medal", keywords: "first winner best"),
        Entry(char: "🎯", name: "Bullseye", keywords: "target goal direct hit"),
        Entry(char: "🚀", name: "Rocket", keywords: "launch ship space fast startup"),
        Entry(char: "💎", name: "Gem Stone", keywords: "diamond jewel precious"),
        Entry(char: "💰", name: "Money Bag", keywords: "cash rich dollar"),
        Entry(char: "💸", name: "Money with Wings", keywords: "spend expensive cash flying"),
        Entry(char: "🪙", name: "Coin", keywords: "money gold crypto"),
        Entry(char: "📈", name: "Chart Up", keywords: "growth stocks increase gains"),
        Entry(char: "📉", name: "Chart Down", keywords: "loss stocks decrease falling"),
        // Nature and animals
        Entry(char: "☀️", name: "Sun", keywords: "sunny weather bright"),
        Entry(char: "🌙", name: "Crescent Moon", keywords: "night moon sleep"),
        Entry(char: "🌈", name: "Rainbow", keywords: "pride colorful weather"),
        Entry(char: "☁️", name: "Cloud", keywords: "weather cloudy"),
        Entry(char: "🌧️", name: "Rain Cloud", keywords: "weather raining"),
        Entry(char: "❄️", name: "Snowflake", keywords: "snow cold winter frozen"),
        Entry(char: "🌊", name: "Wave", keywords: "ocean sea water surf"),
        Entry(char: "🌸", name: "Cherry Blossom", keywords: "flower spring pink sakura"),
        Entry(char: "🌹", name: "Rose", keywords: "flower love romance"),
        Entry(char: "🌲", name: "Evergreen Tree", keywords: "tree forest nature"),
        Entry(char: "🍀", name: "Four Leaf Clover", keywords: "luck lucky irish"),
        Entry(char: "🐶", name: "Dog Face", keywords: "puppy pet animal"),
        Entry(char: "🐱", name: "Cat Face", keywords: "kitten pet animal"),
        Entry(char: "🐭", name: "Mouse Face", keywords: "animal rodent"),
        Entry(char: "🦊", name: "Fox", keywords: "animal clever"),
        Entry(char: "🐻", name: "Bear", keywords: "animal grizzly"),
        Entry(char: "🐼", name: "Panda", keywords: "animal china cute"),
        Entry(char: "🦁", name: "Lion", keywords: "animal king roar"),
        Entry(char: "🐷", name: "Pig Face", keywords: "animal oink"),
        Entry(char: "🐸", name: "Frog", keywords: "animal toad"),
        Entry(char: "🐵", name: "Monkey Face", keywords: "animal ape"),
        Entry(char: "🐔", name: "Chicken", keywords: "animal bird hen"),
        Entry(char: "🦅", name: "Eagle", keywords: "bird animal america"),
        Entry(char: "🦉", name: "Owl", keywords: "bird animal wise night"),
        Entry(char: "🦋", name: "Butterfly", keywords: "insect pretty transform"),
        Entry(char: "🐝", name: "Honeybee", keywords: "insect buzz busy"),
        Entry(char: "🐢", name: "Turtle", keywords: "animal slow tortoise"),
        Entry(char: "🐍", name: "Snake", keywords: "animal python slither"),
        Entry(char: "🐬", name: "Dolphin", keywords: "animal sea ocean"),
        Entry(char: "🐳", name: "Whale", keywords: "animal sea ocean big"),
        Entry(char: "🦈", name: "Shark", keywords: "animal sea ocean danger"),
        Entry(char: "🐙", name: "Octopus", keywords: "animal sea tentacles"),
        Entry(char: "🦄", name: "Unicorn", keywords: "magic mythical rainbow"),
        Entry(char: "🕷️", name: "Spider", keywords: "insect web spidey"),
        Entry(char: "🕸️", name: "Spider Web", keywords: "web spidey halloween"),
        Entry(char: "🦇", name: "Bat", keywords: "animal night batman halloween"),
        // Food and drink
        Entry(char: "🍕", name: "Pizza", keywords: "food slice italian"),
        Entry(char: "🍔", name: "Hamburger", keywords: "food burger fast"),
        Entry(char: "🍟", name: "French Fries", keywords: "food chips fast"),
        Entry(char: "🌮", name: "Taco", keywords: "food mexican"),
        Entry(char: "🍣", name: "Sushi", keywords: "food japanese fish"),
        Entry(char: "🍜", name: "Steaming Bowl", keywords: "food ramen noodles soup"),
        Entry(char: "🍝", name: "Spaghetti", keywords: "food pasta italian"),
        Entry(char: "🍎", name: "Red Apple", keywords: "food fruit healthy"),
        Entry(char: "🍌", name: "Banana", keywords: "food fruit"),
        Entry(char: "🍓", name: "Strawberry", keywords: "food fruit berry"),
        Entry(char: "🍉", name: "Watermelon", keywords: "food fruit summer"),
        Entry(char: "🥑", name: "Avocado", keywords: "food fruit toast"),
        Entry(char: "🍦", name: "Ice Cream", keywords: "food dessert sweet"),
        Entry(char: "🍰", name: "Cake Slice", keywords: "food dessert birthday sweet"),
        Entry(char: "🎂", name: "Birthday Cake", keywords: "food dessert celebrate"),
        Entry(char: "🍪", name: "Cookie", keywords: "food dessert biscuit sweet"),
        Entry(char: "🍫", name: "Chocolate Bar", keywords: "food dessert sweet"),
        Entry(char: "🍿", name: "Popcorn", keywords: "food movie cinema snack"),
        Entry(char: "☕", name: "Hot Beverage", keywords: "coffee tea drink morning"),
        Entry(char: "🍵", name: "Teacup", keywords: "tea drink green"),
        Entry(char: "🍺", name: "Beer Mug", keywords: "drink alcohol pint cheers"),
        Entry(char: "🍷", name: "Wine Glass", keywords: "drink alcohol red"),
        Entry(char: "🍸", name: "Cocktail Glass", keywords: "drink alcohol martini"),
        Entry(char: "🥂", name: "Clinking Glasses", keywords: "cheers celebrate toast champagne"),
        // Objects and activities
        Entry(char: "📱", name: "Mobile Phone", keywords: "iphone smartphone device"),
        Entry(char: "💻", name: "Laptop", keywords: "computer mac work code"),
        Entry(char: "⌚", name: "Watch", keywords: "time wrist apple watch"),
        Entry(char: "🎧", name: "Headphone", keywords: "music audio listen"),
        Entry(char: "🎮", name: "Video Game", keywords: "controller gaming play"),
        Entry(char: "🎵", name: "Musical Note", keywords: "music song melody"),
        Entry(char: "🎸", name: "Guitar", keywords: "music instrument rock"),
        Entry(char: "🎤", name: "Microphone", keywords: "music sing karaoke"),
        Entry(char: "📷", name: "Camera", keywords: "photo picture photography"),
        Entry(char: "🎬", name: "Clapper Board", keywords: "movie film cinema"),
        Entry(char: "📚", name: "Books", keywords: "reading study library"),
        Entry(char: "✏️", name: "Pencil", keywords: "write edit draw"),
        Entry(char: "📝", name: "Memo", keywords: "note write list document"),
        Entry(char: "📅", name: "Calendar", keywords: "date schedule day"),
        Entry(char: "📌", name: "Pushpin", keywords: "pin location save"),
        Entry(char: "🔒", name: "Locked", keywords: "secure private lock"),
        Entry(char: "🔑", name: "Key", keywords: "unlock password access"),
        Entry(char: "🔨", name: "Hammer", keywords: "tool build fix"),
        Entry(char: "🔧", name: "Wrench", keywords: "tool fix settings"),
        Entry(char: "⚙️", name: "Gear", keywords: "settings config machine"),
        Entry(char: "🧲", name: "Magnet", keywords: "attract magnetic"),
        Entry(char: "🔍", name: "Magnifying Glass", keywords: "search find zoom"),
        Entry(char: "💡", name: "Light Bulb", keywords: "idea bright think"),
        Entry(char: "🔦", name: "Flashlight", keywords: "torch light dark"),
        Entry(char: "🕯️", name: "Candle", keywords: "light flame calm"),
        Entry(char: "🛒", name: "Shopping Cart", keywords: "buy store trolley"),
        Entry(char: "✈️", name: "Airplane", keywords: "travel flight fly plane"),
        Entry(char: "🚗", name: "Car", keywords: "drive vehicle automobile"),
        Entry(char: "🚲", name: "Bicycle", keywords: "bike ride cycle"),
        Entry(char: "🏠", name: "House", keywords: "home building"),
        Entry(char: "🏢", name: "Office Building", keywords: "work city company"),
        Entry(char: "🌍", name: "Globe", keywords: "world earth planet international"),
        Entry(char: "⏰", name: "Alarm Clock", keywords: "time wake morning"),
        Entry(char: "⌛", name: "Hourglass", keywords: "time waiting sand"),
        Entry(char: "🧪", name: "Test Tube", keywords: "science experiment lab chemistry"),
        Entry(char: "🩺", name: "Stethoscope", keywords: "doctor medical health"),
        Entry(char: "💊", name: "Pill", keywords: "medicine drug health"),
        Entry(char: "🎓", name: "Graduation Cap", keywords: "education degree university school"),
        Entry(char: "⚽", name: "Soccer Ball", keywords: "football sport"),
        Entry(char: "🏀", name: "Basketball", keywords: "sport ball hoops"),
        Entry(char: "🎾", name: "Tennis", keywords: "sport ball racket"),
        Entry(char: "🏋️", name: "Weight Lifter", keywords: "gym exercise workout"),
        Entry(char: "🧘", name: "Lotus Position", keywords: "yoga meditate calm zen"),
        Entry(char: "🏔️", name: "Snow Mountain", keywords: "nature hiking peak"),
        Entry(char: "🏖️", name: "Beach", keywords: "holiday vacation sand umbrella"),
    ]

    static func search(_ term: String) -> [Entry] {
        let lowered = term.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lowered.isEmpty else { return [] }
        let nameMatches = entries.filter { $0.name.lowercased().contains(lowered) }
        let keywordMatches = entries.filter {
            !$0.name.lowercased().contains(lowered)
                && $0.keywords.split(separator: " ").contains { $0.hasPrefix(lowered) }
        }
        return Array((nameMatches + keywordMatches).prefix(8))
    }

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased()
        guard lowered.hasPrefix("emoji ") else { return [] }
        let term = String(query.dropFirst("emoji ".count))
        return search(term).enumerated().map { index, entry in
            ResultItem(
                title: "\(entry.char)  \(entry.name)",
                subtitle: "Return copies \(entry.char)",
                icon: .appIcon(image(for: entry.char)),
                score: 985 - Double(index),
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(entry.char, forType: .string)
                }
            )
        }
    }

    private static func image(for emoji: String) -> NSImage {
        NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24)]
            let size = emoji.size(withAttributes: attributes)
            emoji.draw(
                at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                withAttributes: attributes
            )
            return true
        }
    }
}
