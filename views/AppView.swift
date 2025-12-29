//
//  AppView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import SwiftUI

struct AppView: View {
  @Environment(PermissionsViewModel.self) private var permVM

  var body: some View {
    VStack(alignment: .center) {
      if !permVM.hasPermissions() {
        PermissionsView()
      } else {
        CalView()
      }
    }
  }
}

#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

