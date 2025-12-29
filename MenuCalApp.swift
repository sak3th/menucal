//
//  MenuCalApp.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 24/11/25.
//

import SwiftUI

@main
struct MenuCalApp: App {
  @State private var permViewModel = PermissionsViewModel()
  @State private var appViewModel = AppViewModel()
  @State private var eventsViewModel = EventsViewModel()

  var body: some Scene {
      MenuBarExtra {
        AppView()
          .environment(permViewModel)
          .environment(appViewModel)
          .environment(eventsViewModel)
          .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
          .onAppear {
            appViewModel.onAppStart()
            Task {
              await eventsViewModel.refreshAll()
            }
            permViewModel.checkPermissions()
            if (permViewModel.hasPermissions()) {
            }
          }
      } label: {
        Image(systemName: "calendar")
          .font(.system(size: 24))
      }
      .menuBarExtraStyle(.window)
  }
}


#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: 700)
}

