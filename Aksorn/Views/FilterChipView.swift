//
//  FilterChipView.swift
//  Aksorn
//

import SwiftUI

struct FilterChipView: View {
    let label: String
    let isSelected: Bool
    var color: Color? = nil
    let action: () -> Void

    private var chipColor: Color {
        color ?? Color.accentColor
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? chipColor.opacity(0.2) : Color(.tertiarySystemFill))
                .foregroundColor(isSelected ? (color != nil ? .primary : Color.accentColor) : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? chipColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        FilterChipView(label: "All", isSelected: true, action: {})
        FilterChipView(label: "Low", isSelected: false, color: .green, action: {})
        FilterChipView(label: "Mid", isSelected: false, color: .yellow, action: {})
        FilterChipView(label: "High", isSelected: false, color: .red, action: {})
    }
    .padding()
}
