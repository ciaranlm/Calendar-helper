import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        Label {
            Text(viewModel.status.menuText)
                .lineLimit(1)
        } icon: {
            Image(systemName: viewModel.status.symbolName)
                .foregroundStyle(viewModel.status.color)
        }
        .symbolEffect(.pulse, isActive: viewModel.isNudgeAnimating)
        .opacity(viewModel.isNudgeAnimating ? 0.88 : 1)
        .animation(.easeInOut(duration: 0.7).repeatCount(5, autoreverses: true), value: viewModel.isNudgeAnimating)
        .help(viewModel.status.title)
    }
}
