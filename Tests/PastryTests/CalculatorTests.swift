import Foundation

public struct CalculatorTests {
    public static func runAll() {
        print("🧪 Running CalculatorTests...")
        
        func check(_ input: String, expected: String?, line: Int = #line) {
            let actual = CalculatorEngine.shared.evaluate(input)
            if actual != expected {
                print("❌ FAIL [line \(line)]: Expression: '\(input)' | Expected: '\(expected ?? "nil")' | Got: '\(actual ?? "nil")'")
                exit(1)
            }
        }
        
        func checkRad(_ input: String, expected: String?, line: Int = #line) {
            let engine = CalculatorEngine(angleMode: .rad)
            let actual = engine.evaluate(input)
            if actual != expected {
                print("❌ FAIL [line \(line)]: Expression (RAD): '\(input)' | Expected: '\(expected ?? "nil")' | Got: '\(actual ?? "nil")'")
                exit(1)
            }
        }
        
        // 1. Basic Arithmetic
        check("2 + 2", expected: "4")
        check("25 * 4", expected: "100")
        check("100 / 5", expected: "20")
        check("10 - 3", expected: "7")
        check("10 % 3", expected: "1")
        
        // 2. Exponentiation
        check("4^2", expected: "16")
        check("2^10", expected: "1,024")
        check("2^3^2", expected: "512")
        check("(2+3)^2", expected: "25")
        check("(-5)^2", expected: "25")
        check("-2^2", expected: "-4")
        
        // 3. Roots
        check("sqrt(16)", expected: "4")
        check("√16", expected: "4")
        check("root(27, 3)", expected: "3")
        check("27^(1/3)", expected: "3")
        check("sqrt(-1)", expected: nil)
        
        // 4. Trigonometry (DEG mode by default)
        check("sin(90)", expected: "1")
        check("cos(0)", expected: "1")
        check("tan(45)", expected: "1")
        check("asin(1)", expected: "90")
        check("acos(1)", expected: "0")
        check("atan(1)", expected: "45")
        
        // Hyperbolic functions
        check("sinh(0)", expected: "0")
        check("cosh(0)", expected: "1")
        check("tanh(0)", expected: "0")
        
        // 5. Angle Modes (RAD mode)
        checkRad("sin(pi/2)", expected: "1")
        checkRad("cos(pi)", expected: "-1")
        
        // 6. Constants
        check("pi * 2", expected: "6.2831853072")
        check("π * 2", expected: "6.2831853072")
        check("e^2", expected: "7.3890560989")
        check("tau / 2", expected: "3.1415926536")
        
        // 7. Logarithms
        check("log(100)", expected: "2")
        check("ln(e)", expected: "1")
        check("log(100, 10)", expected: "2")
        check("log(8, 2)", expected: "3")
        
        // 8. Exponential Function
        check("exp(1)", expected: "2.7182818285")
        
        // 9. Factorial
        check("5!", expected: "120")
        check("10!", expected: "3,628,800")
        check("(-5)!", expected: nil)
        
        // 10. Combinatorics
        check("5P2", expected: "20")
        check("5C2", expected: "10")
        check("perm(5, 2)", expected: "20")
        check("comb(5, 2)", expected: "10")
        
        // 11. Absolute Value
        check("abs(-5)", expected: "5")
        check("|-5|", expected: "5")
        
        // 12. Rounding Functions
        check("floor(3.9)", expected: "3")
        check("ceil(3.1)", expected: "4")
        check("round(3.6)", expected: "4")
        
        // 13. Min / Max
        check("min(2, 5)", expected: "2")
        check("max(2, 5)", expected: "5")
        check("max(2, 5, 10, 3)", expected: "10")
        
        // 14. Sign / Clamp
        check("sign(-5)", expected: "-1")
        check("sign(5)", expected: "1")
        check("clamp(15, 0, 10)", expected: "10")
        
        // 15. Implicit Multiplication
        check("2(4)", expected: "8")
        check("2(5+3)", expected: "16")
        check("3(2+4)", expected: "18")
        check("(2)(4)", expected: "8")
        check("(2+3)(4+1)", expected: "25")
        check("2pi", expected: "6.2831853072")
        check("3sin(30)", expected: "1.5")
        check("2sqrt(16)", expected: "8")
        
        // 16. Parentheses
        check("((2+3)*4)", expected: "20")
        check("(2+(3*4))", expected: "14")
        check("((2+3)(4+5))", expected: "45")
        
        // 17. Trailing '='
        check("2+2=", expected: "4")
        check("2 + 2 =", expected: "4")
        check("235*24214 =", expected: "5,690,290")
        check("(10+5)*2=", expected: "30")
        
        // 18. Scientific Notation
        check("1e3", expected: "1,000")
        check("2.5e-4", expected: "0.00025")
        
        // 19. Large Calculations
        check("99999*99999", expected: "9,999,800,001")
        
        // 20. Unicode Minus & Negative Decimals Regression Tests
        check("(−0.4)(1) + (−0.6)(2) + 0.1", expected: "-1.5")
        check("0.3113 − 0.2193 + 0.1459 + 0.2", expected: "0.4379")
        check("23 + 2345", expected: "2,368")
        check("0.5 + 0.5", expected: "1")
        check("32.232 + 234", expected: "266.232")
        check("-5 + 3", expected: "-2")
        check("-5 - 3", expected: "-8")
        check("(-5) + 3", expected: "-2")
        check("(-5)(2)", expected: "-10")
        check("−5 + 3", expected: "-2")
        check("5 − 3", expected: "2")
        check("−5 − 3", expected: "-8")
        check("(2)(3)", expected: "6")
        check("(2 + 3)(4)", expected: "20")
        check("(-2)(3)", expected: "-6")
        check("(−0.4)(1)", expected: "-0.4")
        
        // 21. Equation Solving
        check("x + 5 = 10", expected: "x = 5")
        check("2x = 10", expected: "x = 5")
        check("x^2 = 25", expected: "x = ±5")
        
        // 21. Non-Mathematical Input Rejection (Must return nil)
        check("Hello", expected: nil)
        check("Hello world", expected: nil)
        check("I have 25 apples", expected: nil)
        check("Version 1.0.0", expected: nil)
        check("iPhone 16", expected: nil)
        check("Room 204", expected: nil)
        check("2026-08-24", expected: nil)
        check("https://example.com", expected: nil)
        check("hello@example.com", expected: nil)
        check("abc123", expected: nil)
        check("2+2=4", expected: nil)
        check("1234", expected: nil)
        check("", expected: nil)
        
        print("✅ All CalculatorTests passed successfully!")
    }
}
