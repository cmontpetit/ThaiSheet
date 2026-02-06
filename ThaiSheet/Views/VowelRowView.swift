//
//  VowelRowView.swift
//  ThaiSheet
//

import SwiftUI

enum VowelFormType {
    case shortClosed, shortOpen, longClosed, longOpen

    var duration: String {
        switch self {
        case .shortClosed, .shortOpen: return "Short"
        case .longClosed, .longOpen: return "Long"
        }
    }

    var form: String {
        switch self {
        case .shortClosed, .longClosed: return "Closed"
        case .shortOpen, .longOpen: return "Open"
        }
    }
}

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

            // Sound column (center)
            Text("Sound")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60)

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
    var searchQuery: String? = nil
    var onPractice: ((String) -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @State private var selectedFormType: VowelFormType? = nil
    @State private var selectedText: String? = nil

    private var allForms: [String?] {
        [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open]
    }

    private func formMatchesSearch(_ form: String?) -> Bool {
        guard let form = form, let query = searchQuery, !query.isEmpty else { return true }
        return form.contains(query)
    }

    private var isHighlighted: Bool {
        guard let highlighted = highlightedForm else { return false }
        return allForms.compactMap { $0 }.contains(highlighted)
    }

    // Find a form that has a sound file (prefer closed forms)
    private var soundForm: String? {
        let formsToTry = [vowel.long.closed, vowel.short.closed, vowel.long.open, vowel.short.open]
        return formsToTry.compactMap { $0 }.first { audioPlayer.hasSound(.vowel, key: $0) }
    }

    private var hasSound: Bool {
        soundForm != nil
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
                vowelCell(vowel.short.closed, formType: .shortClosed)
                vowelCell(vowel.short.open, formType: .shortOpen)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            // Sound (center, display only)
            Text(vowel.sound)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 60)

            Divider()
                .frame(height: 30)

            // LONG section
            HStack(spacing: 0) {
                vowelCell(vowel.long.closed, formType: .longClosed)
                vowelCell(vowel.long.open, formType: .longOpen)
            }
            .frame(maxWidth: .infinity)
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
    private func vowelCell(_ text: String?, formType: VowelFormType) -> some View {
        if let text = text {
            let matches = formMatchesSearch(text)
            let isSelected = highlightedForm == text
            Button {
                selectedFormType = formType
                selectedText = text
            } label: {
                Text(text)
                    .font(.title2)
                    .foregroundColor(matches ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .sheet(
                isPresented: Binding(
                    get: { selectedFormType == formType },
                    set: { if !$0 { selectedFormType = nil; selectedText = nil } }
                )
            ) {
                ReferenceItemSheet(
                    title: text,
                    stage: learningModel.getProgress(forId: "vowel-\(text)").srsStage,
                    note: vowel.note(for: formType.duration, form: formType.form),
                    hasSound: audioPlayer.hasSound(.vowel, key: text),
                    onPlaySound: { audioPlayer.play(.vowel, key: text) },
                    onPractice: { onPractice?(text) }
                )
            }
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
            sounds: VowelSounds(en: "aa/ah"),
            notes: nil,
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: "ก-", open: "โกะ"),
            long: VowelForm(closed: "โก-", open: "โก"),
            sounds: VowelSounds(en: "oh"),
            notes: VowelNotes(short_closed: "Unwritten/inherent vowel (e.g., กก = gok)", short_open: nil, long_closed: nil, long_open: nil),
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}
