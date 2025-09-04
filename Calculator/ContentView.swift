import SwiftUI

// MARK: - Calculation History Model
struct CalculationHistory: Identifiable, Codable {
    let id = UUID()
    let expression: String
    let result: String
    let timestamp: Date
}

// MARK: - ViewOffsetKey for tracking scroll positions
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// MARK: - CalculatorViewModel
class CalculatorViewModel: ObservableObject {
    @Published var display = "0"
    @Published var previousValue: Double?
    @Published var operation: String?
    @Published var waitingForOperand = false
    @Published var history: [CalculationHistory] = []
    @Published var fullEquationChain = ""
    @Published var currentResult = "0"
    @Published var pressedButton: String?
    @Published private var historyOpacities: [UUID: Double] = [:]
    
    init() {
        loadHistory()
    }
    
    // MARK: - Number Input
    func inputNumber(_ num: String) {
        if waitingForOperand {
            display = num
            waitingForOperand = false
            
            if let prevValue = previousValue, let op = operation {
                let newChain = fullEquationChain + num
                fullEquationChain = newChain
                
                // Calculate real-time result
                let inputValue = Double(num) ?? 0
                let result = calculate(firstValue: prevValue, secondValue: inputValue, operation: op)
                currentResult = formatNumber(result)
            } else {
                fullEquationChain = num
                currentResult = num
            }
        } else {
            let newDisplay = display == "0" ? num : display + num
            display = newDisplay
            
            if let prevValue = previousValue, let op = operation {
                let newChain = String(fullEquationChain.dropLast(display.count - num.count)) + newDisplay
                fullEquationChain = newChain
                
                // Calculate real-time result
                let inputValue = Double(newDisplay) ?? 0
                let result = calculate(firstValue: prevValue, secondValue: inputValue, operation: op)
                currentResult = formatNumber(result)
            } else {
                fullEquationChain = newDisplay
                currentResult = newDisplay
            }
        }
    }
    
    // MARK: - Decimal Input
    func inputDecimal() {
        if waitingForOperand {
            display = "0."
            waitingForOperand = false
            
            if previousValue != nil && operation != nil {
                let newChain = fullEquationChain + "0."
                fullEquationChain = newChain
                currentResult = "0."
            } else {
                fullEquationChain = "0."
                currentResult = "0."
            }
        } else if !display.contains(".") {
            let newDisplay = display + "."
            display = newDisplay
            
            if previousValue != nil && operation != nil {
                let newChain = String(fullEquationChain.dropLast(display.count - 1)) + newDisplay
                fullEquationChain = newChain
            } else {
                fullEquationChain = newDisplay
                currentResult = newDisplay
            }
        }
    }
    
    // MARK: - Clear
    func clear() {
        display = "0"
        previousValue = nil
        operation = nil
        waitingForOperand = false
        fullEquationChain = ""
        currentResult = "0"
    }
    
    // MARK: - Operations
    func performOperation(_ nextOperation: String) {
        let inputValue = Double(display) ?? 0
        
        // Handle equals operation separately
        if nextOperation == "equals" {
            handleEqualsOperation()
            return
        }
        
        // Handle other operations (+, -, ×, ÷)
        if previousValue == nil {
            // First number, set it as previous value
            previousValue = inputValue
            operation = nextOperation
            if inputValue == 0 && nextOperation == "subtract" {
                fullEquationChain = getOperationSymbol(nextOperation)
            } else {
                fullEquationChain = display + getOperationSymbol(nextOperation)
            }
            waitingForOperand = true
        } else if let currentOperation = operation {
            // There's already a pending operation
            if waitingForOperand {
                // User pressed operator after operator (like 12+×), replace the operator
                operation = nextOperation
                // Remove the last operator and add the new one
                if let lastChar = fullEquationChain.last, ["+", "−", "×", "÷"].contains(String(lastChar)) {
                    fullEquationChain = String(fullEquationChain.dropLast()) + getOperationSymbol(nextOperation)
                }
            } else {
                // Complete the pending operation first
                let result = calculate(firstValue: previousValue!, secondValue: inputValue, operation: currentOperation)
                display = formatNumber(result)
                currentResult = formatNumber(result)
                previousValue = result
                operation = nextOperation
                fullEquationChain = fullEquationChain + getOperationSymbol(nextOperation)
                waitingForOperand = true
            }
        }
    }
    
