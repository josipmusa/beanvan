import AppKit
import CoffeeProtocol
import Combine
import SwiftUI

@MainActor
enum BeanvanDesign {
    static let brandTeal = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.31, green: 0.78, blue: 0.65, alpha: 1)
            : NSColor(srgbRed: 0.07, green: 0.50, blue: 0.40, alpha: 1)
    })
    static let proposalTint = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.08, green: 0.25, blue: 0.21, alpha: 1)
            : NSColor(srgbRed: 0.84, green: 0.95, blue: 0.92, alpha: 1)
    })
    static let darkMenuBarTeal = Color(red: 0.35, green: 0.82, blue: 0.68)
    static let popoverWidth: CGFloat = 320
}

@MainActor
enum TruckTemplateImage {
    private struct ImageKey: Hashable {
        let steam: Bool
        let proposal: Bool
        let bounceFrame: Int
    }

    private static var cache: [ImageKey: NSImage] = [:]
    private static let bounceOffsets: [CGFloat] = [0, 2.2, 0.6, 1.5, 0]

    static func image(
        steam: Bool,
        proposal: Bool = false,
        bounceFrame: Int = 0
    ) -> NSImage {
        let key = ImageKey(
            steam: steam,
            proposal: proposal,
            bounceFrame: bounceFrame
        )
        if let cached = cache[key] {
            return cached
        }
        let image = makeImage(
            steam: steam,
            proposal: proposal,
            bounceOffset: bounceOffsets.indices.contains(key.bounceFrame)
                ? bounceOffsets[key.bounceFrame]
                : bounceOffsets[0]
        )
        cache[key] = image
        return image
    }

