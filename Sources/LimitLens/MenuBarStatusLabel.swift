import AppKit
import LimitLensCore
import SwiftUI

struct MenuBarStatusLabel: View {
    let status: MenuBarStatusSnapshot

    var body: some View {
        Image(nsImage: MenuBarStatusImageRenderer.image(for: status))
            .renderingMode(.original)
            .interpolation(.high)
            .frame(
                width: MenuBarStatusImageRenderer.size(for: status).width,
                height: MenuBarStatusImageRenderer.size(for: status).height
            )
            .help(status.helpText)
            .accessibilityLabel(status.accessibilityLabel)
    }
}