    // MARK: - Handle Equals Operation
    private func handleEqualsOperation() {
        // Check if there's a trailing operator (expression ends with operator and we're waiting for operand)
        let operators = ["+", "−", "×", "÷"]
        let hasTrailingOperator = !fullEquationChain.isEmpty &&
                                  operators.contains(String(fullEquationChain.last!)) &&
                                  waitingForOperand
        
        if hasTrailingOperator {
            // Expression like "12+3+" - ignore the trailing operator
            let completeExpression = String(fullEquationChain.dropLast()) // Remove trailing operator
            let result = evaluateCompleteExpression(completeExpression)
            
            addToHistory(expression: completeExpression, result: formatNumber(result))
            display = formatNumber(result)
            currentResult = formatNumber(result)
            fullEquationChain = formatNumber(result)
            
        } else if let prevValue = previousValue, let op = operation, !waitingForOperand {
            // Normal calculation like "12+3" then equals
            let inputValue = Double(display) ?? 0
            let result = calculate(firstValue: prevValue, secondValue: inputValue, operation: op)
            
            addToHistory(expression: fullEquationChain, result: formatNumber(result))
            display = formatNumber(result)
            currentResult = formatNumber(result)
            fullEquationChain = formatNumber(result)
            
        } else {
            // Just a number, no operation
            let currentValue = display
            addToHistory(expression: currentValue, result: currentValue)
            currentResult = currentValue
        }
        
        // Reset operation state
        previousValue = nil
        operation = nil
        waitingForOperand = false
    }
    
    // MARK: - Evaluate Complete Expression
    private func evaluateCompleteExpression(_ expression: String) -> Double {
        let operators = ["+", "−", "×", "÷"]
        var result: Double = 0
        var currentNumber = ""
        var currentOperator = ""
        var isFirstNumber = true
        
        for char in expression {
            let charStr = String(char)
            
            if operators.contains(charStr) {
                if !currentNumber.isEmpty {
                    let number = Double(currentNumber) ?? 0
                    if isFirstNumber {
                        result = number
                        isFirstNumber = false
                    } else if !currentOperator.isEmpty {
                        result = calculate(firstValue: result, secondValue: number, operation: getOperationFromSymbol(currentOperator))
                    }
                    currentNumber = ""
                }
                currentOperator = charStr
            } else {
                currentNumber += charStr
            }
        }
        
        // Handle the last number
        if !currentNumber.isEmpty {
            let number = Double(currentNumber) ?? 0
            if isFirstNumber {
                result = number
            } else if !currentOperator.isEmpty {
                result = calculate(firstValue: result, secondValue: number, operation: getOperationFromSymbol(currentOperator))
            }
        }
        
        return result
    }
    
    // MARK: - Helper to get complete expression without trailing operators
    private func getCompleteExpression(_ expression: String) -> String {
        let operators = ["+", "−", "×", "÷"]
        var result = expression
        
        // Remove trailing operators
        while !result.isEmpty && operators.contains(String(result.last!)) {
            result = String(result.dropLast())
        }
        
        return result
    }
    
    // MARK: - Calculate
    private func calculate(firstValue: Double, secondValue: Double, operation: String) -> Double {
        switch operation {
        case "add":
            return firstValue + secondValue
        case "subtract":
            return firstValue - secondValue
        case "multiply":
            return firstValue * secondValue
        case "divide":
            return secondValue != 0 ? firstValue / secondValue : 0
        case "equals":
            return secondValue
        default:
            return secondValue
        }
    }
    
    // MARK: - Helper Functions
    private func getOperationSymbol(_ op: String) -> String {
        switch op {
        case "add": return "+"
        case "subtract": return "−"
        case "multiply": return "×"
        case "divide": return "÷"
        default: return ""
        }
    }
    
