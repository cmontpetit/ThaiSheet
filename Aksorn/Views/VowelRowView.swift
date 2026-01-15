//
//  VowelRowView.swift
//  Aksorn
//

import SwiftUI

struct VowelHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            // SHORT section
            VStack(spacing: 2) {
                Text("SHORT")
                    .font(.caption)
                    .fontWeight(.semibold)
                HStack(spacing: 0) {
                    Text("Closed")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                    Text("Open")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            // LONG section
            VStack(spacing: 2) {
                Text("LONG")
                    .font(.caption)
                    .fontWeight(.semibold)
                HStack(spacing: 0) {
                    Text("Closed")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                    Text("Open")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            // Sound column
            Text("Sound")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct VowelRowView: View {
    let vowel: Vowel
    var highlightedForm: String? = nil
    var onPractice: ((String) -> Void)? = nil

    private var allForms: [String?] {
        [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open]
    }

    private var isHighlighted: Bool {
        guard let highlighted = highlightedForm else { return false }
        return allForms.compactMap { $0 }.contains(highlighted)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // SHORT section
            HStack(spacing: 0) {
                vowelCell(vowel.short.closed)
                vowelCell(vowel.short.open)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            // LONG section
            HStack(spacing: 0) {
                vowelCell(vowel.long.closed)
                vowelCell(vowel.long.open)
            }
            .frame(maxWidth: .infinity)

            // Sound
            Text(vowel.sound)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(backgroundForRow)
    }

    private var backgroundForRow: Color {
        if isHighlighted {
            return Color.accentColor.opacity(0.1)
        } else if vowel.isRare {
            return Color.pink.opacity(0.1)
        }
        return Color.clear
    }

    @ViewBuilder
    private func vowelCell(_ text: String?) -> some View {
        if let text = text {
            Text(text)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onPractice?(text)
                }
                .background(highlightedForm == text ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        } else {
            Text("-")
                .font(.title2)
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    List {
        Section {
            VowelHeaderView()
                .listRowInsets(EdgeInsets())
        }
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: "กั-", open: "กะ"),
            long: VowelForm(closed: "กา-", open: "กา"),
            sounds: VowelSounds(en: "aa/ah")
        ))
        .listRowInsets(EdgeInsets())
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: nil, open: "โกะ"),
            long: VowelForm(closed: "โก-", open: "โก"),
            sounds: VowelSounds(en: "oh")
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}
