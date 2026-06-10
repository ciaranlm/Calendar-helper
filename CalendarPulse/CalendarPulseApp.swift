import SwiftUI

@main
struct CalendarPulseApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var viewModel = CalendarViewModel(settings: AppSettings.shared)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        MenuBarExtra {
            CalendarPopoverView(viewModel: viewModel, settings: settings)
        } label: {
            MenuBarStatusView(viewModel: viewModel)
                .task { viewModel.start() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await viewModel.refresh(requestPermission: true) }
                    }
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, launchAtLoginManager: LaunchAtLoginManager()) {}
                .frame(width: 420)
        }
    }

}
