//
//  FilterChipView.swift
//  ThaiSheet
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

/// Horizontal row of filter chips with a leading "All" chip clearing the selection
struct FilterChipRow<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    var color: (Item) -> Color? = { _ in nil }
    @Binding var selection: Item?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipView(
                    label: String(localized: "All", bundle: .appLanguage),
                    isSelected: selection == nil,
                    action: { selection = nil }
                )
                ForEach(items, id: \.self) { item in
                    FilterChipView(
                        label: label(item),
                        isSelected: selection == item,
                        color: color(item),
                        action: { selection = item }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
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
