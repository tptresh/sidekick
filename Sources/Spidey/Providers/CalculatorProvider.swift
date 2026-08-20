import AppKit

enum CalculatorProvider {
    static func results(for query: String) -> [ResultItem] {
        guard Calculator.looksLikeExpression(query),
              let value = Calculator.evaluate(query) else { return [] }
        let formatted = Calculator.format(value)
        return [ResultItem(
            title: "= \(formatted)",
            subtitle: "Press Return to copy the result",
            icon: .symbol("equal.circle.fill"),
            score: 1000,
            action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(formatted, forType: .string)
            }
        )]
    }
}
