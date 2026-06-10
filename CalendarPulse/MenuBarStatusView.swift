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
        .help(viewModel.status.title)
    }
}
