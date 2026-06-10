import SwiftUI

struct CalendarPopoverView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var settings: AppSettings
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                SettingsView(settings: settings, launchAtLoginManager: LaunchAtLoginManager()) {
                    viewModel.settingsChanged()
                    showingSettings = false
                }
            } else {
                scheduleView
            }
        }
        .frame(width: 360)
        .onAppear {
            viewModel.popoverOpened()
        }
        .onChange(of: settings.workdayStartMinutes) { _, _ in viewModel.settingsChanged() }
        .onChange(of: settings.workdayEndMinutes) { _, _ in viewModel.settingsChanged() }
        .onChange(of: settings.refreshIntervalSeconds) { _, _ in viewModel.settingsChanged() }
    }

    private var scheduleView: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            if viewModel.isLoading && viewModel.lastRefreshDate == nil {
                loadingView
            } else if viewModel.accessState != .authorized {
                noAccessView
            } else if let errorMessage = viewModel.errorMessage {
                messageView(title: "Calendar unavailable", message: errorMessage, symbol: "exclamationmark.triangle")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if settings.includeAllDayEventsInList {
                            allDayEventsSection
                        }
                        nextEventSection
                        remainingEventsSection
                        freeBlocksSection
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 480)
            }

            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewModel.status.symbolName)
                .font(.title3)
                .foregroundStyle(viewModel.status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.status.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(viewModel.status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Loading today’s calendar…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private var noAccessView: some View {
        VStack(alignment: .leading, spacing: 10) {
            messageView(
                title: "Calendar access required",
                message: "Calendar access is needed to show your schedule.",
                symbol: "calendar.badge.exclamationmark"
            )
            Button("Open System Settings") {
                viewModel.openPrivacySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    private func messageView(title: String, message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var nextEventSection: some View {
        SectionHeader(title: "Next event")
        if let nextEvent = viewModel.nextEvent {
            NextEventCard(event: nextEvent, startsIn: viewModel.relativeDuration(from: Date(), to: nextEvent.startDate)) {
                viewModel.openCalendar()
            }
        } else {
            EmptyStateRow(text: "No more timed events today.", symbol: "checkmark.circle")
        }
    }

    @ViewBuilder
    private var remainingEventsSection: some View {
        let remaining = viewModel.timedEvents.filter { $0.endDate > Date() }
        SectionHeader(title: "Remaining today")
        if remaining.isEmpty {
            EmptyStateRow(text: "Your calendar is clear for the rest of today.", symbol: "sparkles")
        } else {
            VStack(spacing: 8) {
                ForEach(remaining) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    @ViewBuilder
    private var allDayEventsSection: some View {
        if !viewModel.allDayEvents.isEmpty {
            SectionHeader(title: "All-day")
            VStack(spacing: 8) {
                ForEach(viewModel.allDayEvents) { event in
                    EventRow(event: event, compactTime: "All day")
                }
            }
        }
    }

    @ViewBuilder
    private var freeBlocksSection: some View {
        SectionHeader(title: "Free blocks")
        if viewModel.freeBlocks.isEmpty {
            EmptyStateRow(text: "No open workday blocks remaining.", symbol: "calendar.badge.clock")
        } else {
            VStack(spacing: 8) {
                ForEach(viewModel.freeBlocks) { block in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CalendarViewModel.compactDuration(block.duration))
                                .font(.subheadline.weight(.medium))
                            Text(block.timeRangeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.refresh(requestPermission: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                viewModel.quit()
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .help("Refresh, settings, or quit Calendar Pulse")
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NextEventCard: View {
    let event: CalendarEvent
    let startsIn: String
    let openAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(event.calendarColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("Starts in \(startsIn)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.yellow)
                    Text(event.timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let location = event.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let videoURL = event.videoCallURL {
                Link(destination: videoURL) {
                    Label("Join call", systemImage: "video.fill")
                }
                .font(.caption)
            }

            Button("Open in Calendar", action: openAction)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(event.calendarColor.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    var compactTime: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(event.calendarColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(compactTime ?? event.timeRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location = event.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let videoURL = event.videoCallURL {
                    Link("Video call", destination: videoURL)
                        .font(.caption)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EmptyStateRow: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }
}
