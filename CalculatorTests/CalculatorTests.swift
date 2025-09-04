import XCTest
@testable import Calculator

class CalculatorViewModelTests: XCTestCase {

    var viewModel: CalculatorViewModel!

    override func setUp() {
        super.setUp()
        viewModel = CalculatorViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Basic Arithmetic

    func testAddition() {
        viewModel.inputNumber("5")
        viewModel.performOperation("add")
        viewModel.inputNumber("3")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "8")
    }

    func testSubtraction() {
        viewModel.inputNumber("10")
        viewModel.performOperation("subtract")
        viewModel.inputNumber("4")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "6")
    }

    func testMultiplication() {
        viewModel.inputNumber("7")
        viewModel.performOperation("multiply")
        viewModel.inputNumber("6")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "42")
    }

    func testDivision() {
        viewModel.inputNumber("20")
        viewModel.performOperation("divide")
        viewModel.inputNumber("5")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "4")
    }

    func testDivisionByZero() {
        viewModel.inputNumber("10")
        viewModel.performOperation("divide")
        viewModel.inputNumber("0")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "0") // Or some error state, for now "0"
    }

    // MARK: - Chained Operations

    func testChainedOperations() {
        viewModel.inputNumber("10")
        viewModel.performOperation("add")
        viewModel.inputNumber("5")
        viewModel.performOperation("multiply")
        viewModel.inputNumber("2")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "30") // 10 + 5 * 2 = 30
    }

    // MARK: - State and UI

    func testClear() {
        viewModel.inputNumber("123")
        viewModel.performOperation("add")
        viewModel.clear()
        XCTAssertEqual(viewModel.display, "0")
        XCTAssertNil(viewModel.previousValue)
        XCTAssertNil(viewModel.operation)
        XCTAssertFalse(viewModel.waitingForOperand)
    }

    func testDecimalInput() {
        viewModel.inputNumber("3")
        viewModel.inputDecimal()
        viewModel.inputNumber("14")
        XCTAssertEqual(viewModel.display, "3.14")
    }

    func testMultipleDecimalInputs() {
        viewModel.inputNumber("3")
        viewModel.inputDecimal()
        viewModel.inputNumber("14")
        viewModel.inputDecimal() // Should be ignored
        XCTAssertEqual(viewModel.display, "3.14")
    }

    // MARK: - Edge Cases

    func testOperatorChange() {
        viewModel.inputNumber("10")
        viewModel.performOperation("add")
        viewModel.performOperation("multiply") // Change from + to *
        viewModel.inputNumber("5")
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "50") // 10 * 5 = 50
    }

    func testEqualsWithoutSecondOperand() {
        viewModel.inputNumber("10")
        viewModel.performOperation("add")
        viewModel.performOperation("equals")
        // This behavior can vary, but a common approach is to repeat the last operation
        // For now, let's assume it does nothing or equals itself
        XCTAssertEqual(viewModel.display, "10")
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.display, "0")
        XCTAssertEqual(viewModel.currentResult, "0")
        XCTAssertTrue(viewModel.fullEquationChain.isEmpty)
    }

    // MARK: - New Tests for Bug Fixes

    func testBackspace() {
        viewModel.inputNumber("1")
        viewModel.inputNumber("2")
        viewModel.inputNumber("3")
        XCTAssertEqual(viewModel.display, "123")

        viewModel.backspace()
        XCTAssertEqual(viewModel.display, "12")

        viewModel.performOperation("add")
        viewModel.inputNumber("5")
        XCTAssertEqual(viewModel.fullEquationChain, "12+5")

        viewModel.backspace()
        XCTAssertEqual(viewModel.fullEquationChain, "12+")

        viewModel.backspace()
        XCTAssertEqual(viewModel.fullEquationChain, "12")
    }

    func testPercentage() {
        viewModel.inputNumber("200")
        viewModel.percentage()
        XCTAssertEqual(viewModel.display, "2")

        viewModel.clear()

        viewModel.inputNumber("100")
        viewModel.performOperation("add")
        viewModel.inputNumber("50")
        viewModel.percentage() // 50% of 100
        XCTAssertEqual(viewModel.display, "0.5")
    }

    func testToggleSign() {
        viewModel.inputNumber("10")
        viewModel.performOperation("subtract")
        viewModel.inputNumber("5")
        viewModel.toggleSign() // display is now -5
        viewModel.performOperation("equals")
        XCTAssertEqual(viewModel.display, "15", "Error: 10 - (-5) should be 15")
    }
}
