import AppKit
import CoffeeProtocol
import SwiftUI

@main
struct BeanvanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel.shared

    var body: some Scene {
        Settings {
            if let proposalStore = appModel.proposalStore {
                BeanvanSettingsView(appModel: appModel, proposalStore: proposalStore)
            }
        }
    }
}

@MainActor
final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    var onPreferredContentSizeChange: ((NSSize) -> Void)?

    override var preferredContentSize: NSSize {
        didSet {
            guard preferredContentSize.height != oldValue.height else { return }
            onPreferredContentSizeChange?(preferredContentSize)
        }
    }
}

@MainActor
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class MenuBarPopoverController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let contentHostingController: PopoverHostingController<AnyView>
    private let statusHostingView: PassthroughHostingView<AnyView>
    private var preparedInitialSize = false

    init(appModel: AppModel, previewAnimation: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        popover = NSPopover()
        contentHostingController = PopoverHostingController(
            rootView: Self.popoverContent(
                appModel: appModel,
                previewAnimation: previewAnimation
            )
        )
        statusHostingView = PassthroughHostingView(
            rootView: Self.statusContent(appModel: appModel)
        )
        super.init()

        contentHostingController.sizingOptions = [.preferredContentSize]
        contentHostingController.onPreferredContentSizeChange = { [weak self] size in
            self?.updateContentSize(size)
        }

        popover.animates = true
        popover.behavior = .transient
        popover.contentViewController = contentHostingController

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            statusHostingView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(statusHostingView)
            NSLayoutConstraint.activate([
                statusHostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                statusHostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                statusHostingView.widthAnchor.constraint(equalToConstant: 26),
                statusHostingView.heightAnchor.constraint(equalToConstant: 22),
            ])
        }
    }

    static func normalizedContentSize(_ preferredSize: NSSize) -> NSSize {
        NSSize(width: BeanvanDesign.popoverWidth, height: preferredSize.height)
    }

    func show() {
        guard !popover.isShown, let button = statusItem.button else { return }
        if !preparedInitialSize {
            updateContentSize(contentHostingController.sizeThatFits(in: NSSize(
                width: BeanvanDesign.popoverWidth,
                height: .infinity
            )))
            preparedInitialSize = true
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func invalidate() {
        popover.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
        }
    }

    private func updateContentSize(_ preferredSize: NSSize) {
        let size = Self.normalizedContentSize(preferredSize)
        guard popover.contentSize != size else { return }
        popover.contentSize = size
    }

    private static func popoverContent(
        appModel: AppModel,
        previewAnimation: @escaping () -> Void
    ) -> AnyView {
        if let peerManager = appModel.peerManager,
           let scheduleStore = appModel.scheduleStore,
           let scheduler = appModel.scheduler,
           let proposalStore = appModel.proposalStore {
            return AnyView(CoffeePopover(
                appModel: appModel,
                peerManager: peerManager,
                scheduleStore: scheduleStore,
                scheduler: scheduler,
                proposalStore: proposalStore,
                previewAnimation: previewAnimation
            ))
        }
        return AnyView(ContentUnavailableView(
            "Beanvan could not start",
            systemImage: "exclamationmark.triangle",
            description: Text(appModel.startupError ?? "Unknown startup error")
        )
        .frame(width: BeanvanDesign.popoverWidth, height: 220))
    }

    private static func statusContent(appModel: AppModel) -> AnyView {
        if let peerManager = appModel.peerManager,
           let scheduler = appModel.scheduler,
           let proposalStore = appModel.proposalStore {
            return AnyView(MenuBarTruckIcon(
                peerManager: peerManager,
                scheduler: scheduler,
                proposalStore: proposalStore
            ))
        }
        return AnyView(Image(nsImage: TruckTemplateImage.image(steam: false))
            .accessibilityLabel("Beanvan"))
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let peerManager: PeerManager?
    let scheduleStore: ScheduleStore?
    let scheduler: ScheduleFiringScheduler?
    let proposalStore: ProposalStore?
    let startupError: String?

    @Published private(set) var displayName = ""
    @Published private(set) var teamPhrase = ""
    @Published private(set) var avoidsFullScreenApps = true
    @Published private(set) var avoidsCalls = true
    @Published private(set) var soundEnabled = false
    @Published private(set) var proposalNotificationsEnabled = true
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var settingsError: String?

    private var instance: AppInstance?

    private init() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            let baseInstance = try AppInstance.load(arguments: arguments)
            let settings = try AppSettings.load(for: baseInstance, arguments: arguments).validated()
            let instance = AppInstance(
                displayName: settings.displayName,
                requestedPort: baseInstance.requestedPort,
                teamPhrase: settings.teamPhrase,
                stateDirectory: baseInstance.stateDirectory,
                id: baseInstance.id
            )
            let manager = PeerManager(instance: instance, teamPhrase: instance.teamPhrase)
            let scheduleStore = try ScheduleStore(instance: instance, transport: manager)
            let proposalStore = try ProposalStore(instance: instance, transport: manager)
            let scheduler = ScheduleFiringScheduler(
                instance: instance,
                scheduleStore: scheduleStore,
                peerManager: manager
            )
            try manager.start()

            self.instance = instance
            displayName = instance.displayName
            teamPhrase = instance.teamPhrase
            avoidsFullScreenApps = settings.avoidsFullScreenApps
            avoidsCalls = settings.avoidsCalls
            soundEnabled = settings.soundEnabled
            proposalNotificationsEnabled = settings.proposalNotificationsEnabled
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            peerManager = manager
            self.scheduleStore = scheduleStore
            self.scheduler = scheduler
            self.proposalStore = proposalStore
            startupError = nil
        } catch {
            peerManager = nil
            scheduleStore = nil
            scheduler = nil
            proposalStore = nil
            startupError = error.localizedDescription
            fputs("Beanvan peer discovery failed: \(error.localizedDescription)\n", stderr)
        }
    }

    func applySettings(displayName: String, teamPhrase: String) {
        guard let oldInstance = instance,
              let peerManager,
              let scheduleStore,
              let proposalStore else { return }

        do {
            let settings = try AppSettings(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                teamPhrase: teamPhrase,
                avoidsFullScreenApps: avoidsFullScreenApps,
                avoidsCalls: avoidsCalls,
                soundEnabled: soundEnabled,
                proposalNotificationsEnabled: proposalNotificationsEnabled
            ).validated()
            guard settings.displayName != oldInstance.displayName
                    || settings.teamPhrase != oldInstance.teamPhrase else {
                settingsError = nil
                return
            }

            let updated = AppInstance(
                displayName: settings.displayName,
                requestedPort: oldInstance.requestedPort,
                teamPhrase: settings.teamPhrase,
                stateDirectory: oldInstance.stateDirectory,
                id: oldInstance.id
            )
            try settings.persist(for: updated)
            do {
                try peerManager.reconfigure(instance: updated)
            } catch {
                try? AppSettings(
                    displayName: oldInstance.displayName,
                    teamPhrase: oldInstance.teamPhrase,
                    avoidsFullScreenApps: avoidsFullScreenApps,
                    avoidsCalls: avoidsCalls,
                    soundEnabled: soundEnabled,
                    proposalNotificationsEnabled: proposalNotificationsEnabled
                ).persist(for: oldInstance)
                throw error
            }
            scheduleStore.updateInstance(updated)
            proposalStore.updateInstance(updated)
            instance = updated
            self.displayName = updated.displayName
            self.teamPhrase = updated.teamPhrase
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
        }
    }

    func setInterruptionPreferences(avoidsFullScreenApps: Bool, avoidsCalls: Bool) {
        guard let instance else { return }
        let oldFullScreenValue = self.avoidsFullScreenApps
        let oldCallsValue = self.avoidsCalls
        self.avoidsFullScreenApps = avoidsFullScreenApps
        self.avoidsCalls = avoidsCalls
        do {
            try AppSettings(
                displayName: displayName,
                teamPhrase: teamPhrase,
                avoidsFullScreenApps: avoidsFullScreenApps,
                avoidsCalls: avoidsCalls,
                soundEnabled: soundEnabled,
                proposalNotificationsEnabled: proposalNotificationsEnabled
            ).persist(for: instance)
            settingsError = nil
        } catch {
            self.avoidsFullScreenApps = oldFullScreenValue
            self.avoidsCalls = oldCallsValue
            settingsError = error.localizedDescription
        }
    }

    func setSoundEnabled(_ enabled: Bool) {
        guard let instance else { return }
        let oldValue = soundEnabled
        soundEnabled = enabled
        do {
            try AppSettings(
                displayName: displayName,
                teamPhrase: teamPhrase,
                avoidsFullScreenApps: avoidsFullScreenApps,
                avoidsCalls: avoidsCalls,
                soundEnabled: enabled,
                proposalNotificationsEnabled: proposalNotificationsEnabled
            ).persist(for: instance)
            settingsError = nil
        } catch {
            soundEnabled = oldValue
            settingsError = error.localizedDescription
        }
    }

    func setProposalNotificationsEnabled(_ enabled: Bool) {
        guard let instance else { return }
        let oldValue = proposalNotificationsEnabled
        proposalNotificationsEnabled = enabled
        do {
            try AppSettings(
                displayName: displayName,
                teamPhrase: teamPhrase,
                avoidsFullScreenApps: avoidsFullScreenApps,
                avoidsCalls: avoidsCalls,
                soundEnabled: soundEnabled,
                proposalNotificationsEnabled: enabled
            ).persist(for: instance)
            if enabled {
                ProposalNotifier.shared.requestAuthorization()
            }
            settingsError = nil
        } catch {
            proposalNotificationsEnabled = oldValue
            settingsError = error.localizedDescription
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            settingsError = enabled && !launchAtLoginEnabled
                ? "Allow Beanvan in System Settings > General > Login Items."
                : nil
        } catch {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            settingsError = error.localizedDescription
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayController?
    private var firingGate: FiringGate?
    private var menuBarPopoverController: MenuBarPopoverController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlayController = OverlayController(resources: AppResources.shared)
        firingGate = FiringGate()
        menuBarPopoverController = MenuBarPopoverController(
            appModel: AppModel.shared,
            previewAnimation: { [weak self] in self?.previewAnimation() }
        )
        ProposalNotifier.shared.onProposalSelected = { [weak self] in
            NSApp.activate()
            self?.menuBarPopoverController?.show()
        }
        if AppModel.shared.proposalNotificationsEnabled {
            ProposalNotifier.shared.requestAuthorization()
        }
        AppModel.shared.scheduler?.start { [weak self] in
            self?.showAutomaticOverlayIfAllowed()
        }
        AppModel.shared.proposalStore?.start(
            onFire: { [weak self] in
                self?.showAutomaticOverlayIfAllowed()
            },
            onIncomingProposal: { proposal in
                guard AppModel.shared.proposalNotificationsEnabled else { return }
                ProposalNotifier.shared.notify(about: proposal)
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProposalNotifier.shared.onProposalSelected = nil
        menuBarPopoverController?.invalidate()
        menuBarPopoverController = nil
        AppModel.shared.scheduler?.stop()
        AppModel.shared.proposalStore?.stop()
        AppModel.shared.peerManager?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModel.shared.refreshLaunchAtLoginStatus()
    }

    func previewAnimation() {
        overlayController?.show(soundEnabled: AppModel.shared.soundEnabled)
    }

    private func showAutomaticOverlayIfAllowed() {
        let appModel = AppModel.shared
        guard firingGate?.allowsFire(
            avoidsFullScreenApps: appModel.avoidsFullScreenApps,
            avoidsCalls: appModel.avoidsCalls
        ) == true else { return }
        overlayController?.show(soundEnabled: appModel.soundEnabled)
    }
}
