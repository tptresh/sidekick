import Foundation

// For any plain query, offer to look the show up on each enabled streaming service.
enum StreamingProvider {
    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, !Calculator.looksLikeExpression(trimmed) else { return [] }
        let encoded = BrowserLauncher.encodeQuery(trimmed)
        return SettingsStore.shared.activeStreamingServices.enumerated().map { index, service in
            let url = service.searchURL(encoded)
            return ResultItem(
                title: "Watch \"\(trimmed)\" on \(service.name)",
                subtitle: "Opens the \(service.name) search in \(BrowserLauncher.targetName)",
                icon: .symbol("play.tv.fill"),
                score: 200 - Double(index),
                action: { BrowserLauncher.open(url) }
            )
        }
    }
}
