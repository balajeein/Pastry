import Foundation

public enum ExpressionParser {
    public static func evaluate(_ input: String) -> String? {
        return CalculatorEngine.shared.evaluate(input)
    }
}
