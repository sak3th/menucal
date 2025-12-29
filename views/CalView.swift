//
//  AppView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 16/12/25.
//

import SwiftUI

struct CalView: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(.background)
      ZStack(alignment: .bottomLeading) {
        VStack(alignment: .center, spacing: 0) {
          HStack {
            Spacer()
            PagedMonthView()
              .frame(width: ViewConstants.monthViewWidth)
            Spacer()
          }
          
          EventsView()
            .frame(minHeight: ViewConstants.appHeight * 0.3)
            .padding(.horizontal, ViewConstants.padding)
            .scrollEdgeEffectStyle(.hard, for: .bottom)
        }
        .padding(.top, ViewConstants.padding)
        .frame(width: ViewConstants.appWidth)
        
        BottomToolbar()
          .offset(y: -8)
      }
      TopBar()
        .offset(x: -4, y: 8)
    }
    .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
    .frame(maxHeight: ViewConstants.appHeight)
    .background(.regularMaterial)
    .focusable(false)
  }
  
}

struct TopBar: View {
  @State private var showingEventsViewMenu: Bool = true
  var body: some View {
    HStack {
      Spacer()
      TopToolbar()
    }
  }
}


#Preview {
  CalView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

