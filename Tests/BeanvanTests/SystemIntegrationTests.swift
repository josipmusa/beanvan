import AppKit
import SwiftUI
import Testing
@testable import Beanvan

@MainActor
struct SystemIntegrationTests {
    @Test func hostingControllerReportsPreferredHeightChanges() {
        var sizes: [NSSize] = []
        let controller = PopoverHostingController(rootView: EmptyView())
        controller.onPreferredContentSizeChange = { sizes.append($0) }

        controller.preferredContentSize = NSSize(width: 500, height: 200)
        controller.preferredContentSize = NSSize(width: 600, height: 200)
        controller.preferredContentSize = NSSize(width: 600, height: 240)

        #expect(sizes == [
            NSSize(width: 500, height: 200),
            NSSize(width: 600, height: 240),
        ])
    }

    @Test func popoverSizeIgnoresPreferredWidth() {
        #expect(MenuBarPopoverController.normalizedContentSize(
            NSSize(width: 640, height: 240)
        ) == NSSize(width: 320, height: 240))
    }

    @Test func hostedStatusIconDoesNotInterceptButtonClicks() {
        let view = PassthroughHostingView(rootView: EmptyView())
        view.frame = NSRect(x: 0, y: 0, width: 26, height: 22)

        #expect(view.hitTest(NSPoint(x: 13, y: 11)) == nil)
    }
}