    private func formatNumber(_ num: Double) -> String {
        if num == 0 { return "0" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 9
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: num)) ?? "0"
    }
    
    // MARK: - Percentage
    func percentage() {
        let value = (Double(display) ?? 0) / 100
        let result = formatNumber(value)
        display = result
        
        if !fullEquationChain.isEmpty {
            fullEquationChain = fullEquationChain.replacingOccurrences(of: display, with: "\(display)%")
        } else {
            fullEquationChain = "\(display)%"
        }
        currentResult = result
    }
    
    // MARK: - Toggle Sign
    func toggleSign() {
        if display != "0" {
            let oldDisplay = display
            let newDisplay = display.hasPrefix("-") ? String(display.dropFirst()) : "-" + display
            display = newDisplay
            
            if !fullEquationChain.isEmpty {
                if fullEquationChain.hasSuffix(oldDisplay) {
                    fullEquationChain = String(fullEquationChain.dropLast(oldDisplay.count)) + newDisplay
                }
            } else {
                fullEquationChain = newDisplay
            }
            currentResult = newDisplay
        }
    }
    
    // MARK: - Backspace
    func backspace() {
        if fullEquationChain.count > 0 {
            // Remove one character from the equation chain
            let newChain = String(fullEquationChain.dropLast())
            
            if newChain.isEmpty {
                // If chain is empty, reset everything
                clear()
                return
            }
            
            fullEquationChain = newChain
            
            // Parse the expression without spaces
            let result = evaluateExpression(newChain)
            currentResult = formatNumber(result.value)
            display = result.lastNumber
            previousValue = result.previousValue
            operation = result.operation
            waitingForOperand = result.waitingForOperand
        } else if display != "0" && display.count > 0 {
            // Fallback to original display-based backspace
            var newDisplay = String(display.dropLast())
            if newDisplay.isEmpty || newDisplay == "-" {
                newDisplay = "0"
            }
            display = newDisplay
            currentResult = newDisplay
            
            if newDisplay == "0" {
                clear()
            }
        }
    }
    
    // MARK: - Expression Evaluator
    private func evaluateExpression(_ expression: String) -> (value: Double, lastNumber: String, previousValue: Double?, operation: String?, waitingForOperand: Bool) {
        let operators = ["+", "−", "×", "÷"]
        var numbers: [String] = []
        var ops: [String] = []
        var currentNumber = ""
        
        // Parse the expression character by character
        for char in expression {
            let charStr = String(char)
            if operators.contains(charStr) {
                if !currentNumber.isEmpty {
                    numbers.append(currentNumber)
                    currentNumber = ""
                }
                ops.append(charStr)
            } else {
                currentNumber += charStr
            }
        }
        
        // Add the last number if exists
        if !currentNumber.isEmpty {
            numbers.append(currentNumber)
        }
        
        // If expression ends with operator, ignore it for calculation
        let hasTrailingOperator = !expression.isEmpty && operators.contains(String(expression.last!))
        let effectiveOps = hasTrailingOperator ? Array(ops.dropLast()) : ops
        
        // Calculate the result using only complete operations
        var result: Double = 0
        var lastDisplayNumber = "0"
        var prevValue: Double? = nil
        var lastOp: String? = nil
        var waiting = false
        
        if numbers.isEmpty {
            result = 0
            lastDisplayNumber = "0"
        } else if numbers.count == 1 {
            // Only one number
            result = Double(numbers[0]) ?? 0
            lastDisplayNumber = numbers[0]
            if hasTrailingOperator && !ops.isEmpty {
                prevValue = result
                lastOp = getOperationFromSymbol(ops.last!)
                waiting = true
            }
        } else {
            // Multiple numbers with operations
            result = Double(numbers[0]) ?? 0
            lastDisplayNumber = numbers[0]
            
            // Process complete operations only
            for i in 0..<min(effectiveOps.count, numbers.count - 1) {
                let op = getOperationFromSymbol(effectiveOps[i])
                let nextNum = Double(numbers[i + 1]) ?? 0
                result = calculate(firstValue: result, secondValue: nextNum, operation: op)
                lastDisplayNumber = numbers[i + 1]
            }
            
            // Set up state for next operation if there's a trailing operator
            if hasTrailingOperator && !ops.isEmpty {
                prevValue = result
                lastOp = getOperationFromSymbol(ops.last!)
                waiting = true
            } else if effectiveOps.count > 0 && numbers.count > effectiveOps.count {
                // There's an incomplete operation
                let lastOpIndex = effectiveOps.count - 1
                if lastOpIndex >= 0 {
                    prevValue = Double(numbers[0]) ?? 0
                    for i in 0..<lastOpIndex {
                        let op = getOperationFromSymbol(effectiveOps[i])
                        let nextNum = Double(numbers[i + 1]) ?? 0
                        prevValue = calculate(firstValue: prevValue!, secondValue: nextNum, operation: op)
                    }
                    lastOp = getOperationFromSymbol(effectiveOps[lastOpIndex])
                    lastDisplayNumber = numbers.last ?? "0"
                    waiting = false
                }
            }
        }
        
        return (result, lastDisplayNumber, prevValue, lastOp, waiting)
    }
    
    // MARK: - Helper function to get operation from symbol
    private func getOperationFromSymbol(_ symbol: String) -> String {
        switch symbol {
        case "+": return "add"
        case "−": return "subtract"
        case "×": return "multiply"
        case "÷": return "divide"
        default: return ""
        }
    }
    
    // MARK: - History Management
    private func addToHistory(expression: String, result: String) {
        let newEntry = CalculationHistory(
            expression: expression,
            result: result,
            timestamp: Date()
        )
        
        history.insert(newEntry, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        // Initialize opacity for new entry
        historyOpacities[newEntry.id] = 1.0
        
        saveHistory()
    }
    
    func handleHistoryClick(_ calc: CalculationHistory) {
        currentResult = calc.result
        display = calc.result
        fullEquationChain = calc.expression
        previousValue = nil
        operation = nil
        waitingForOperand = false
    }
    
    // MARK: - History Opacity Management
    func updateHistoryItemOpacity(id: UUID, opacity: Double) {
        historyOpacities[id] = opacity
    }
    
    func getHistoryItemOpacity(id: UUID) -> Double {
        return historyOpacities[id] ?? 1.0
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "calculator_history")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "calculator_history"),
           let decodedHistory = try? JSONDecoder().decode([CalculationHistory].self, from: data) {
            history = decodedHistory
        }
    }
    
    // MARK: - Button Press Animation
    func handleButtonPress(_ buttonId: String, action: @escaping () -> Void) {
        pressedButton = buttonId
        action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.pressedButton = nil
        }
    }
}

