//
//  ContentView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 24/11/25.
//

import SwiftUI

struct ContentView: View {
  // Create and manage the lifecycle of our view model.
  @StateObject private var viewModel = CalendarViewModel()

  var body: some View {
    VStack(spacing: 0) {
      if !(viewModel.hasCalendarPermission && viewModel.hasReminderPermission) {
        PermissionsView(viewModel: viewModel)
      } else if let errorMessage = viewModel.errorMessage {
        VStack {
          Text("An Error Occurred")
            .font(.headline)
            .padding()
          Text(errorMessage)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // The interactive month grid.
        MonthView(viewModel: viewModel)

        Divider()

        // The detailed view for the selected day.
        DayView(viewModel: viewModel)
      }
    }
    .onAppear {
      viewModel.checkPermissions()
      if viewModel.hasCalendarPermission && viewModel.hasReminderPermission {
        Task {
          await viewModel.fetchData()
          // Force re-assignment so DayView can react (scroll logic inside DayView will run on appear)
          viewModel.selectedDate = Date()
        }
      }
    }
    .frame(width: 300, height: 900)
    //.glassEffect()
    //.glassEffectTransition(.matchedGeometry)
    //.background(.thinMaterial)
  }
}
