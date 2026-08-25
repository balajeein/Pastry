import Foundation

public enum CalculatorTokenizer {
    
    private static let knownFunctions: Set<String> = [
        "sin", "cos", "tan", "asin", "acos", "atan",
        "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
        "sqrt", "root", "log", "ln", "exp", "abs",
        "floor", "ceil", "round", "min", "max",
        "sign", "clamp", "perm", "comb"
    ]
    
    private static let knownConstants: Set<String> = [
        "pi", "π", "e", "tau", "τ"
    ]
    
    private static let knownVariables: Set<String> = [
        "x", "X"
    ]
    
    /// Tokenizes input string into a tuple of tokens and boolean indicating if any operator/function/constant was found.
    public static func tokenize(_ input: String) -> (tokens: [CalculatorToken], hasOpOrFunc: Bool)? {
        var rawTokens: [CalculatorToken] = []
        var hasScientificNotation = false
        let chars = Array(input)
        var i = 0
        
        while i < chars.count {
            let ch = chars[i]
            
            if ch.isWhitespace {
                i += 1
                continue
            }
            
            // 1. Numbers (including scientific notation e.g. 1e3, 2.5e-4)
            if ch.isNumber || ch == "." {
                var numStr = ""
                var dotCount = 0
                while i < chars.count {
                    let c = chars[i]
                    if c.isNumber {
                        numStr.append(c)
                        i += 1
                    } else if c == "." {
                        dotCount += 1
                        if dotCount > 1 { return nil } // Invalid e.g. 1.0.0
                        numStr.append(c)
                        i += 1
                    } else if (c == "e" || c == "E") && i + 1 < chars.count {
                        let nextChar = chars[i + 1]
                        if nextChar.isNumber {
                            numStr.append(c)
                            i += 1
                            hasScientificNotation = true
                        } else if (nextChar == "+" || nextChar == "-") && i + 2 < chars.count && chars[i + 2].isNumber {
                            numStr.append(c)
                            numStr.append(nextChar)
                            i += 2
                            hasScientificNotation = true
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                guard let val = Double(numStr) else { return nil }
                rawTokens.append(.number(val))
                continue
            }
            
            // 2. Identifiers (functions, constants, variables)
            if ch.isLetter || ch == "π" || ch == "τ" || ch == "√" {
                var idStr = ""
                if ch == "√" {
                    idStr = "sqrt"
                    i += 1
                } else if ch == "π" || ch == "τ" {
                    idStr = String(ch)
                    i += 1
                } else {
                    while i < chars.count && chars[i].isLetter {
                        idStr.append(chars[i])
                        i += 1
                    }
                }
                
                let lowerId = idStr.lowercased()
                
                if lowerId == "npr" || (idStr == "P" && !rawTokens.isEmpty) || (lowerId == "p" && !rawTokens.isEmpty) {
                    rawTokens.append(.op(.nPr))
                    continue
                } else if lowerId == "ncr" || (idStr == "C" && !rawTokens.isEmpty) || (lowerId == "c" && !rawTokens.isEmpty) {
                    rawTokens.append(.op(.nCr))
                    continue
                }
                
                if knownFunctions.contains(lowerId) {
                    rawTokens.append(.identifier(lowerId))
                } else if knownConstants.contains(lowerId) || knownConstants.contains(idStr) {
                    rawTokens.append(.identifier(idStr))
                } else if knownVariables.contains(idStr) {
                    rawTokens.append(.identifier(idStr))
                } else {
                    // Unrecognized word -> reject
                    return nil
                }
                continue
            }
            
            // 3. Operators
            if ch == "+" || ch == "-" || ch == "*" || ch == "/" || ch == "%" || ch == "^" || ch == "!" {
                let op: CalculatorOperator
                switch ch {
                case "+": op = .add
                case "-": op = .subtract
                case "*": op = .multiply
                case "/": op = .divide
                case "%": op = .modulo
                case "^": op = .power
                case "!": op = .factorial
                default: return nil
                }
                rawTokens.append(.op(op))
                i += 1
                continue
            }
            
            // 4. Punctuation
            if ch == "(" {
                rawTokens.append(.lparen)
                i += 1
                continue
            }
            
            if ch == ")" {
                rawTokens.append(.rparen)
                i += 1
                continue
            }
            
            if ch == "|" {
                rawTokens.append(.verticalBar)
                i += 1
                continue
            }
            
            if ch == "," {
                rawTokens.append(.comma)
                i += 1
                continue
            }
            
            return nil
        }
        
        guard !rawTokens.isEmpty else { return nil }
        
        let processedTokens = insertImplicitMultiplication(rawTokens)
        let hasOpOrFunc = hasScientificNotation || processedTokens.contains { token in
            switch token {
            case .op, .identifier, .verticalBar:
                return true
            default:
                return false
            }
        }
        
        return (processedTokens, hasOpOrFunc)
    }
    
    private static func insertImplicitMultiplication(_ tokens: [CalculatorToken]) -> [CalculatorToken] {
        var result: [CalculatorToken] = []
        var isVerticalBarOpen = false
        
        for idx in 0..<tokens.count {
            let curr = tokens[idx]
            
            if idx > 0 {
                let prev = tokens[idx - 1]
                if canEndFactor(prev, isVerticalBarOpen: isVerticalBarOpen) && canStartFactor(curr, isVerticalBarOpen: isVerticalBarOpen) {
                    result.append(.op(.multiply))
                }
            }
            
            if curr == .verticalBar {
                isVerticalBarOpen.toggle()
            }
            
            result.append(curr)
        }
        
        return result
    }
    
    private static func canEndFactor(_ token: CalculatorToken, isVerticalBarOpen: Bool) -> Bool {
        switch token {
        case .number, .rparen:
            return true
        case .identifier(let id):
            let lower = id.lowercased()
            return knownConstants.contains(lower) || knownConstants.contains(id) || knownVariables.contains(id)
        case .op(let op):
            return op == .factorial
        case .verticalBar:
            return isVerticalBarOpen
        default:
            return false
        }
    }
    
    private static func canStartFactor(_ token: CalculatorToken, isVerticalBarOpen: Bool) -> Bool {
        switch token {
        case .number, .lparen, .identifier:
            return true
        case .verticalBar:
            return !isVerticalBarOpen
        default:
            return false
        }
    }
}