// MARK: - Main Calculator View
struct ContentView: View {
    @StateObject private var calculator = CalculatorViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Display Area
                    VStack(spacing: 8) {
                        // History - Scrollable with all 100 entries
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .trailing, spacing: 4) {
                                ForEach(Array(calculator.history.enumerated()), id: \.element.id) { index, calc in
                                    Button(action: {
                                        calculator.handleHistoryClick(calc)
                                    }) {
                                        HStack {
                                            Spacer()
                                            Text("\(calc.expression) = \(calc.result)")
                                                .font(.system(size: 16, weight: .light))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                                .truncationMode(.head)
                                        }
                                        .padding(.horizontal, 4)
                                        .background(
                                            GeometryReader { itemGeometry in
                                                Color.clear
                                                    .preference(key: ViewOffsetKey.self, value: itemGeometry.frame(in: .named("historyScroll")).midY)
                                            }
                                        )
                                        .onPreferenceChange(ViewOffsetKey.self) { offset in
                                            // Calculate opacity based on distance from center of scroll area
                                            let scrollAreaCenter: CGFloat = 40 // Half of 80px height
                                            let distance = abs(offset - scrollAreaCenter)
                                            let maxDistance: CGFloat = 40
                                            let normalizedDistance = min(distance / maxDistance, 1.0)
                                            
                                            // Update opacity for this specific item
                                            if var historyItem = calculator.history.first(where: { $0.id == calc.id }) {
                                                let opacity = max(0.25, 1.0 - (normalizedDistance * 0.75))
                                                // Store opacity in a way that can trigger UI updates
                                                DispatchQueue.main.async {
                                                    // Force update by modifying a published property
                                                    calculator.updateHistoryItemOpacity(id: calc.id, opacity: opacity)
                                                }
                                            }
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .opacity(calculator.getHistoryItemOpacity(id: calc.id))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .coordinateSpace(name: "historyScroll")
                        .clipped()
                        
                        // Main Result
                        Text(calculator.currentResult)
                            .font(.system(size: min(60, geometry.size.width / 6), weight: .thin))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .frame(height: 80)
                        
                        // Equation Chain
                        Text(calculator.fullEquationChain)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Button Grid
                    VStack(spacing: 12) {
                        // Row 1
                        HStack(spacing: 12) {
                            CalculatorButton(
                                title: "AC",
                                backgroundColor: .gray,
                                foregroundColor: .black,
                                isPressed: calculator.pressedButton == "clear"
                            ) {
                                calculator.handleButtonPress("clear") {
                                    calculator.clear()
                                }
                            }
                            
                            CalculatorButton(
                                title: "⌫",
                                backgroundColor: .gray,
                                foregroundColor: .black,
                                isPressed: calculator.pressedButton == "backspace"
                            ) {
                                calculator.handleButtonPress("backspace") {
                                    calculator.backspace()
                                }
                            }
                            
                            CalculatorButton(
                                title: "%",
                                backgroundColor: .gray,
                                foregroundColor: .black,
                                isPressed: calculator.pressedButton == "percent"
                            ) {
                                calculator.handleButtonPress("percent") {
                                    calculator.percentage()
                                }
                            }
                            
                            CalculatorButton(
                                title: "÷",
                                backgroundColor: .orange,
                                foregroundColor: .white,
                                isPressed: calculator.pressedButton == "divide"
                            ) {
                                calculator.handleButtonPress("divide") {
                                    calculator.performOperation("divide")
                                }
                            }
                        }
                        
                        // Row 2
                        HStack(spacing: 12) {
                            CalculatorButton(title: "7", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "7") {
                                calculator.handleButtonPress("7") { calculator.inputNumber("7") }
                            }
                            CalculatorButton(title: "8", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "8") {
                                calculator.handleButtonPress("8") { calculator.inputNumber("8") }
                            }
                            CalculatorButton(title: "9", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "9") {
                                calculator.handleButtonPress("9") { calculator.inputNumber("9") }
                            }
                            CalculatorButton(title: "×", backgroundColor: .orange, foregroundColor: .white, isPressed: calculator.pressedButton == "multiply") {
                                calculator.handleButtonPress("multiply") { calculator.performOperation("multiply") }
                            }
                        }
                        
                        // Row 3
                        HStack(spacing: 12) {
                            CalculatorButton(title: "4", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "4") {
                                calculator.handleButtonPress("4") { calculator.inputNumber("4") }
                            }
                            CalculatorButton(title: "5", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "5") {
                                calculator.handleButtonPress("5") { calculator.inputNumber("5") }
                            }
                            CalculatorButton(title: "6", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "6") {
                                calculator.handleButtonPress("6") { calculator.inputNumber("6") }
                            }
                            CalculatorButton(title: "−", backgroundColor: .orange, foregroundColor: .white, isPressed: calculator.pressedButton == "subtract") {
                                calculator.handleButtonPress("subtract") { calculator.performOperation("subtract") }
                            }
                        }
                        
                        // Row 4
                        HStack(spacing: 12) {
                            CalculatorButton(title: "1", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "1") {
                                calculator.handleButtonPress("1") { calculator.inputNumber("1") }
                            }
                            CalculatorButton(title: "2", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "2") {
                                calculator.handleButtonPress("2") { calculator.inputNumber("2") }
                            }
                            CalculatorButton(title: "3", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "3") {
                                calculator.handleButtonPress("3") { calculator.inputNumber("3") }
                            }
                            CalculatorButton(title: "+", backgroundColor: .orange, foregroundColor: .white, isPressed: calculator.pressedButton == "add") {
                                calculator.handleButtonPress("add") { calculator.performOperation("add") }
                            }
                        }
                        
                        // Row 5
                        HStack(spacing: 12) {
                            CalculatorButton(
                                title: "0",
                                backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2),
                                isPressed: calculator.pressedButton == "0",
                                isWide: true
                            ) {
                                calculator.handleButtonPress("0") { calculator.inputNumber("0") }
                            }
                            
                            CalculatorButton(title: ".", backgroundColor: .init(red: 0.2, green: 0.2, blue: 0.2), isPressed: calculator.pressedButton == "decimal") {
                                calculator.handleButtonPress("decimal") { calculator.inputDecimal() }
                            }
                            
                            CalculatorButton(title: "=", backgroundColor: .orange, foregroundColor: .white, isPressed: calculator.pressedButton == "equals") {
                                calculator.handleButtonPress("equals") { calculator.performOperation("equals") }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Calculator Button Component
struct CalculatorButton: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let isPressed: Bool
    let isWide: Bool
    let action: () -> Void
    
    init(
        title: String,
        backgroundColor: Color = Color(red: 0.2, green: 0.2, blue: 0.2),
        foregroundColor: Color = .white,
        isPressed: Bool = false,
        isWide: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.isPressed = isPressed
        self.isWide = isWide
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .fill(backgroundColor)
                        .opacity(isPressed ? 0.7 : 1.0)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .frame(width: isWide ? nil : nil)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
