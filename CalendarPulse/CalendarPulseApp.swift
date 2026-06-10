import SwiftUI

@main
@MainActor
struct CalendarPulseApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var viewModel: CalendarViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings.shared
        _settings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: CalendarViewModel(settings: settings))
    }

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
