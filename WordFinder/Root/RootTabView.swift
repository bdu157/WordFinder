import SwiftUI

struct RootTabView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("Camera", systemImage: "camera.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(Color.accentColor)
        .preferredColorScheme(appTheme.colorScheme)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [DictEntryRecord.self, HistoryRecord.self], inMemory: true)
}
