import Foundation

public enum EquationSolver {
    /// Attempts to solve simple 1-variable equations like `x + 5 = 10`, `2x = 10`, `x^2 = 25`.
    /// Returns formatted result string (e.g. `x = 5` or `x = ±5`) if solved, or nil if unsupported/invalid.
    public static func solve(_ input: String, angleMode: AngleMode = .deg) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("=") else { return nil }
        
        let parts = trimmed.components(separatedBy: "=")
        guard parts.count == 2 else { return nil }
        
        let leftStr = parts[0].trimmingCharacters(in: .whitespaces)
        let rightStr = parts[1].trimmingCharacters(in: .whitespaces)
        
        guard !leftStr.isEmpty && !rightStr.isEmpty else { return nil }
        
        let hasX = leftStr.contains("x") || leftStr.contains("X") || rightStr.contains("x") || rightStr.contains("X")
        guard hasX else { return nil }
        
        guard let (leftTokens, _) = CalculatorTokenizer.tokenize(leftStr),
              let (rightTokens, _) = CalculatorTokenizer.tokenize(rightStr),
              let leftAST = CalculatorParser.parse(leftTokens),
              let rightAST = CalculatorParser.parse(rightTokens) else {
            return nil
        }
        
        let evaluator = CalculatorEvaluator(angleMode: angleMode)
        
        func f(_ xVal: Double) -> Double? {
            do {
                let l = try evaluator.evaluate(leftAST, variableValue: xVal)
                let r = try evaluator.evaluate(rightAST, variableValue: xVal)
                let diff = l - r
                return (diff.isNaN || diff.isInfinite) ? nil : diff
            } catch {
                return nil
            }
        }
        
        guard let f0 = f(0), let f1 = f(1), let f_1 = f(-1), let f2 = f(2) else {
            return nil
        }
        
        let c = f0
        let a = (f1 + f_1 - 2 * f0) / 2.0
        let b = (f1 - f_1) / 2.0
        
        let f2_expected = a * 4.0 + b * 2.0 + c
        guard abs(f2 - f2_expected) < 1e-7 else {
            return nil
        }
        
        // Linear case
        if abs(a) < 1e-9 {
            guard abs(b) > 1e-9 else { return nil }
            let xSol = -c / b
            guard let formatted = CalculatorFormatter.format(xSol) else { return nil }
            return "x = \(formatted)"
        }
        
        // Quadratic case
        let disc = b * b - 4 * a * c
        guard disc >= -1e-9 else { return nil }
        
        let safeDisc = max(0.0, disc)
        
        if abs(b) < 1e-9 && c < 0 && a > 0 {
            let k = -c / a
            let rootK = sqrt(k)
            guard let formatted = CalculatorFormatter.format(rootK) else { return nil }
            return "x = ±\(formatted)"
        }
        
        if safeDisc < 1e-9 {
            let xSol = -b / (2 * a)
            guard let formatted = CalculatorFormatter.format(xSol) else { return nil }
            return "x = \(formatted)"
        } else {
            let x1 = (-b + sqrt(safeDisc)) / (2 * a)
            let x2 = (-b - sqrt(safeDisc)) / (2 * a)
            guard let fmt1 = CalculatorFormatter.format(x1),
                  let fmt2 = CalculatorFormatter.format(x2) else { return nil }
            let (first, second) = x1 < x2 ? (fmt1, fmt2) : (fmt2, fmt1)
            return "x = \(first), \(second)"
        }
    }
}
