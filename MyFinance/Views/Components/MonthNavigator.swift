import SwiftUI

struct MonthNavigator: View {
    @Binding var selectedMonth: Date
    var showDayMode: Bool = false
    @Binding var selectedDay: Date

    var body: some View {
        HStack {
            Button { navigateBack() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(showDayMode ? dayString : monthString)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button { navigateForward() } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal)
    }

    private var monthString: String { selectedMonth.indonesianMonthYear }
    private var dayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEE, dd MMM"
        return f.string(from: selectedDay)
    }

    private func navigateBack() {
        if showDayMode {
            selectedDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        } else {
            selectedMonth = selectedMonth.addingMonths(-1)
        }
    }

    private func navigateForward() {
        if showDayMode {
            selectedDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
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
