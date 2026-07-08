import AppKit
import ResetStatCore
import SwiftUI

@main
struct ResetStatApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            ResetStatPopover(viewModel: viewModel)
                .frame(width: 460)
        } label: {
            MenuBarStatusLabel(status: viewModel.menuBarStatus)
                .task {
                    viewModel.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
