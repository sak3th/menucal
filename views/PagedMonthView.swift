//
// PagedMonthView.swift
// MenuCal
//
// Created by Saketh Vejendla on 14/12/25.
//

import SwiftUI

struct PagedMonthView: View {
  @Environment(AppViewModel.self) private var appVM

  @State private var months: [Date]
  @State private var isProgrammaticScroll = false

  private let calendar = Calendar.current
  private let loadBatchSize = 3
  private let currentMonth: Date

  private var containerHeight: CGFloat {
    ViewConstants.monthGridHeight(weekCount: Month.weekCount(for: appVM.selectedMonth))
  }

  init() {
    let calendar = Calendar.current
    let now = Date()
    let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    self.currentMonth = startOfCurrentMonth

    var initial: [Date] = []
    for offset in -loadBatchSize...loadBatchSize {
      if let d = calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
        initial.append(start)
      }
    }
    _months = State(initialValue: initial)
  }

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      MonthHeader()
      Spacer().frame(height: 16)
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          LazyHStack(alignment: .top, spacing: 0) {
            ForEach(months, id: \.self) { date in
              Month(startOfMonth: date)
                .id(date)
                .onAppear {
                  if date == self.months.last {
                    appendNextMonths(current: date)
                  } else if date == self.months.first {
                    prependPrevMonths(current: date)
                  }
                }
                .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                  if isVisible && !isProgrammaticScroll {
                    appVM.onMonthScrolled(date)
                  }
                }
                .frame(width: ViewConstants.monthViewWidth)
            }
          }
          .onAppear {
            proxy.scrollTo(appVM.selectedMonth, anchor: .center)
          }
        }
        .frame(height: containerHeight)
        .animation(.smooth(duration: 0.3), value: containerHeight)
        .scrollTargetLayout()
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.never)
        .defaultScrollAnchor(.center)
        .onChange(of: appVM.selectedMonth) { _, newMonth in
          if !months.contains(newMonth) {
            months = generateMonths(around: newMonth)
          }
          if appVM.changeSource != .monthScroll {
            isProgrammaticScroll = true
            withAnimation {
              proxy.scrollTo(newMonth, anchor: .center)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              isProgrammaticScroll = false
            }
          }
        }
      }
    }
    .padding(.vertical, 8)
  }

  private func prependPrevMonths(current: Date) {
    for offset in stride(from: -loadBatchSize, through: -1, by: 1) {
      if let date = calendar.date(byAdding: .month, value: offset, to: current),
         !months.contains(date) {
        months.insert(date, at: 0)
      }
    }
  }

  private func appendNextMonths(current: Date) {
    for offset in 1...loadBatchSize {
      if let date = calendar.date(byAdding: .month, value: offset, to: current),
         !months.contains(date) {
        months.append(date)
      }
    }
  }

  private func generateMonths(around date: Date) -> [Date] {
    var newMonths: [Date] = []
    for offset in -loadBatchSize...loadBatchSize {
      if let d = calendar.date(byAdding: .month, value: offset, to: date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
        newMonths.append(start)
      }
    }
    return newMonths
  }
}

struct MonthHeader: View {
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM

  private var monthFormatter: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "MMMM yyyy"
    return df
  }

  var body: some View {
    HStack {
      Text(appVM.selectedMonth, formatter: monthFormatter)
        .font(Font.title3)
        .fontWeight(.medium)
      if eventsVM.isRefreshing {
        ProgressView()
          .controlSize(.small)
          .padding(.leading, 4)
      }
      Spacer()
    }
  }
}

struct Month: View {
  let startOfMonth: Date
  init(startOfMonth: Date) {
    self.startOfMonth = startOfMonth
  }

  static func weekCount(for month: Date) -> Int {
    let calendar = Calendar.current
    let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    guard let range = calendar.range(of: .day, in: .month, for: start) else { return 5 }

    var uniqueWeeks: [(Int, Int)] = []
    for day in range {
      if let d = calendar.date(byAdding: .day, value: day - 1, to: start) {
        let w = calendar.component(.weekOfYear, from: d)
        let y = calendar.component(.yearForWeekOfYear, from: d)
        if uniqueWeeks.last?.0 != w || uniqueWeeks.last?.1 != y {
          uniqueWeeks.append((w, y))
        }
      }
    }
    return uniqueWeeks.count
  }

