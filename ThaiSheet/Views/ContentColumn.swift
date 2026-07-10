//
//  ContentColumn.swift
//  ThaiSheet
//

import SwiftUI

extension View {
    /// Caps content width and centers it, so iPhone-proportioned rows don't
    /// stretch across the full iPad width. No-op on compact widths (an iPhone
    /// never reaches the cap), so iPhone layouts are unaffected.
    func contentColumn(maxWidth: CGFloat = 700) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
