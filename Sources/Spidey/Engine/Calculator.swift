import Foundation

// Small recursive descent evaluator: + - * / % ( ) and decimal numbers.
// Written by hand because NSExpression throws uncatchable ObjC exceptions on bad input.
enum Calculator {
    static func looksLikeExpression(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 1 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/%() ")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        // Needs at least one digit and one operator (or parens) to be worth showing.
        let hasDigit = trimmed.contains(where: \.isNumber)
        let hasOperator = trimmed.contains(where: { "+-*/%".contains($0) })
        return hasDigit && (hasOperator || trimmed.contains("("))
    }

    static func evaluate(_ text: String) -> Double? {
        var parser = Parser(text: text)
        guard let value = parser.parseExpression(), parser.atEnd else { return nil }
        return value.isFinite ? value : nil
    }

    static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private struct Parser {
        let chars: [Character]
        var pos = 0

        init(text: String) {
            chars = Array(text.filter { $0 != " " })
        }

        var atEnd: Bool { pos >= chars.count }

        mutating func parseExpression() -> Double? {
            guard var left = parseTerm() else { return nil }
            while !atEnd, chars[pos] == "+" || chars[pos] == "-" {
                let op = chars[pos]
                pos += 1
                guard let right = parseTerm() else { return nil }
                left = op == "+" ? left + right : left - right
            }
            return left
        }

        mutating func parseTerm() -> Double? {
            guard var left = parseUnary() else { return nil }
            while !atEnd, chars[pos] == "*" || chars[pos] == "/" || chars[pos] == "%" {
                let op = chars[pos]
                pos += 1
                guard let right = parseUnary() else { return nil }
                switch op {
                case "*": left *= right
                case "/": left /= right
                default: left = left.truncatingRemainder(dividingBy: right)
                }
            }
            return left
        }

        mutating func parseUnary() -> Double? {
            if !atEnd, chars[pos] == "-" {
                pos += 1
                guard let value = parseUnary() else { return nil }
                return -value
            }
            if !atEnd, chars[pos] == "+" {
                pos += 1
                return parseUnary()
            }
            return parsePrimary()
        }

        mutating func parsePrimary() -> Double? {
            guard !atEnd else { return nil }
            if chars[pos] == "(" {
                pos += 1
                guard let value = parseExpression(), !atEnd, chars[pos] == ")" else { return nil }
                pos += 1
                return value
            }
            var number = ""
            while !atEnd, chars[pos].isNumber || chars[pos] == "." {
                number.append(chars[pos])
                pos += 1
            }
            return Double(number)
        }
    }
}
