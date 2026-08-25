import Foundation

public enum CalculatorEvalError: Error {
    case divisionByZero
    case invalidArgument
    case overflow
    case undefinedVariable
}

public class CalculatorEvaluator {
    public var angleMode: AngleMode
    
    public init(angleMode: AngleMode = .deg) {
        self.angleMode = angleMode
    }
    
    public func evaluate(_ node: ASTNode, variableValue: Double? = nil) throws -> Double {
        switch node {
        case .number(let val):
            return val
            
        case .constant(_, let val):
            return val
            
        case .variable:
            guard let val = variableValue else {
                throw CalculatorEvalError.undefinedVariable
            }
            return val
            
        case .unary(let op, let child):
            let val = try evaluate(child, variableValue: variableValue)
            switch op {
            case .add: return val
            case .subtract: return -val
            default: throw CalculatorEvalError.invalidArgument
            }
            
        case .postfix(let op, let child):
            let val = try evaluate(child, variableValue: variableValue)
            switch op {
            case .factorial:
                return try calculateFactorial(val)
            case .modulo:
                return val / 100.0
            default:
                throw CalculatorEvalError.invalidArgument
            }
            
        case .binary(let op, let left, let right):
            let lVal = try evaluate(left, variableValue: variableValue)
            let rVal = try evaluate(right, variableValue: variableValue)
            
            switch op {
            case .add:
                return lVal + rVal
            case .subtract:
                return lVal - rVal
            case .multiply:
                return lVal * rVal
            case .divide:
                guard abs(rVal) > 1e-15 else { throw CalculatorEvalError.divisionByZero }
                let res = lVal / rVal
                guard res.isFinite else { throw CalculatorEvalError.overflow }
                return res
            case .modulo:
                guard abs(rVal) > 1e-15 else { throw CalculatorEvalError.divisionByZero }
                return lVal.truncatingRemainder(dividingBy: rVal)
            case .power:
                return try calculatePower(base: lVal, exponent: rVal)
            case .nPr:
                return try calculatePermutations(n: lVal, r: rVal)
            case .nCr:
                return try calculateCombinations(n: lVal, r: rVal)
            default:
                throw CalculatorEvalError.invalidArgument
            }
            
        case .absoluteValue(let child):
            let val = try evaluate(child, variableValue: variableValue)
            return abs(val)
            
        case .functionCall(let name, let args):
            return try evaluateFunction(name: name, args: args, variableValue: variableValue)
        }
    }
    
    private func evaluateFunction(name: String, args: [ASTNode], variableValue: Double?) throws -> Double {
        let values = try args.map { try evaluate($0, variableValue: variableValue) }
        
        switch name {
        // Trigonometry
        case "sin":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            let rad = angleMode == .deg ? values[0] * .pi / 180.0 : values[0]
            return sin(rad)
        case "cos":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            let rad = angleMode == .deg ? values[0] * .pi / 180.0 : values[0]
            return cos(rad)
        case "tan":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            let rad = angleMode == .deg ? values[0] * .pi / 180.0 : values[0]
            let c = cos(rad)
            guard abs(c) > 1e-15 else { throw CalculatorEvalError.invalidArgument }
            return tan(rad)
            
        // Inverse Trig
        case "asin":
            guard values.count == 1, values[0] >= -1.0 && values[0] <= 1.0 else { throw CalculatorEvalError.invalidArgument }
            let rad = asin(values[0])
            return angleMode == .deg ? rad * 180.0 / .pi : rad
        case "acos":
            guard values.count == 1, values[0] >= -1.0 && values[0] <= 1.0 else { throw CalculatorEvalError.invalidArgument }
            let rad = acos(values[0])
            return angleMode == .deg ? rad * 180.0 / .pi : rad
        case "atan":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            let rad = atan(values[0])
            return angleMode == .deg ? rad * 180.0 / .pi : rad
            
        // Hyperbolic
        case "sinh":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return sinh(values[0])
        case "cosh":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return cosh(values[0])
        case "tanh":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return tanh(values[0])
        case "asinh":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return asinh(values[0])
        case "acosh":
            guard values.count == 1, values[0] >= 1.0 else { throw CalculatorEvalError.invalidArgument }
            return acosh(values[0])
        case "atanh":
            guard values.count == 1, abs(values[0]) < 1.0 else { throw CalculatorEvalError.invalidArgument }
            return atanh(values[0])
            
        // Roots
        case "sqrt":
            guard values.count == 1, values[0] >= 0 else { throw CalculatorEvalError.invalidArgument }
            return sqrt(values[0])
        case "root":
            guard values.count == 2 else { throw CalculatorEvalError.invalidArgument }
            let x = values[0]
            let n = values[1]
            return try calculatePower(base: x, exponent: 1.0 / n)
            
        // Logarithms
        case "log":
            if values.count == 1 {
                guard values[0] > 0 else { throw CalculatorEvalError.invalidArgument }
                return log10(values[0])
            } else if values.count == 2 {
                let x = values[0]
                let base = values[1]
                guard x > 0, base > 0, abs(base - 1.0) > 1e-12 else { throw CalculatorEvalError.invalidArgument }
                return log(x) / log(base)
            } else {
                throw CalculatorEvalError.invalidArgument
            }
        case "ln":
            guard values.count == 1, values[0] > 0 else { throw CalculatorEvalError.invalidArgument }
            return log(values[0])
            
        // Exponentials
        case "exp":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            let res = exp(values[0])
            guard res.isFinite else { throw CalculatorEvalError.overflow }
            return res
            
        // Utility
        case "abs":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return abs(values[0])
        case "floor":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return floor(values[0])
        case "ceil":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return ceil(values[0])
        case "round":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return round(values[0])
        case "sign":
            guard values.count == 1 else { throw CalculatorEvalError.invalidArgument }
            return values[0] > 0 ? 1.0 : (values[0] < 0 ? -1.0 : 0.0)
        case "clamp":
            guard values.count == 3 else { throw CalculatorEvalError.invalidArgument }
            let val = values[0]
            let minV = values[1]
            let maxV = values[2]
            return min(max(val, minV), maxV)
        case "min":
            guard !values.isEmpty else { throw CalculatorEvalError.invalidArgument }
            return values.min()!
        case "max":
            guard !values.isEmpty else { throw CalculatorEvalError.invalidArgument }
            return values.max()!
            
        // Combinatorics functions
        case "perm":
            guard values.count == 2 else { throw CalculatorEvalError.invalidArgument }
            return try calculatePermutations(n: values[0], r: values[1])
        case "comb":
            guard values.count == 2 else { throw CalculatorEvalError.invalidArgument }
            return try calculateCombinations(n: values[0], r: values[1])
            
        default:
            throw CalculatorEvalError.invalidArgument
        }
    }
    