    private static func makeImage(
        steam: Bool,
        proposal: Bool,
        bounceOffset: CGFloat
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: 26, height: 22), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: 2, yBy: 1 + bounceOffset)
            transform.concat()

            let body = NSBezierPath()
            body.move(to: NSPoint(x: 1.2, y: 4.4))
            body.line(to: NSPoint(x: 1.2, y: 9.1))
            body.curve(
                to: NSPoint(x: 3.1, y: 11),
                controlPoint1: NSPoint(x: 1.2, y: 10.4),
                controlPoint2: NSPoint(x: 1.8, y: 11)
            )
            body.line(to: NSPoint(x: 13.4, y: 11))
            body.line(to: NSPoint(x: 15.7, y: 8.5))
            body.line(to: NSPoint(x: 19.3, y: 8.5))
            body.line(to: NSPoint(x: 21, y: 6.8))
            body.line(to: NSPoint(x: 21, y: 4.4))
            body.close()
            body.lineWidth = 1.7
            body.lineJoinStyle = .round
            body.stroke()

            for wheelRect in [
                NSRect(x: 3.1, y: 1.3, width: 4.2, height: 4.2),
                NSRect(x: 15.7, y: 1.3, width: 4.2, height: 4.2),
            ] {
                let wheel = NSBezierPath(ovalIn: wheelRect)
                wheel.lineWidth = 1.7
                wheel.stroke()
            }

            let cup = NSBezierPath()
            cup.move(to: NSPoint(x: 5, y: 10.7))
            cup.line(to: NSPoint(x: 5, y: 13.2))
            cup.curve(
                to: NSPoint(x: 11.4, y: 13.2),
                controlPoint1: NSPoint(x: 5, y: 16.2),
                controlPoint2: NSPoint(x: 11.4, y: 16.2)
            )
            cup.line(to: NSPoint(x: 11.4, y: 10.7))
            cup.lineWidth = 1.7
            cup.lineCapStyle = .square
            cup.stroke()
            let lid = NSBezierPath()
            lid.move(to: NSPoint(x: 4.5, y: 10.7))
            lid.line(to: NSPoint(x: 12, y: 10.7))
            lid.lineWidth = 1.7
            lid.stroke()
            let handle = NSBezierPath(ovalIn: NSRect(x: 10.8, y: 11, width: 3.4, height: 2.6))
            handle.lineWidth = 1.4
            handle.stroke()

            if steam {
                for x in [7.1, 9.7] {
                    let line = NSBezierPath()
                    line.move(to: NSPoint(x: x, y: 15.3))
                    line.curve(
                        to: NSPoint(x: x + 0.2, y: 18.1),
                        controlPoint1: NSPoint(x: x - 1, y: 16.1),
                        controlPoint2: NSPoint(x: x + 1.1, y: 17.2)
                    )
                    line.lineWidth = 1.3
                    line.lineCapStyle = .round
                    line.stroke()
                }
            }
            NSGraphicsContext.restoreGraphicsState()

            if proposal {
                NSBezierPath(
                    ovalIn: NSRect(x: 19, y: 15, width: 7, height: 7)
                ).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

enum MenuBarIconState {
    static func showsSteam(
        at date: Date,
        nextFireDate: Date?,
        peerCount: Int,
        isSkippingToday: Bool
    ) -> Bool {
        guard !isSkippingToday, peerCount > 0, let nextFireDate else { return false }
        let remaining = nextFireDate.timeIntervalSince(date)
        return remaining > 0 && remaining <= 5 * 60
    }

    static func truckOpacity(isSkippingToday: Bool) -> Double {
        isSkippingToday ? 0.4 : 1
    }

    static func shouldBounce(
        previousProposalIDs: [UUID],
        currentProposalIDs: [UUID]
    ) -> Bool {
        !Set(currentProposalIDs).subtracting(previousProposalIDs).isEmpty
    }
}

enum ScheduleTimePicker {
    static func date(for time: ScheduleTime, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(
            year: 2001,
            month: 1,
            day: 1,
            hour: time.hour,
            minute: time.minute
        )) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    static func time(from date: Date, calendar: Calendar) -> ScheduleTime {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ScheduleTime(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }
}

enum ProposalDisplay {
    static func selected(
        from proposals: [ActiveCoffeeProposal],
        localInstanceID: UUID
    ) -> ActiveCoffeeProposal? {
        proposals.first { $0.proposal.proposer == localInstanceID } ?? proposals.first
    }
}

struct MenuBarTruckIcon: View {
    @ObservedObject var peerManager: PeerManager
    @ObservedObject var scheduler: ScheduleFiringScheduler
    @ObservedObject var proposalStore: ProposalStore
    @State private var bounceFrame = 0
    @State private var bounceTask: Task<Void, Never>?
    @State private var currentDate = Date()

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(nsImage: TruckTemplateImage.image(
            steam: shouldShowSteam(at: currentDate),
            proposal: !proposalStore.activeProposals.isEmpty,
            bounceFrame: bounceFrame
        ))
            .opacity(MenuBarIconState.truckOpacity(
                isSkippingToday: scheduler.isSkippingToday
            ))
        .frame(width: 26, height: 22)
        .onReceive(clock) { currentDate = $0 }
        .onChange(of: proposalStore.activeProposals.map(\.id)) { previous, current in
            guard MenuBarIconState.shouldBounce(
                previousProposalIDs: previous,
                currentProposalIDs: current
            ) else { return }
            animateBounce()
        }
        .onDisappear {
            bounceTask?.cancel()
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func animateBounce() {
        bounceTask?.cancel()
        bounceTask = Task { @MainActor in
            for _ in 0..<2 {
                for frame in 1...4 {
                    bounceFrame = frame
                    try? await Task.sleep(for: .milliseconds(90))
                    guard !Task.isCancelled else { return }
                }
            }
            bounceFrame = 0
        }
    }

    private func shouldShowSteam(at date: Date) -> Bool {
        MenuBarIconState.showsSteam(
            at: date,
            nextFireDate: scheduler.nextFireDate,
            peerCount: peerManager.presentPeers.count,
            isSkippingToday: scheduler.isSkippingToday
        )
    }

    private var accessibilityLabel: String {
        if scheduler.isSkippingToday { return "Beanvan, skipping today" }
        if !proposalStore.activeProposals.isEmpty { return "Beanvan, coffee proposal waiting" }
        return "Beanvan"
    }
}

struct CoffeePopover: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var peerManager: PeerManager
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var scheduler: ScheduleFiringScheduler
    @ObservedObject var proposalStore: ProposalStore
    let previewAnimation: () -> Void
    @State private var isShowingSettings = false

    private var displayedProposal: ActiveCoffeeProposal? {
        ProposalDisplay.selected(
            from: proposalStore.activeProposals,
            localInstanceID: proposalStore.localInstanceID
        )
    }

    var body: some View {
        Group {
            if isShowingSettings {
                PopoverSettingsView(
                    appModel: appModel,
                    proposalStore: proposalStore,
                    dismiss: { isShowingSettings = false }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let proposal = displayedProposal {
                            ProposalCard(proposal: proposal, proposalStore: proposalStore)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        StatusHeader(scheduler: scheduler)
                        PresenceSection(peers: peerManager.presentPeers)
                        Divider()
                        ScheduleEditor(scheduleStore: scheduleStore)

                        if let event = scheduleStore.latestChangeEvent {
                            AttributionLine(event: event)
                        }

                        Divider()
                        ActionsSection(scheduler: scheduler, proposalStore: proposalStore)
                        Divider()
                        UtilityFooter(
                            previewAnimation: previewAnimation,
                            showSettings: { isShowingSettings = true }
                        )
                    }
                    .padding(16)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(
            width: BeanvanDesign.popoverWidth,
            alignment: .topLeading
        )
        .background(.regularMaterial)
        .animation(.easeOut(duration: 0.2), value: displayedProposal?.id)
        .animation(.easeOut(duration: 0.18), value: isShowingSettings)
    }
}

private struct ProposalCard: View {
    let proposal: ActiveCoffeeProposal
    @ObservedObject var proposalStore: ProposalStore

    private var isMine: Bool {
        proposal.proposal.proposer == proposalStore.localInstanceID
    }

    private var hasAccepted: Bool {
        proposal.participantIDs.contains(proposalStore.localInstanceID)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                if isMine {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your proposal")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(countText) · \(expiryText(at: context.date))")
                        }
                        Spacer(minLength: 4)
                        Button {
                            proposalStore.cancel(proposal.id)
                        } label: {
                            Text("Cancel")
                                .frame(minHeight: 28)
                                .padding(.horizontal, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(InteractivePlainButtonStyle())
                        .foregroundStyle(BeanvanDesign.brandTeal)
                    }
                } else {
                    Text("\(proposal.proposerName) proposes coffee")
                        .font(.system(size: 14, weight: .medium))
                    HStack {
                        Text(countText)
                        Spacer()
                        Text(expiryText(at: context.date))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !isMine {
                    if hasAccepted {
                        Button("You're in ✓") {}
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .disabled(true)
                    } else {
                        Button {
                            proposalStore.accept(proposal.id)
                        } label: {
                            Text("I'm in")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BeanvanDesign.brandTeal)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BeanvanDesign.proposalTint,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .foregroundStyle(.primary)
        }
    }

    private var countText: String {
        "\(proposal.participantCount) of \(proposalStore.quorumThreshold) in"
    }

    private func expiryText(at date: Date) -> String {
        let expiry = Date(
            timeIntervalSince1970: TimeInterval(proposal.proposal.expiresAt) / 1_000
        )
        return "expires in \(CompactDuration.until(expiry, from: date))"
    }
}

private struct StatusHeader: View {
    @ObservedObject var scheduler: ScheduleFiringScheduler

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                        if scheduler.isSkippingToday {
                            Image(systemName: "moon")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    Spacer()
                    if let nextFireDate = scheduler.nextFireDate,
                       !scheduler.isSkippingToday {
                        Text("in \(CompactDuration.until(nextFireDate, from: context.date))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if scheduler.isSkippingToday {
                    Text("Back tomorrow · not visible to teammates")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var title: String {
        if scheduler.isSkippingToday { return "Skipping today" }
        guard let date = scheduler.nextFireDate else { return "No coffee scheduled" }
        return "Next coffee · \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct PresenceSection: View {
    let peers: [PresentPeer]

    var body: some View {
        HStack(spacing: 9) {
            if !peers.isEmpty {
                HStack(spacing: -6) {
                    ForEach(Array(peers.prefix(5))) { peer in
                        InitialsCircle(peer: peer)
                    }
                    if peers.count > 5 {
                        Text("+\(peers.count - 5)")
                            .font(.system(size: 9, weight: .medium))
                            .frame(width: 22, height: 22)
                            .background(.quaternary, in: Circle())
                            .overlay(Circle().stroke(.background, lineWidth: 1.5))
                    }
                }
            }

            Text(peers.isEmpty ? "Nobody around" : "\(peers.count) around")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(peers.isEmpty ? .secondary : .primary)
        }
        .help(peers.isEmpty ? "Nobody is currently visible" : peerNames)
    }

    private var peerNames: String {
        peers.map(\.name).sorted().joined(separator: ", ")
    }
}

private struct InitialsCircle: View {
    let peer: PresentPeer
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(initials)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(avatarForeground)
            .frame(width: 22, height: 22)
            .background(avatarBackground, in: Circle())
            .overlay(Circle().stroke(.background, lineWidth: 1.5))
            .help(peer.name)
    }

    private var initials: String {
        let words = peer.name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return "?" }
        let last = words.count > 1 ? words.last?.first : nil
        return String([first, last].compactMap { $0 }).uppercased()
    }

    private var avatarBaseColor: Color {
        let byte = withUnsafeBytes(of: peer.id.uuid) { Int($0[0]) }
        let palette: [Color] = [
            Color(nsColor: .systemBlue),
            Color(nsColor: .systemPurple),
            Color(nsColor: .systemPink),
            Color(nsColor: .systemOrange),
            Color(nsColor: .systemIndigo),
            Color(nsColor: .systemGreen),
        ]
        return palette[byte % palette.count]
    }

    private var avatarBackground: Color {
        avatarBaseColor.opacity(colorScheme == .dark ? 0.7 : 0.16)
    }

    private var avatarForeground: Color {
        colorScheme == .dark ? .white : avatarBaseColor
    }
}

private struct ScheduleEditor: View {
    @ObservedObject var scheduleStore: ScheduleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Schedule")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            if scheduleStore.schedule.entries.isEmpty {
                EmptyView()
            }

            ForEach(scheduleStore.schedule.entries) { entry in
                ScheduleEntryRow(
                    entry: entry,
                    updateTime: { newTime in
                        update(entry) { $0.time = newTime }
                    },
                    toggleWeekday: { toggle($0, for: entry) },
                    remove: { remove(entry) }
                )
            }

            if scheduleStore.schedule.entries.count < Schedule.maximumEntryCount {
                Button(action: addEntry) {
                    Label("Add time", systemImage: "plus")
                        .frame(minHeight: 28)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InteractivePlainButtonStyle())
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func toggle(_ weekday: Weekday, for entry: ScheduleEntry) {
        update(entry) {
            if $0.weekdays.contains(weekday) {
                $0.weekdays.remove(weekday)
            } else {
                $0.weekdays.insert(weekday)
            }
        }
    }

    private func update(_ entry: ScheduleEntry, change: (inout ScheduleEntry) -> Void) {
        var entries = scheduleStore.schedule.entries
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        change(&entries[index])
        try? scheduleStore.replaceEntries(entries)
    }

    private func addEntry() {
        var entries = scheduleStore.schedule.entries
        guard entries.count < Schedule.maximumEntryCount else { return }
        entries.append(ScheduleEntry(
            id: UUID(),
            time: ScheduleTime(hour: 10, minute: 30),
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            lastEditedBy: UUID(),
            lastEditedAt: 0
        ))
        try? scheduleStore.replaceEntries(entries)
    }

    private func remove(_ entry: ScheduleEntry) {
        try? scheduleStore.replaceEntries(
            scheduleStore.schedule.entries.filter { $0.id != entry.id }
        )
    }
}

private struct ScheduleEntryRow: View {
    let entry: ScheduleEntry
    let updateTime: (ScheduleTime) -> Void
    let toggleWeekday: (Weekday) -> Void
    let remove: () -> Void
    @State private var focusDismissalTask: Task<Void, Never>?

    private var calendar: Calendar { .autoupdatingCurrent }

    private var time: Binding<Date> {
        Binding(
            get: { ScheduleTimePicker.date(for: entry.time, calendar: calendar) },
            set: {
                updateTime(ScheduleTimePicker.time(from: $0, calendar: calendar))
                scheduleFocusDismissal()
            }
        )
    }

    private let weekdays: [Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]

    var body: some View {
        HStack(spacing: 4) {
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .controlSize(.small)
                .frame(width: 72)
                .accessibilityLabel("Coffee time")

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    WeekdayToggle(
                        weekday: weekday,
                        isOn: entry.weekdays.contains(weekday),
                        action: { toggleWeekday(weekday) }
                    )
                }
            }

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(InteractivePlainButtonStyle())
            .foregroundStyle(.secondary)
            .help("Remove time")
        }
        .onDisappear {
            focusDismissalTask?.cancel()
        }
    }

    private func scheduleFocusDismissal() {
        focusDismissalTask?.cancel()
        focusDismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}

private struct WeekdayToggle: View {
    let weekday: Weekday
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? BeanvanDesign.brandTeal : Color.clear)
                    .overlay {
                        if !isOn {
                            Circle().stroke(.quaternary)
                        }
                    }
                    .frame(width: 20, height: 20)
                Text(WeekdayLabels.short(weekday))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : .secondary)
            }
            .frame(width: 24, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractivePlainButtonStyle())
        .accessibilityLabel(WeekdayLabels.full(weekday))
        .accessibilityValue(isOn ? "Selected" : "Not selected")
    }
}

private struct ActionsSection: View {
    @ObservedObject var scheduler: ScheduleFiringScheduler
    @ObservedObject var proposalStore: ProposalStore

    private var hasLocalProposal: Bool {
        proposalStore.activeProposals.contains {
            $0.proposal.proposer == proposalStore.localInstanceID
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !hasLocalProposal {
                Button {
                    _ = try? proposalStore.proposeCoffeeNow()
                } label: {
                    Text("Propose coffee now")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.bordered)
                .disabled(!proposalStore.canPropose)

                if let cooldownEnd = proposalStore.nextProposalDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("again in \(CompactDuration.until(cooldownEnd, from: context.date))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Toggle(
                "Skip today",
                isOn: Binding(
                    get: { scheduler.isSkippingToday },
                    set: { scheduler.setSkippingToday($0) }
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(BeanvanDesign.brandTeal)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
}

private struct AttributionLine: View {
    let event: ScheduleChangeEvent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text("\(event.message) · \(CompactDuration.ago(event.changedAt, from: context.date))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct UtilityFooter: View {
    let previewAnimation: () -> Void
    let showSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: previewAnimation) {
                Text("Preview")
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .contentShape(Rectangle())
            }
            Button(action: showSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .contentShape(Rectangle())
            }
                .keyboardShortcut("q")
        }
        .buttonStyle(InteractivePlainButtonStyle())
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }
}

private struct InteractivePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct PopoverSettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var proposalStore: ProposalStore
    let dismiss: () -> Void
    @State private var displayName: String
    @State private var teamPhrase: String

    init(appModel: AppModel, proposalStore: ProposalStore, dismiss: @escaping () -> Void) {
        self.appModel = appModel
        self.proposalStore = proposalStore
        self.dismiss = dismiss
        _displayName = State(initialValue: appModel.displayName)
        _teamPhrase = State(initialValue: appModel.teamPhrase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    applySettings()
                    return
                }
                applySettings()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(InteractivePlainButtonStyle())

            SettingsFields(
                appModel: appModel,
                proposalStore: proposalStore,
                displayName: $displayName,
                teamPhrase: $teamPhrase,
                applySettings: applySettings
            )
        }
        .padding(16)
        .frame(width: BeanvanDesign.popoverWidth, alignment: .topLeading)
        .onDisappear(perform: applySettings)
    }

    private func applySettings() {
        appModel.applySettings(displayName: displayName, teamPhrase: teamPhrase)
    }
}

private struct SettingsFields: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var proposalStore: ProposalStore
    @Binding var displayName: String
    @Binding var teamPhrase: String
    let applySettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Display name")
                    .font(.system(size: 13, weight: .semibold))
                TextField("Display name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, weight: .medium))
                    .controlSize(.large)
                    .onSubmit(applySettings)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Team phrase")
                    .font(.system(size: 13, weight: .semibold))
                SecureField("Leave empty for open network", text: $teamPhrase)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, weight: .medium))
                    .controlSize(.large)
                    .onSubmit(applySettings)
                Text("Only Macs with the same phrase see each other.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quorum")
                        .font(.system(size: 14, weight: .semibold))
                    Text("People needed for ‘coffee now’")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                QuorumControl(
                    value: proposalStore.quorumThreshold,
                    decrement: {
                        proposalStore.setQuorumThreshold(proposalStore.quorumThreshold - 1)
                    },
                    increment: {
                        proposalStore.setQuorumThreshold(proposalStore.quorumThreshold + 1)
                    }
                )
            }

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { appModel.launchAtLoginEnabled },
                set: { appModel.setLaunchAtLoginEnabled($0) }
            ))
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())

            Toggle("Proposal notifications", isOn: Binding(
                get: { appModel.proposalNotificationsEnabled },
                set: { appModel.setProposalNotificationsEnabled($0) }
            ))
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())

            Toggle("Don't interrupt full-screen apps", isOn: Binding(
                get: { appModel.avoidsFullScreenApps },
                set: { value in
                    appModel.setInterruptionPreferences(
                        avoidsFullScreenApps: value,
                        avoidsCalls: appModel.avoidsCalls
                    )
                }
            ))
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())

            Toggle("Don't interrupt calls", isOn: Binding(
                get: { appModel.avoidsCalls },
                set: { value in
                    appModel.setInterruptionPreferences(
                        avoidsFullScreenApps: appModel.avoidsFullScreenApps,
                        avoidsCalls: value
                    )
                }
            ))
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())

            Toggle("Sound", isOn: Binding(
                get: { appModel.soundEnabled },
                set: { appModel.setSoundEnabled($0) }
            ))
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())

            if let error = appModel.settingsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct QuorumControl: View {
    let value: Int
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            quorumButton(systemImage: "minus", action: decrement)
                .disabled(value <= 1)

            Divider().frame(height: 16)

            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 30)
                .accessibilityLabel("Quorum")
                .accessibilityValue("\(value) people")

            Divider().frame(height: 16)

            quorumButton(systemImage: "plus", action: increment)
                .disabled(value >= 10)
        }
        .frame(height: 30)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func quorumButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(InteractivePlainButtonStyle())
        .foregroundStyle(.secondary)
        .accessibilityLabel(systemImage == "minus" ? "Decrease quorum" : "Increase quorum")
    }
}

