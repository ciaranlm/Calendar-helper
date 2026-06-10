import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    let doneAction: () -> Void
    var settingsChanged: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Settings", systemImage: "gearshape")
                    .font(.headline)
                Spacer()
                Button("Done", action: doneAction)
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            Form {
                DatePicker(
                    "Workday start",
                    selection: Binding(
                        get: { settings.workdayStartDate },
                        set: { settings.workdayStartDate = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )

                DatePicker(
                    "Workday end",
                    selection: Binding(
                        get: { settings.workdayEndDate },
                        set: { settings.workdayEndDate = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )

                Toggle("Include all-day events in list", isOn: $settings.includeAllDayEventsInList)
                Toggle("Show event titles in menu bar", isOn: $settings.showEventTitlesInMenuBar)

                Section("Meeting nudges") {
                    Toggle("Meeting nudges", isOn: $settings.meetingNudgesEnabled)

                    Picker("Nudge time", selection: $settings.nudgeTimeMinutes) {
                        ForEach(NudgeTime.allCases) { nudgeTime in
                            Text(nudgeTime.title).tag(nudgeTime.rawValue)
                        }
                    }
                    .disabled(!settings.meetingNudgesEnabled)

                    Toggle("Play sound", isOn: $settings.playNudgeSound)
                        .disabled(!settings.meetingNudgesEnabled)
                }

                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )
                )

                Picker("Refresh interval", selection: $settings.refreshIntervalSeconds) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval.rawValue)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 260)

            if let errorMessage = launchAtLoginManager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(width: 360)
        .frame(minHeight: 360)
        .onAppear { launchAtLoginManager.refresh() }
        .onChange(of: settings.workdayStartMinutes) { _, _ in settingsChanged() }
        .onChange(of: settings.workdayEndMinutes) { _, _ in settingsChanged() }
        .onChange(of: settings.includeAllDayEventsInList) { _, _ in settingsChanged() }
        .onChange(of: settings.showEventTitlesInMenuBar) { _, _ in settingsChanged() }
        .onChange(of: settings.refreshIntervalSeconds) { _, _ in settingsChanged() }
        .onChange(of: settings.meetingNudgesEnabled) { _, _ in settingsChanged() }
        .onChange(of: settings.nudgeTimeMinutes) { _, _ in settingsChanged() }
        .onChange(of: settings.playNudgeSound) { _, _ in settingsChanged() }
    }
}
