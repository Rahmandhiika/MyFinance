import SwiftUI

// MARK: - CalcKeypad Sheet

/// Full-screen calculator numpad.
/// Usage: .sheet(isPresented: $show) { CalcKeypad(value: $nominal) }
struct CalcKeypad: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Binding var value: Decimal

    // MARK: - Calculator State

    @State private var currentInput: String = "0"
    @State private var accumulator:  Decimal = 0
    @State private var pendingOp:    String? = nil
    @State private var expressionStr: String = ""
    @State private var justPressedOp: Bool = false

    // MARK: - Init: seed current value

    private var confirmValue: Decimal {
        // If there's a pending operation, auto-evaluate first
        if let op = pendingOp {
            let rhs = Decimal(string: currentInput) ?? 0
            return calcResult(accumulator, rhs, op: op)
        }
        return Decimal(string: currentInput) ?? 0
    }

    // MARK: - Layout

    private let btnSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(theme.separator)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Display
            displayArea
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider().background(theme.separator)

            // Keypad grid
            keypadGrid
                .padding(.horizontal, 14)
                .padding(.top, 10)

            // Confirm button
            confirmButton
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, max(16, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom ?? 16))
        }
        .background(theme.bgApp)
        .onAppear {
            // Seed with current value (termasuk 0 — biar user lihat angka yang sedang di-edit)
            currentInput = value > 0 ? formatRaw(value) : "0"
        }
    }

    // MARK: - Display

    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Expression line (e.g. "50.000 +")
            if !expressionStr.isEmpty {
                Text(expressionStr)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }

            // Main number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Rp")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Text(formattedDisplay)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: expressionStr)
    }

    private var formattedDisplay: String {
        guard let d = Decimal(string: currentInput) else { return currentInput }
        if currentInput.hasSuffix(".") { return d.decimalDisplayFormatted + "," }
        return d.decimalDisplayFormatted
    }

    // MARK: - Keypad Grid

    private var keypadGrid: some View {
        let rows: [[CalcKey]] = [
            [.op("÷"), .op("×"), .clear, .backspace],
            [.digit("1"), .digit("2"), .digit("3"), .op("+")],
            [.digit("4"), .digit("5"), .digit("6"), .op("−")],
            [.digit("7"), .digit("8"), .digit("9"), .percent],
            [.triple0, .digit("0"), .decimal, .equals]
        ]

        return VStack(spacing: btnSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: btnSpacing) {
                    ForEach(row) { key in
                        calcButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calcButton(_ key: CalcKey) -> some View {
        switch key {
        case .digit(let d):
            numButton(label: d, bg: numBg, fg: theme.textPrimary) { pressDigit(d) }
        case .triple0:
            numButton(label: "000", bg: numBg, fg: theme.textPrimary) { press000() }
        case .decimal:
            numButton(label: ",", bg: numBg, fg: theme.textPrimary) { pressDecimal() }
        case .op(let o):
            numButton(label: o, bg: opBg, fg: opFg, fontSize: 22) { pressOp(o) }
                .overlay(
                    pendingOp == o
                    ? RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.accent, lineWidth: 2)
                    : nil
                )
        case .equals:
            numButton(label: "=", bg: theme.accent, fg: theme.textOnColor, fontSize: 24) { pressEquals() }
        case .clear:
            numButton(label: "C", bg: clearBg, fg: clearFg) { pressClear() }
        case .backspace:
            numButton(icon: "delete.backward.fill", bg: numBg, fg: theme.textSecondary) { pressBackspace() }
        case .percent:
            numButton(label: "%", bg: clearBg, fg: clearFg) { pressPercent() }
        }
    }

    // MARK: - Button factory

    private func numButton(
        label: String = "",
        icon: String = "",
        bg: Color,
        fg: Color,
        fontSize: CGFloat = 20,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { action() }
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        }) {
            Group {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                } else {
                    Text(label)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            value = confirmValue
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Konfirmasi  \(confirmValue.idrFormatted)")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(theme.textOnColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [theme.accent, theme.accentDark],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors

    private var numBg: Color {
        theme.colorScheme == .dark
            ? Color(hex: "#1C2A1C")
            : Color(hex: "#F3F4F6")
    }
    private var opBg: Color {
        theme.colorScheme == .dark
            ? theme.accent.opacity(0.18)
            : theme.accent.opacity(0.12)
    }
    private var opFg: Color { theme.accent }
    private var clearBg: Color {
        theme.colorScheme == .dark
            ? Color(hex: "#FF6B6B").opacity(0.18)
            : Color(hex: "#FF6B6B").opacity(0.12)
    }
    private var clearFg: Color { Color(hex: "#FF6B6B") }

    // MARK: - Calculator Logic

    private func pressDigit(_ d: String) {
        if justPressedOp {
            currentInput = d == "0" ? "0" : d
            justPressedOp = false
        } else {
            currentInput = currentInput == "0" ? d : currentInput + d
        }
    }

    private func press000() {
        if justPressedOp {
            currentInput = "0"
            justPressedOp = false
        } else if currentInput != "0" {
            currentInput += "000"
        }
    }

    private func pressDecimal() {
        if justPressedOp {
            currentInput = "0."
            justPressedOp = false
        } else if !currentInput.contains(".") {
            currentInput += "."
        }
    }

    private func pressOp(_ op: String) {
        let current = Decimal(string: currentInput) ?? 0
        if let prev = pendingOp, !justPressedOp {
            accumulator = calcResult(accumulator, current, op: prev)
            expressionStr = accumulator.decimalDisplayFormatted + " \(op)"
        } else {
            accumulator = current
            expressionStr = current.decimalDisplayFormatted + " \(op)"
        }
        pendingOp = op
        justPressedOp = true
    }

    private func pressEquals() {
        guard let op = pendingOp else { return }
        let rhs = Decimal(string: currentInput) ?? 0
        let result = calcResult(accumulator, rhs, op: op)
        currentInput = formatRaw(result)
        expressionStr = ""
        accumulator = 0
        pendingOp = nil
        justPressedOp = false
    }

    private func pressPercent() {
        let current = Decimal(string: currentInput) ?? 0
        if pendingOp != nil {
            // Kontekstual: 1.000.000 × 50% → 50% dari accumulator
            let pct = current / 100 * accumulator
            currentInput = formatRaw(pct)
        } else {
            // Standalone: bagi 100
            currentInput = formatRaw(current / 100)
        }
        justPressedOp = false
    }

    private func pressClear() {
        currentInput = "0"
        accumulator = 0
        pendingOp = nil
        expressionStr = ""
        justPressedOp = false
    }

    private func pressBackspace() {
        if justPressedOp {
            pendingOp = nil
            expressionStr = ""
            justPressedOp = false
            return
        }
        if currentInput.count > 1 {
            currentInput.removeLast()
            if currentInput == "-" { currentInput = "0" }
        } else {
            currentInput = "0"
        }
    }

    private func calcResult(_ a: Decimal, _ b: Decimal, op: String) -> Decimal {
        switch op {
        case "+":     return a + b
        case "−":     return a - b
        case "×":     return a * b
        case "÷":     return b != 0 ? a / b : a
        default:      return b
        }
    }

    // MARK: - Formatter

    private func formatRaw(_ val: Decimal) -> String {
        // Store without separators
        let d = Double(truncating: val as NSDecimalNumber)
        if d == d.rounded(.towardZero) && !"\(val)".contains(".") {
            return String(format: "%.0f", d)
        }
        return "\(val)"
    }
}

// MARK: - CalcKey Enum

enum CalcKey: Identifiable {
    case digit(String)
    case triple0
    case decimal
    case op(String)
    case equals
    case clear
    case backspace
    case percent

    var id: String {
        switch self {
        case .digit(let d): return "d\(d)"
        case .triple0:      return "000"
        case .decimal:      return "dec"
        case .op(let o):    return "op\(o)"
        case .equals:       return "eq"
        case .clear:        return "clr"
        case .backspace:    return "bk"
        case .percent:      return "pct"
        }
    }
}

// MARK: - CalcInputField
// Drop-in replacement for CurrencyInputField — tap to open CalcKeypad

struct CalcInputField: View {
    @Environment(\.appTheme) private var theme
    @Binding var value: Decimal
    var placeholder: String = "Ketuk untuk input"
    var showRpPrefix: Bool = true

    @State private var showCalc = false

    var body: some View {
        Button { showCalc = true } label: {
            HStack(spacing: 8) {
                if showRpPrefix {
                    Text("Rp")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                Text(value > 0 ? value.decimalDisplayFormatted : placeholder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value > 0 ? theme.textPrimary : theme.textSecondary.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "plusminus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .padding(6)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(12)
            .background(theme.separator.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCalc) {
            CalcKeypad(value: $value)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
        }
    }

}
