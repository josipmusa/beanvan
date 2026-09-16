import AppKit
import Foundation
import ServiceManagement
import UserNotifications
import os

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

final class ProposalNotifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ProposalNotifier()

    private let center: UNUserNotificationCenter
    private let logger = Logger(
        subsystem: "com.josipmusa.beanvan",
        category: "notifications"
    )
    var onProposalSelected: (@MainActor @Sendable () -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [logger] _, error in
            if let error {
                logger.error(
                    "Notification authorization failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func notify(about proposal: ActiveCoffeeProposal) {
        let content = UNMutableNotificationContent()
        content.title = "Coffee proposed"
        content.body = "\(proposal.proposerName) is looking for coffee company. Open Beanvan to join."
        content.sound = .default
        content.threadIdentifier = "coffee-proposals"
        content.userInfo = ["proposalID": proposal.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "proposal-\(proposal.id.uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request) { [logger] error in
            if let error {
                logger.error(
                    "Could not deliver a proposal notification: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              response.notification.request.content.userInfo["proposalID"] is String else {
            completionHandler()
            return
        }
        completionHandler()
        Task { @MainActor [weak self] in
            self?.onProposalSelected?()
        }
    }
}
