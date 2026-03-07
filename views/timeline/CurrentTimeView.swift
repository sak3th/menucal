//
//  CurrentTimeView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 26/11/25.
//

import SwiftUI

struct CurrentTimeView: View {
  let time: String
  let onHeightCalculated: ((CGFloat) -> Void)?
  
  init(time: String,onHeightCalculated: ((CGFloat) -> Void)? = nil) {
    self.time = time
    self.onHeightCalculated = onHeightCalculated
  }
  
  @State var height: CGFloat = 0
  
  var body: some View {
    HStack(spacing: 0) {
      
      Text(time)
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
      //.glassEffect()
        .glassEffect(.regular.tint(.red).interactive())
      
      VStack() {
        Divider()
          .frame(height: 1)
          .glassEffect(.clear.tint(.red).interactive())
      }
    }
    .background() {
      GeometryReader { geometry in
        Color.clear.onAppear {
          height = geometry.size.height
          onHeightCalculated?(geometry.size.height)
        }
      }
    }
  }
}

#Preview {
  CurrentTimeView(time: "12:00")
    .padding()
}
