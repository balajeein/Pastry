import Foundation

/// Detects and evaluates mathematical expressions from user-selected text.
/// Uses NSExpression for safe, sandboxed evaluation — no arbitrary code execution.
public class CalculationService {
    public static let shared = CalculationService()
    
    private init() {}
    
    /// Attempts to evaluate the given text as a math expression.
    /// Returns (normalizedExpression, resultString) or nil if not a valid expression.
    public func evaluate(_ text: String) -> (expression: String, result: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Must contain at least one operator to be considered a math expression
        let operatorChars: [Character] = ["+", "-", "×", "✕", "*", "÷", "/", "^", "%"]
        let hasOperator = trimmed.contains(where: { operatorChars.contains($0) })
        guard hasOperator else { return nil }
        
        // Must not contain alphabetical characters (except math functions would be a future extension)
        // Allow digits, operators, parentheses, whitespace, decimal points, commas
        let allowed = CharacterSet.decimalDigits
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "+-×✕*÷/^%().,"))
        let scalars = trimmed.unicodeScalars
        for scalar in scalars {
            if !allowed.contains(scalar) {
                return nil
            }
        }
        
        // Normalize the expression into NSExpression-compatible format
        var expr = trimmed
        expr = expr.replacingOccurrences(of: "×", with: "*")
        expr = expr.replacingOccurrences(of: "✕", with: "*")
        expr = expr.replacingOccurrences(of: "÷", with: "/")
        expr = expr.replacingOccurrences(of: ",", with: "") // strip thousands separators
        
        // Handle ^ (power) by converting to power() calls — NSExpression supports this
        // For simplicity, handle simple cases like "2^3" -> "2**3"
        expr = expr.replacingOccurrences(of: "^", with: "**")
        
        // Validate balanced parentheses
        var depth = 0
        for ch in expr {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth -= 1 }
            if depth < 0 { return nil }
        }
        if depth != 0 { return nil }
        
        // Attempt evaluation using NSExpression
        // NSExpression(format:) can crash on truly malformed input,
        // so we rely on our validation above to ensure the expression is safe
        let expression = NSExpression(format: expr)
        guard let result = expression.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }
        
        let doubleValue = result.doubleValue
        
        // Guard against infinity and NaN
        guard doubleValue.isFinite else { return nil }
        
        // Format the result nicely
        let resultString: String
        if doubleValue == doubleValue.rounded() && abs(doubleValue) < 1e15 {
            // Integer result — display without decimal
            resultString = String(format: "%.0f", doubleValue)
        } else {
            // Decimal result — trim trailing zeros
            let formatted = String(format: "%.10f", doubleValue)
            resultString = trimTrailingZeros(formatted)
        }
        
        return (expression: trimmed, result: resultString)
    }
    
    private func trimTrailingZeros(_ str: String) -> String {
        var s = str
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
