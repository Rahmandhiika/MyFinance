import SwiftUI

struct MonthNavigator: View {
    @Binding var selectedMonth: Date
    var showDayMode: Bool = false
    @Binding var selectedDay: Date

    /// Batas minimum bulan yang bisa dinagivasi ke belakang (default 3 tahun lalu)
    var minMonth: Date = Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
    /// Batas maksimum — default bulan ini (tidak bisa navigasi ke depan)
    var maxMonth: Date = Date()

    @Environment(\.appTheme) private var theme

    // Static formatter — tidak re-alloc setiap render
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEE, dd MMM"
        return f
    }()

    private var cal: Calendar { Calendar.current }

    private var atMin: Bool {
        cal.compare(selectedMonth, to: minMonth, toGranularity: .month) != .orderedDescending
    }
    private var atMax: Bool {
        cal.compare(selectedMonth, to: maxMonth, toGranularity: .month) != .orderedAscending
    }

    var body: some View {
        HStack {
            Button { navigateBack() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(atMin ? theme.textSecondary.opacity(0.3) : theme.textPrimary)
            }
            .disabled(atMin)
            .accessibilityLabel(showDayMode ? "Hari sebelumnya" : "Bulan sebelumnya")

            Spacer()

            Text(showDayMode ? Self.dayFormatter.string(from: selectedDay) : selectedMonth.indonesianMonthYear)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button { navigateForward() } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(atMax ? theme.textSecondary.opacity(0.3) : theme.textPrimary)
            }
            .disabled(atMax)
            .accessibilityLabel(showDayMode ? "Hari berikutnya" : "Bulan berikutnya")
        }
        .padding(.horizontal)
    }

    private func navigateBack() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if showDayMode {
            selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        } else {
            selectedMonth = selectedMonth.addingMonths(-1)
        }
    }

    private func navigateForward() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if showDayMode {
            selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        } else {
            selectedMonth = selectedMonth.addingMonths(1)
        }
    }
}

// Convenience init — month-only mode (no day binding needed)
extension MonthNavigator {
    init(selectedMonth: Binding<Date>) {
        self._selectedMonth = selectedMonth
        self.showDayMode = false
        self._selectedDay = .constant(Date())
    }
}