    private func calculateFactorial(_ val: Double) throws -> Double {
        guard val >= 0, abs(val - round(val)) < 1e-9 else {
            throw CalculatorEvalError.invalidArgument
        }
        let n = Int(round(val))
        guard n <= 170 else { throw CalculatorEvalError.overflow }
        
        var result: Double = 1.0
        if n == 0 || n == 1 { return 1.0 }
        for i in 2...n {
            result *= Double(i)
        }
        return result
    }
    
    private func calculatePower(base: Double, exponent: Double) throws -> Double {
        if base < 0 {
            let roundExp = round(exponent)
            if abs(exponent - roundExp) < 1e-9 {
                let expInt = Int(roundExp)
                let res = pow(base, Double(expInt))
                guard res.isFinite else { throw CalculatorEvalError.overflow }
                return res
            }
            let invExp = round(1.0 / exponent)
            if abs((1.0 / exponent) - invExp) < 1e-9 {
                let invInt = Int(invExp)
                if invInt % 2 != 0 {
                    let res = -pow(-base, exponent)
                    guard res.isFinite else { throw CalculatorEvalError.overflow }
                    return res
                }
            }
            throw CalculatorEvalError.invalidArgument
        }
        
        let res = pow(base, exponent)
        guard res.isFinite else { throw CalculatorEvalError.overflow }
        return res
    }
    
    private func calculatePermutations(n: Double, r: Double) throws -> Double {
        guard n >= 0, r >= 0, r <= n, abs(n - round(n)) < 1e-9, abs(r - round(r)) < 1e-9 else {
            throw CalculatorEvalError.invalidArgument
        }
        let nInt = Int(round(n))
        let rInt = Int(round(r))
        
        var result: Double = 1.0
        if rInt == 0 { return 1.0 }
        for i in (nInt - rInt + 1)...nInt {
            result *= Double(i)
            guard result.isFinite else { throw CalculatorEvalError.overflow }
        }
        return result
    }
    
    private func calculateCombinations(n: Double, r: Double) throws -> Double {
        guard n >= 0, r >= 0, r <= n, abs(n - round(n)) < 1e-9, abs(r - round(r)) < 1e-9 else {
            throw CalculatorEvalError.invalidArgument
        }
        let nInt = Int(round(n))
        let rInt = Int(round(r))
        let k = min(rInt, nInt - rInt)
        
        var result: Double = 1.0
        if k == 0 { return 1.0 }
        for i in 1...k {
            result = result * Double(nInt - i + 1) / Double(i)
        }
        return result
    }
}
