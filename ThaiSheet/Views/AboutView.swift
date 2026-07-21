//
//  AboutView.swift
//  ThaiSheet
//

import SwiftUI

struct AboutView: View {
    // Force-unwraps are safe: literal URLs, validated at development time
    private static let repositoryURL = URL(string: "https://github.com/cmontpetit/ThaiSheet")!
    private static let websiteURL = URL(string: "https://cmontpetit.github.io/ThaiSheet/")!
    private static let privacyURL = URL(string: "https://cmontpetit.github.io/ThaiSheet/privacy.html")!
    private static let supportURL = URL(string: "https://cmontpetit.github.io/ThaiSheet/support.html")!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "5"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    Text("ThaiSheet")
                        .font(.title2.weight(.semibold))
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("An open-source quick reference to help you learn to read Thai")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Open Source") {
                Link(destination: Self.websiteURL) {
                    HStack {
                        Label("Website", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Link(destination: Self.repositoryURL) {
                    HStack {
                        Label("GitHub Repository", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Credits") {
                HStack {
                    Text("Author")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Claude Montpetit")
                }
                HStack {
                    Text("Sound Generation")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Google Cloud TTS & ElevenLabs")
                }
                HStack {
                    Text("Built with")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("SwiftUI")
                }
            }

            Section("Privacy") {
                Text("ThaiSheet does not include analytics, ads, or tracking. Progress and settings stay on device unless you enable iCloud Sync, which uses Apple's iCloud key-value store.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Link("Privacy Policy", destination: Self.privacyURL)
                Link("Support", destination: Self.supportURL)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