struct BeanvanSettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var proposalStore: ProposalStore
    @State private var displayName: String
    @State private var teamPhrase: String

    init(appModel: AppModel, proposalStore: ProposalStore) {
        self.appModel = appModel
        self.proposalStore = proposalStore
        _displayName = State(initialValue: appModel.displayName)
        _teamPhrase = State(initialValue: appModel.teamPhrase)
    }

    var body: some View {
        SettingsFields(
            appModel: appModel,
            proposalStore: proposalStore,
            displayName: $displayName,
            teamPhrase: $teamPhrase,
            applySettings: {
                appModel.applySettings(displayName: displayName, teamPhrase: teamPhrase)
            }
        )
        .padding(20)
        .frame(width: 340)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Apply") {
                    appModel.applySettings(displayName: displayName, teamPhrase: teamPhrase)
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .onChange(of: appModel.displayName) { _, value in displayName = value }
        .onChange(of: appModel.teamPhrase) { _, value in teamPhrase = value }
    }
}

enum WeekdayLabels {
    static func short(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }

    static func full(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    static func summary(_ weekdays: Set<Weekday>) -> String {
        let ordered = Weekday.allCases
        guard !weekdays.isEmpty else { return "No active days" }
        if weekdays == Set(ordered) { return "Every day" }

        var runs: [[Weekday]] = []
        for weekday in ordered where weekdays.contains(weekday) {
            if let last = runs.last?.last, weekday.rawValue == last.rawValue + 1 {
                runs[runs.count - 1].append(weekday)
            } else {
                runs.append([weekday])
            }
        }
        return runs.map { run in
            let first = abbreviation(run[0])
            guard run.count > 1, let last = run.last else { return first }
            return "\(first)–\(abbreviation(last))"
        }.joined(separator: ", ")
    }

    private static func abbreviation(_ weekday: Weekday) -> String {
        String(full(weekday).prefix(3))
    }
}

enum CompactDuration {
    static func until(_ date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = Int(ceil(Double(seconds) / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func ago(_ date: Date, from now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
