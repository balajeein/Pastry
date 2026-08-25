import Foundation

public class CalculatorEngine {
    public static let shared = CalculatorEngine()
    
    public var angleMode: AngleMode = .deg
    
    public init(angleMode: AngleMode = .deg) {
        self.angleMode = angleMode
    }
    
    /// Evaluates a string input. Returns formatted calculation result if a valid mathematical expression, otherwise nil.
    public func evaluate(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        guard trimmed.count <= 2000 else { return nil }
        
        if isNonMathPattern(trimmed) {
            return nil
        }
        
        // Check for equation solving (e.g. x + 5 = 10)
        if trimmed.contains("=") && !trimmed.hasSuffix("=") {
            if let eqResult = EquationSolver.solve(trimmed, angleMode: angleMode) {
                return eqResult
            }
            return nil
        }
        
        // Normalize trailing '=' (e.g., "2 + 2 =" -> "2 + 2")
        var normInput = trimmed
        let trailingEqualsWasPresent = normInput.hasSuffix("=")
        if trailingEqualsWasPresent {
            normInput = String(normInput.dropLast()).trimmingCharacters(in: .whitespaces)
            guard !normInput.isEmpty else { return nil }
        }
        
        guard let (tokens, hasOpOrFunc) = CalculatorTokenizer.tokenize(normInput) else {
            return nil
        }
        
        // Expression must contain at least one operation, function, constant, or trailing '='
        guard hasOpOrFunc || trailingEqualsWasPresent else {
            return nil
        }
        
        guard let ast = CalculatorParser.parse(tokens) else {
            return nil
        }
        
        let evaluator = CalculatorEvaluator(angleMode: angleMode)
        do {
            let resultValue = try evaluator.evaluate(ast)
            return CalculatorFormatter.format(resultValue)
        } catch {
            return nil
        }
    }
    
    private func isNonMathPattern(_ text: String) -> Bool {
        // Date patterns: 2026-08-24, 08/24/2026
        if text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil ||
           text.range(of: #"^\d{1,2}/\d{1,2}/\d{4}$"#, options: .regularExpression) != nil {
            return true
        }
        // Version numbers: 1.0.0, 1.1.0-beta
        if text.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) != nil {
            return true
        }
        // URLs or Emails
        if text.contains("://") || text.contains("@") {
            return true
        }
        return false
    }
}
