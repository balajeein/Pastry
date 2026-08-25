import Foundation

public enum CalculatorParser {
    
    public static func parse(_ tokens: [CalculatorToken]) -> ASTNode? {
        var index = 0
        guard let ast = parseAdditive(tokens, index: &index) else { return nil }
        guard index == tokens.count else { return nil }
        return ast
    }
    
    // Level 1: Additive (+, -)
    private static func parseAdditive(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard var left = parseMultiplicative(tokens, index: &index) else { return nil }
        
        while index < tokens.count {
            let token = tokens[index]
            if case .op(let op) = token, (op == .add || op == .subtract) {
                index += 1
                guard let right = parseMultiplicative(tokens, index: &index) else { return nil }
                left = .binary(op: op, left: left, right: right)
            } else {
                break
            }
        }
        
        return left
    }
    
    // Level 2: Multiplicative (*, /, %, nPr, nCr)
    private static func parseMultiplicative(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard var left = parseUnary(tokens, index: &index) else { return nil }
        
        while index < tokens.count {
            let token = tokens[index]
            if case .op(let op) = token, (op == .multiply || op == .divide || op == .modulo || op == .nPr || op == .nCr) {
                index += 1
                guard let right = parseUnary(tokens, index: &index) else { return nil }
                left = .binary(op: op, left: left, right: right)
            } else {
                break
            }
        }
        
        return left
    }
    
    // Level 3: Prefix Unary (+, -)
    private static func parseUnary(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard index < tokens.count else { return nil }
        let token = tokens[index]
        
        if case .op(let op) = token, (op == .add || op == .subtract) {
            index += 1
            guard let child = parseUnary(tokens, index: &index) else { return nil }
            return .unary(op: op, child: child)
        }
        
        return parseExponentiation(tokens, index: &index)
    }
    
    // Level 4: Exponentiation (^) - Right Associative
    private static func parseExponentiation(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard let left = parsePostfix(tokens, index: &index) else { return nil }
        
        if index < tokens.count, case .op(let op) = tokens[index], op == .power {
            index += 1
            guard let right = parseExponentiation(tokens, index: &index) else { return nil }
            return .binary(op: .power, left: left, right: right)
        }
        
        return left
    }
    
    // Level 5: Postfix operators (!, %)
    private static func parsePostfix(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard var node = parsePrimary(tokens, index: &index) else { return nil }
        
        while index < tokens.count {
            let token = tokens[index]
            if case .op(let op) = token, op == .factorial {
                index += 1
                node = .postfix(op: .factorial, child: node)
            } else if case .op(let op) = token, op == .modulo {
                if index + 1 < tokens.count && canStartFactor(tokens[index + 1]) {
                    break // Infix modulo, handle in parseMultiplicative
                } else {
                    index += 1
                    node = .postfix(op: .modulo, child: node)
                }
            } else {
                break
            }
        }
        
        return node
    }
    
    private static func canStartFactor(_ token: CalculatorToken) -> Bool {
        switch token {
        case .number, .lparen, .verticalBar, .identifier:
            return true
        case .op(let op):
            return op == .add || op == .subtract
        default:
            return false
        }
    }
    
    // Level 6: Primary (Numbers, Constants, Variables, Function calls, Parentheses, Vertical bars)
    private static func parsePrimary(_ tokens: [CalculatorToken], index: inout Int) -> ASTNode? {
        guard index < tokens.count else { return nil }
        let token = tokens[index]
        
        switch token {
        case .number(let val):
            index += 1
            return .number(val)
            
        case .identifier(let id):
            index += 1
            let lower = id.lowercased()
            
            if lower == "pi" || id == "π" {
                return .constant(id, Double.pi)
            } else if lower == "e" {
                return .constant(id, M_E)
            } else if lower == "tau" || id == "τ" {
                return .constant(id, Double.pi * 2.0)
            } else if lower == "x" {
                return .variable(id)
            }
            
            var args: [ASTNode] = []
            
            if index < tokens.count && tokens[index] == .lparen {
                index += 1 // consume '('
                if index < tokens.count && tokens[index] == .rparen {
                    index += 1 // empty args
                } else {
                    while index < tokens.count {
                        guard let arg = parseAdditive(tokens, index: &index) else { return nil }
                        args.append(arg)
                        
                        if index < tokens.count && tokens[index] == .comma {
                            index += 1 // consume ','
                        } else if index < tokens.count && tokens[index] == .rparen {
                            index += 1 // consume ')'
                            break
                        } else {
                            return nil
                        }
                    }
                }
            } else {
                // Function without parentheses e.g. sqrt 16 or √16
                guard let arg = parseUnary(tokens, index: &index) else { return nil }
                args.append(arg)
            }
            
            return .functionCall(name: lower, args: args)
            
        case .lparen:
            index += 1 // consume '('
            guard let inner = parseAdditive(tokens, index: &index) else { return nil }
            guard index < tokens.count, tokens[index] == .rparen else { return nil }
            index += 1 // consume ')'
            return inner
            
        case .verticalBar:
            index += 1 // consume '|'
            guard let inner = parseAdditive(tokens, index: &index) else { return nil }
            guard index < tokens.count, tokens[index] == .verticalBar else { return nil }
            index += 1 // consume '|'
            return .absoluteValue(child: inner)
            
        default:
            return nil
        }
    }
}
