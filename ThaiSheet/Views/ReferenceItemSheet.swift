//
//  ReferenceItemSheet.swift
//  ThaiSheet
//

import SwiftUI

/// A reusable sheet for reference items showing stage, notes, and action buttons
struct ReferenceItemSheet: View {
    let title: String
    let stage: SRSStage
    let note: String?
    let hasSound: Bool
    let onPlaySound: () -> Void
    let onPractice: () -> Void

    @Environment(\.dismiss) var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text(title)
                .font(.system(size: titleSize))
                .minimumScaleFactor(0.5)
                .padding(.top, 20)

            // Stage indicator
            StageIndicatorView(stage: stage, isCapped: false)

            // Note (if any)
            if let note = note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onPlaySound()
                } label: {
                    HStack {
                        Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                        Text("Play Sound")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasSound ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundColor(hasSound ? .white : .secondary)
                    .cornerRadius(12)
                }
                .disabled(!hasSound)

                Button {
                    dismiss()
                    onPractice()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack")
                        Text("Practice")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Tap to show sheet")
        .sheet(isPresented: .constant(true)) {
            ReferenceItemSheet(
                title: "ก",
                stage: .apprentice1,
                note: "This is a sample note explaining the character.",
                hasSound: true,
                onPlaySound: {},
                onPractice: {}
            )
        }
}
