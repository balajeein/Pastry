import Foundation

@main
struct TestRunner {
    static func main() {
        CalculatorTests.runAll()
        ClipboardTests.runAll()
        ScreenshotTests.runAll()
        ScrollScreenshotTests.runAll()
        TextShortcutTests.runAll()
    }
}
