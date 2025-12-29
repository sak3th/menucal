//
//  Extensions.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 24/12/25.
//

import Foundation
import SwiftUI
import AppKit

extension Color {
    /// Returns a high-contrast foreground color (either black or white) based on the luminance of this color.
    var contrastingForegroundColor: Color {
        let nsColor = NSColor(self)
        
        // Convert to sRGB to ensure we can extract components
        guard let components = nsColor.usingColorSpace(.sRGB) else {
            return .white // Fallback
        }
        
        let r = components.redComponent
        let g = components.greenComponent
        let b = components.blueComponent
        
        // Calculate luminance
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        
        return luminance > 0.5 ? .black : .white
    }
}

extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        // The forced unwrap (!) is safe here because dateComponents(_:from:)
        // guarantees a valid date when only year/month are requested.
        return calendar.date(from: components)!
    }
}
