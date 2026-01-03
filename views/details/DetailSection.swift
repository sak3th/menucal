//
//  DetailSection.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 29/12/25.
//

import SwiftUI

struct DetailSection<Content: View>: View {
  let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    Section {
      content()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .background(Color.primary.quinary, in: RoundedRectangle(cornerRadius: 16.0))
  }
}

#Preview {
  DetailSection {
    Text("Sample content inside DetailSection")
  }
  .padding()
}
