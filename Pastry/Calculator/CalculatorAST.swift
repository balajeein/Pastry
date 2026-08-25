import Foundation

public indirect enum ASTNode: Equatable {
    case number(Double)
    case constant(String, Double)
    case variable(String)
    case unary(op: CalculatorOperator, child: ASTNode)
    case binary(op: CalculatorOperator, left: ASTNode, right: ASTNode)
    case postfix(op: CalculatorOperator, child: ASTNode)
    case functionCall(name: String, args: [ASTNode])
    case absoluteValue(child: ASTNode)
}
