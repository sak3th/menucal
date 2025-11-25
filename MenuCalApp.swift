//
//  MenuCalApp.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 24/11/25.
//

import SwiftUI

@main
struct MenuCalApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            // Use SF Symbols for a native look. The icon will represent the current date.
            // This is a placeholder, we will make it dynamic later.
            Image(systemName: "calendar")
                .resizable()
                .scaledToFill()
        }
        .menuBarExtraStyle(.window) // Use .window style for a popover interface
    }
}


#Preview {
    ContentView()
}

