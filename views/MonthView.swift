import SwiftUI

struct MonthView: View {
  @ObservedObject var viewModel: CalendarViewModel
  @State private var displayedMonth: Date = Date()

  // Define the grid layout: 7 columns of flexible width.
  private let columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: 7)

  // Get weekday symbols from the user's current calendar.
  private var weekdaySymbols: [String] {
    // We must slice to re-order based on the user's `firstWeekday` preference.
    let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
    let firstWeekday = Calendar.current.firstWeekday
    return Array(symbols[firstWeekday - 1..<symbols.count] + symbols[0..<firstWeekday - 1])
  }

  var body: some View {
    VStack(spacing: 4) {
      HeaderView
      WeekdayHeaderView
      CalendarGridView
    }
    .padding(.horizontal)
    .padding(.bottom, 8)
    .onChange(of: viewModel.selectedDate) { _, newDate in
      withAnimation {
        self.displayedMonth = newDate
      }
    }
  }

  // MARK: - Subviews

  private var HeaderView: some View {
    HStack {
      Text(displayedMonth, formatter: Self.monthYearFormatter)
        .font(.system(size: 14, weight: .semibold))
      Spacer()
      Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left").bold() }
        .buttonStyle(.borderless)
      Button("Today") { viewModel.changeSelectedDate(to: Date()) }.buttonStyle(.borderless)
      Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right").bold() }
        .buttonStyle(.borderless)
    }.padding(.vertical)
  }

  private var WeekdayHeaderView: some View {
    LazyVGrid(columns: columns) {
      ForEach(weekdaySymbols, id: \.self) { symbol in
        Text(symbol)
          .font(.system(size: 12, weight: .medium))
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var CalendarGridView: some View {
    let daysInMonth = generateDays(for: displayedMonth)

    return LazyVGrid(columns: columns, spacing: 4) {
      ForEach(daysInMonth, id: \.self) { date in
        DayCell(date: date, displayedMonth: displayedMonth)
      }
    }
  }

  // MARK: - Cell View
  private func DayCell(date: Date, displayedMonth: Date) -> some View {
    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
    let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
    let isDateInDisplayedMonth =
      Calendar.current.component(.year, from: date)
      == Calendar.current.component(.year, from: displayedMonth)
      && Calendar.current.component(.month, from: date)
        == Calendar.current.component(.month, from: displayedMonth)

    return Text(date, formatter: Self.dayFormatter)
      .font(.system(size: 13))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .foregroundColor(isDateInDisplayedMonth ? .primary : .secondary.opacity(0.6))
      .background(
        ZStack {
          if isSelected {
            Circle().fill(Color.accentColor)
          }
          if isToday && !isSelected {
            Circle().fill(Color.secondary.opacity(0.25))
          }
        }
      )
      .foregroundColor(isSelected ? .white : isDateInDisplayedMonth ? .primary : .secondary)
      .onTapGesture {
        withAnimation(.easeInOut(duration: 0.4)) {
          viewModel.changeSelectedDate(to: date)
        }
      }
      .clipShape(Circle())
  }

  // MARK: - Helpers
  private func changeMonth(by value: Int) {
    withAnimation {
      if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
        self.displayedMonth = newMonth
      }
    }
  }

  private func generateDays(for date: Date) -> [Date] {
    guard let monthInterval = Calendar.current.dateInterval(of: .month, for: date) else {
      return []
    }
    let firstDayOfMonth = monthInterval.start

    var days: [Date] = []
    let calendar = Calendar.current
    let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
    let dayOffset = (firstWeekday - calendar.firstWeekday + 7) % 7

    guard let firstDayOfGrid = calendar.date(byAdding: .day, value: -dayOffset, to: firstDayOfMonth)
    else { return [] }

    for i in 0..<42 {  // 6 weeks * 7 days
      if let day = calendar.date(byAdding: .day, value: i, to: firstDayOfGrid) {
        days.append(day)
      }
    }
    return days
  }

  // MARK: - Formatters
  private static let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }()

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter
  }()
}
