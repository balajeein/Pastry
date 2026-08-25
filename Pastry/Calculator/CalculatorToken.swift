import Foundation

public enum AngleMode: String, Codable, CaseIterable {
    case deg
    case rad
}

public enum CalculatorOperator: String, Equatable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"
    case power = "^"
    case factorial = "!"
    case nPr = "nPr"
    case nCr = "nCr"
}

public enum CalculatorToken: Equatable {
    case number(Double)
    case identifier(String)
    case op(CalculatorOperator)
    case lparen
    case rparen
    case verticalBar
    case comma
}
