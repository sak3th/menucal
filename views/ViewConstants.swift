//
//  ViewConstants.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 16/12/25.
//

import Foundation

struct ViewConstants {
  static let height: CGFloat = 280.0
  static let width: CGFloat = 280.0
  static let padding: CGFloat = 8.0
  //static let appWidth = width + (padding * 0) + 64.0
  static let appHeight = (height * 3) + (padding * 2)

  static let weekNumCellWidth = 22.0
  static let dayCellWidth = 32.0
  static let dayCellHeight = 36.0
  static let dayEventCapsuleMaxWidth = 16.0
  static let monthCellPadding = 4.0

  static var monthViewWidth: CGFloat {
    return weekNumCellWidth + monthCellPadding + (dayCellWidth * 7) + (monthCellPadding * 7)
  }

  static var appWidth: CGFloat {
    padding * 2 + monthViewWidth
  }

}

