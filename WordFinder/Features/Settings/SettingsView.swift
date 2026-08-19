import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var playbackSpeed: Double = 1.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.wfTextPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    appearanceSection
                    pronunciationSection
                    dataSection
                    aboutSection

                    Text("WordFinder 1.0 · Definitions by dictionaryapi.dev (CC BY-SA 3.0)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.wfTextSecondary.opacity(0.8))
                        .padding(.horizontal, 34)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                }
            }
            .background(Color.wfBackground)
            .navigationBarHidden(true)
        }
    }

    private var appearanceSection: some View {
        SettingsSection(header: "Appearance") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Text("Applies inside the app only, independent of system settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wfTextSecondary)
            }
            .padding(14)
        }
    }

    private var pronunciationSection: some View {
        SettingsSection(header: "Pronunciation") {
            VStack(spacing: 0) {
                SettingsRow(title: "Voice", detail: "US · Samantha", showsChevron: true)
                Divider().padding(.leading, 16)
                VStack(spacing: 12) {
                    HStack {
                        Text("Playback speed")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.wfTextPrimary)
                        Spacer()
                        Text(String(format: "%.1f×", playbackSpeed))
                            .font(.system(size: 15))
                            .foregroundStyle(Color.wfTextSecondary)
                    }
                    Slider(value: $playbackSpeed, in: 0.5...1.5)
                        .tint(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var dataSection: some View {
        SettingsSection(header: "Data") {
            VStack(spacing: 0) {
                SettingsRow(title: "Clear cache", detail: "32.4 MB")
                Divider().padding(.leading, 16)
                SettingsRow(title: "Delete all history", titleColor: Color.wfDestructive)
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(header: "About") {
            VStack(spacing: 0) {
                SettingsRow(title: "Dictionary attribution", showsChevron: true)
                Divider().padding(.leading, 16)
                SettingsRow(title: "Open source licenses", showsChevron: true)
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let header: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.uppercased())
                .font(.system(size: 13))
                .tracking(0.4)
                .foregroundStyle(Color.wfTextSecondary)
                .padding(.horizontal, 34)
                .padding(.top, 20)

            content
                .background(Color.wfSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
        }
    }
}

private struct SettingsRow: View {
    let title: String
    var detail: String? = nil
    var titleColor: Color = Color.wfTextPrimary
    var showsChevron: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(titleColor)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.wfTextSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.wfSeparator)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }
}

#Preview {
    SettingsView()
}
