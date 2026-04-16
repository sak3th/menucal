//
//  PagedWeekView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 16/04/26.
//

import SwiftUI

struct PagedWeekView: View {
  @Environment(AppViewModel.self) private var appVM

  @State private var weeks: [WeekID]
  @State private var scrollPosition: WeekID?

  private let calendar = Calendar.current
  private let loadBatchSize = 7

  init() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    var initial: [WeekID] = []
    for offset in -7...7 {
      if let d = calendar.date(byAdding: .weekOfYear, value: offset, to: today) {
        let id = WeekID(from: d, calendar: calendar)
        if !initial.contains(id) {
          initial.append(id)
        }
      }
    }
    _weeks = State(initialValue: initial)
  }

  private func weekID(for date: Date) -> WeekID {
    WeekID(from: date, calendar: calendar)
  }

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      MonthHeader()
      Spacer().frame(height: 16)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 0) {
          ForEach(weeks) { week in
            WeekPage(week: week)
              .frame(width: ViewConstants.monthViewWidth)
              .id(week)
          }
        }
        .scrollTargetLayout()
      }
      .frame(height: ViewConstants.weekViewHeight)
      .scrollTargetBehavior(.paging)
      .scrollIndicators(.never)
      .scrollPosition(id: $scrollPosition)
      .onAppear {
        scrollPosition = weekID(for: appVM.selectedDate)
      }
      .onChange(of: scrollPosition) { _, newWeek in
        guard let newWeek else { return }

        // Load more weeks at edges
        if let index = weeks.firstIndex(of: newWeek) {
          if index < 3 {
            prependWeeks(before: newWeek)
          } else if index > weeks.count - 3 {
            appendWeeks(after: newWeek)
          }
        }

        // Sync selected date from scroll
        let currentWeek = weekID(for: appVM.selectedDate)
        if newWeek != currentWeek {
          if let startOfWeek = newWeek.startOfWeek(calendar: calendar) {
            appVM.onWeekScrolled(startOfWeek)
          }
        }
      }
      .onChange(of: appVM.selectedDate) { _, newDate in
        if appVM.changeSource != .weekScroll {
          let target = weekID(for: newDate)
          if !weeks.contains(target) {
            weeks = generateWeeks(around: newDate)
          }
          withAnimation {
            scrollPosition = target
          }
        }
      }
    }
    .padding(.vertical, 8)
  }

  private func prependWeeks(before current: WeekID) {
    guard let startDate = current.startOfWeek(calendar: calendar) else { return }
    for offset in stride(from: -loadBatchSize, through: -1, by: 1) {
      if let d = calendar.date(byAdding: .weekOfYear, value: offset, to: startDate) {
        let id = WeekID(from: d, calendar: calendar)
        if !weeks.contains(id) {
          weeks.insert(id, at: 0)
        }
      }
    }
  }

  private func appendWeeks(after current: WeekID) {
    guard let startDate = current.startOfWeek(calendar: calendar) else { return }
    for offset in 1...loadBatchSize {
      if let d = calendar.date(byAdding: .weekOfYear, value: offset, to: startDate) {
        let id = WeekID(from: d, calendar: calendar)
        if !weeks.contains(id) {
          weeks.append(id)
        }
      }
    }
  }

  private func generateWeeks(around date: Date) -> [WeekID] {
    var result: [WeekID] = []
    for offset in -7...7 {
      if let d = calendar.date(byAdding: .weekOfYear, value: offset, to: date) {
        let id = WeekID(from: d, calendar: calendar)
        if !result.contains(id) {
          result.append(id)
        }
      }
    }
    return result
  }
}

struct WeekPage: View {
  let week: WeekID

  var body: some View {
    VStack(spacing: 0) {
      Grid(horizontalSpacing: 4, verticalSpacing: 4) {
        WeekdaysGridRow()
        WeekGridRow(week.weekOfYear, week.yearForWeekOfYear)
      }
    }
  }
}

struct WeekID: Identifiable, Hashable {
  let weekOfYear: Int
  let yearForWeekOfYear: Int

  var id: String { "\(yearForWeekOfYear)-W\(weekOfYear)" }

  init(from date: Date, calendar: Calendar) {
    self.weekOfYear = calendar.component(.weekOfYear, from: date)
    self.yearForWeekOfYear = calendar.component(.yearForWeekOfYear, from: date)
  }

  init(weekOfYear: Int, yearForWeekOfYear: Int) {
    self.weekOfYear = weekOfYear
    self.yearForWeekOfYear = yearForWeekOfYear
  }

  func startOfWeek(calendar: Calendar) -> Date? {
    var components = DateComponents()
    components.yearForWeekOfYear = yearForWeekOfYear
    components.weekOfYear = weekOfYear
    return calendar.date(from: components)
  }
}

#Preview {
  CalView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth)
}