  private func getWeekNumbers() -> [(week: Int, year: Int)] {
    let calendar = Calendar.current
    guard let rangeOfDays = calendar.range(of: .day, in: .month, for: startOfMonth) else {
      return []
    }

    var weekYearPairs: [(week: Int, year: Int)] = []

    for day in rangeOfDays {
      if let currentDay = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {

        let week = calendar.component(.weekOfYear, from: currentDay)
        let year = calendar.component(.yearForWeekOfYear, from: currentDay)

        if weekYearPairs.last?.week != week {
          weekYearPairs.append((week: week, year: year))
        }
      }
    }

    return weekYearPairs
  }


  var body: some View {
    VStack(spacing: 0) {
      Grid(horizontalSpacing: 4, verticalSpacing: 4) {
        WeekdaysGridRow()
        ForEach(getWeekNumbers(), id: \.week) { w in
          WeekGridRow(w.week, w.year)
        }
      }
    }
  }
}

struct WeekGridRow: View {
  let weekNum: Int
  let year: Int

  init(_ weekNum: Int,_ year: Int) {
    self.weekNum = weekNum
    self.year = year
  }

  private func generateDaysOfWeek() -> [Date] {
    let calendar = Calendar.current

    var dateComponents = DateComponents()
    dateComponents.yearForWeekOfYear = year // Use yearForWeekOfYear for week-based calendars
    dateComponents.weekOfYear = weekNum

    // Get the first day of that week (which will be Monday in ISO8601)
    guard let startOfWeek = calendar.date(from: dateComponents) else {
      return []
    }

    var weekDates: [Date] = []

    // Loop through 0 to 6 to get all 7 days of the week
    for dayIndex in 0..<7 {
      if let date = calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek) {
        weekDates.append(date)
      }
    }

    return weekDates
  }

  var body: some View {
    GridRow() {
      Text(weekNum.formatted())
        .font(.caption)
        .fontWeight(.light).opacity(0.7)
        .frame(width: ViewConstants.weekNumCellWidth)


      ForEach(generateDaysOfWeek(), id: \.self) { date in
        DayCell(date)
          .frame(width: ViewConstants.dayCellWidth, height: ViewConstants.dayCellHeight)
      }
    }
  }
}


struct WeekdaysGridRow: View {
  private var weekdaySymbols: [String] {
    let cal = Calendar.current
    let symbols = cal.veryShortStandaloneWeekdaySymbols
    let firstWeekday = cal.firstWeekday
    return Array(symbols[firstWeekday - 1..<symbols.count] + symbols[0..<firstWeekday - 1])
  }

  var body: some View {
    GridRow {
      Group {
        Spacer()
          .frame(height: 1.0)
        ForEach(weekdaySymbols, id: \.self) { symbol in
          Text(symbol)
            .font(.system(size: 9, weight: .ultraLight))
            .frame(width: ViewConstants.dayCellWidth, height: ViewConstants.weekdayRowHeight)
        }
      }
    }
  }
}

struct DayCell: View {
  @Environment(AppViewModel.self) private var appVM: AppViewModel

  let date: Date

  init(_ date: Date) {
    self.date = date
  }

  private var isSelected: Bool {
    Calendar.current.isDate(date, inSameDayAs: appVM.selectedDate)
  }

  private var isToday: Bool {
    Calendar.current.isDate(date, inSameDayAs: appVM.lastKnownToday)
  }

  private var isInCurrentMonth: Bool {
    Calendar.current.isDate(date, equalTo: appVM.selectedDate, toGranularity: .month)
  }

  private var dayFormatter: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "d"
    return df
  }

  var body: some View {
    VStack(spacing: 0) {
      Button(action: { appVM.selectDate(date) }) {
        ZStack {
          if isSelected {
            Circle().fill(isToday ? Color.red : Color("SelectedDayBg")).padding(4)
          } else {
            Circle().fill(Color.clear).padding(4)
          }

          if isInCurrentMonth {
            if isSelected && isToday {
              Text(date, formatter: dayFormatter)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(Color("SelectedDayFg"))
            } else if isSelected && !isToday {
              Text(date, formatter: dayFormatter)
                .font(.body.weight(.medium))
                .foregroundStyle(Color("SelectedDayFg"))
            } else if !isSelected && isToday {
              Text(date, formatter: dayFormatter)
                .font(.body.weight(.medium))
                .foregroundStyle(.red)
            } else {
              Text(date, formatter: dayFormatter)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            }
          } else {
            Text(date, formatter: dayFormatter)
              .font(.body.weight(.medium))
              .foregroundStyle(.primary.opacity(0.2))
          }

        }
      }
      .buttonStyle(.plain)

      DayEventsCapsule(date: date).opacity(0.5)
    }
  }
}


#Preview {
  CalView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth)
}

