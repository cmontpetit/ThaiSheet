import SwiftUI

/// The toolbar can collapse search to an icon while its query still filters
/// every section. Keep the active query visible independently of that UI.
struct ReferenceSearchFilter: View {
    @Binding var text: String
    let onEdit: () -> Void

    var body: some View {
        if !text.isEmpty {
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Label {
                        Text(verbatim: text)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Search filter: \(text)"))
                .accessibilityHint(Text("Edit search"))
                .accessibilityIdentifier("reference.searchFilter.edit")

                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
                .accessibilityIdentifier("reference.searchFilter.clear")
            }
            .font(.subheadline)
            .padding(.leading, 12)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)
            .contentColumn()
            .accessibilityIdentifier("reference.searchFilter")
        }
    }
}
