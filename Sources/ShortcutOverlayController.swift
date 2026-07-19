import AppKit

private enum OverlayMetrics {
    static let panelMaxWidth: CGFloat = 1860
    static let panelMaxHeight: CGFloat = 940
    static let panelInset: CGFloat = 34
    static let columnSpacing: CGFloat = 34
    static let cornerRadius: CGFloat = 28
}

private struct OverlayLayout {
    let scale: CGFloat
    let constrainedLaneWidth: CGFloat?

    init(scale: CGFloat, constrainedLaneWidth: CGFloat? = nil) {
        self.scale = scale
        self.constrainedLaneWidth = constrainedLaneWidth
    }

    var groupHeaderHeight: CGFloat { 54 * scale }
    var groupSpacing: CGFloat { 14 * scale }
    var laneSpacing: CGFloat { 14 * scale }
    var sectionGap: CGFloat { 8 * scale }
    var rowHeight: CGFloat { 34 * scale }
    var rowSpacing: CGFloat { 4 * scale }
    var sectionHeaderHeight: CGFloat { 36 * scale }
    var rowCornerRadius: CGFloat { 8 * scale }
    var headerCornerRadius: CGFloat { 7 * scale }
    var laneWidth: CGFloat { constrainedLaneWidth ?? max(148, 304 * scale) }
    var comboWidth: CGFloat { min(max(78, 178 * scale), laneWidth * 0.58) }
    var titleFontSize: CGFloat { max(8.5, 15 * scale) }
    var subtitleFontSize: CGFloat { max(7, 10.5 * scale) }
    var sectionFontSize: CGFloat { max(8.5, 15 * scale) }
    var groupFontSize: CGFloat { max(12, 21 * scale) }
    var iconSize: CGFloat { max(16, 24 * scale) }
    var tokenHeight: CGFloat { max(14, 24 * scale) }
    var tokenSpacing: CGFloat { max(2, 4 * scale) }
    var tokenFontScale: CGFloat { max(0.52, scale) }
}

private enum ShortcutColumnElement {
    case header(String)
    case row(ShortcutItem)
    case gap
}

private struct PackedShortcutColumns {
    let columns: [[ShortcutColumnElement]]
    let fits: Bool
}

final class ShortcutOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class OverlayRootView: NSVisualEffectView {
    var onBackgroundClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onBackgroundClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onBackgroundClick?()
    }
}

private final class EscapeHintView: NSView {
    private let label = NSTextField(labelWithString: "再次按下 Esc 退出")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.94).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 210),
            heightAnchor.constraint(equalToConstant: 36),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ShortcutRowView: NSView {
    private let comboStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let onClick: () -> Void
    private let isEnabled: Bool

    var combo: KeyCombo
    private var tokenViews: [KeyTokenView] = []
    private var isMatchingPressedSymbols = false

    init(item: ShortcutItem, layout: OverlayLayout, onClick: @escaping () -> Void) {
        self.combo = item.combo
        self.isEnabled = item.isEnabled
        self.onClick = onClick
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = layout.rowCornerRadius
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: layout.rowHeight).isActive = true

        comboStack.orientation = .horizontal
        comboStack.spacing = layout.tokenSpacing
        comboStack.alignment = .centerY
        comboStack.distribution = .gravityAreas
        comboStack.translatesAutoresizingMaskIntoConstraints = false

        for segment in item.combo.displaySegments {
            let token = KeyTokenView(text: segment, layout: layout)
            tokenViews.append(token)
            comboStack.addArrangedSubview(token)
        }

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 0
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = item.title
        titleLabel.font = .systemFont(ofSize: layout.titleFontSize, weight: .medium)
        titleLabel.textColor = item.isEnabled ? .labelColor : .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.stringValue = item.subtitle ?? ""
        subtitleLabel.font = .systemFont(ofSize: layout.subtitleFontSize, weight: .regular)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isHidden = item.subtitle == nil
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(comboStack)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            comboStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            comboStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            comboStack.widthAnchor.constraint(equalToConstant: layout.comboWidth),

            textStack.leadingAnchor.constraint(equalTo: comboStack.trailingAnchor, constant: 10 * layout.scale),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick()
    }

    func updatePressedSymbols(_ symbols: Set<String>) {
        isMatchingPressedSymbols = isEnabled && combo.matchesPressedSymbols(symbols)
        for token in tokenViews {
            token.isHighlighted = isMatchingPressedSymbols
                && symbols.contains(KeyCombo.normalizedSymbol(token.text))
        }
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = isMatchingPressedSymbols
            ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            : NSColor.labelColor.withAlphaComponent(0.035).cgColor
        titleLabel.textColor = isMatchingPressedSymbols
            ? .controlAccentColor
            : (isEnabled ? .labelColor : .secondaryLabelColor)
        subtitleLabel.textColor = isMatchingPressedSymbols
            ? NSColor.controlAccentColor.withAlphaComponent(0.76)
            : .tertiaryLabelColor
    }
}

private final class KeyTokenView: NSView {
    private let label = NSTextField(labelWithString: "")
    let text: String

    var isHighlighted = false {
        didSet { updateAppearance() }
    }

    init(text: String, layout: OverlayLayout) {
        self.text = text
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = max(3.5, 5 * layout.scale)

        label.stringValue = text
        label.font = .systemFont(ofSize: tokenFontSize(for: text, scale: layout.tokenFontScale), weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: tokenWidth(for: text, scale: layout.tokenFontScale)),
            heightAnchor.constraint(equalToConstant: layout.tokenHeight),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: max(3, 5 * layout.scale)),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -max(3, 5 * layout.scale)),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func updateAppearance() {
        layer?.backgroundColor = isHighlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.96).cgColor
            : NSColor.labelColor.withAlphaComponent(0.08).cgColor
        label.textColor = isHighlighted
            ? .white
            : NSColor.labelColor.withAlphaComponent(0.92)
    }

    private func tokenWidth(for text: String, scale: CGFloat) -> CGFloat {
        let base: CGFloat
        switch text.count {
        case 0...1: base = 26
        case 2: base = 30
        case 3...5: base = 46
        default: base = 58
        }
        return max(18, base * scale)
    }

    private func tokenFontSize(for text: String, scale: CGFloat) -> CGFloat {
        max(8, (text.count > 5 ? 10 : 13) * scale)
    }
}

private final class SectionHeaderView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(title: String, layout: OverlayLayout) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = layout.headerCornerRadius
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.11).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: layout.sectionHeaderHeight).isActive = true

        label.stringValue = title
        label.font = .systemFont(ofSize: layout.sectionFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ColumnHeaderView: NSView {
    init(title: String, image: NSImage?, layout: OverlayLayout) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = max(6, 8 * layout.scale)
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: layout.groupHeaderHeight).isActive = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10 * layout.scale
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let image {
            let iconView = NSImageView(image: image)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(iconView)
            iconView.widthAnchor.constraint(equalToConstant: layout.iconSize).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: layout.iconSize).isActive = true
        }

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: layout.groupFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class ShortcutOverlayController {
    private let panel: ShortcutOverlayPanel
    private let rootView = OverlayRootView()
    private let contentStack = NSStackView()
    private let escapeHintView = EscapeHintView()
    private var rowViews: [ShortcutRowView] = []
    private var rowViewsByID: [UUID: ShortcutRowView] = [:]
    private var currentCatalog: ShortcutCatalog?
    private var escapeDismissalState = EscapeDismissalState()
    private var escapeHintWorkItem: DispatchWorkItem?
    private var requiresEscapeConfirmation = false
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    var isVisible: Bool {
        panel.isVisible
    }

    init() {
        panel = ShortcutOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 720),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true

        rootView.material = .hudWindow
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = OverlayMetrics.cornerRadius
        rootView.layer?.masksToBounds = true
        rootView.onBackgroundClick = { [weak self] in
            self?.close()
        }

        contentStack.orientation = .horizontal
        contentStack.spacing = OverlayMetrics.columnSpacing
        contentStack.alignment = .top
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(contentStack)

        escapeHintView.isHidden = true
        escapeHintView.alphaValue = 0
        rootView.addSubview(escapeHintView)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: OverlayMetrics.panelInset),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -OverlayMetrics.panelInset),
            contentStack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: OverlayMetrics.panelInset),
            contentStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -OverlayMetrics.panelInset),

            escapeHintView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            escapeHintView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -16)
        ])

        panel.contentView = rootView
    }

    func show(catalog: ShortcutCatalog) {
        resetEscapeConfirmation()
        currentCatalog = catalog
        requiresEscapeConfirmation = containsEscapeShortcut(in: catalog)
        let size = preferredPanelSize()
        let layout = bestLayout(for: catalog, panelSize: size)
        render(catalog, layout: layout, panelSize: size)
        panel.setFrame(positionedFrame(size: size), display: false)
        panel.orderFrontRegardless()
        beginMouseMonitoring()
    }

    func close() {
        resetEscapeConfirmation()
        endMouseMonitoring()
        panel.orderOut(nil)
        rowViews.removeAll()
        rowViewsByID.removeAll()
        currentCatalog = nil
        requiresEscapeConfirmation = false
    }

    func updatePressedSymbols(_ symbols: Set<String>) {
        guard panel.isVisible else { return }

        let normalized = Set(symbols.map(KeyCombo.normalizedSymbol))
        for row in rowViews {
            row.updatePressedSymbols(normalized)
        }
    }

    func handleKeyDown(pressedSymbols: Set<String>, key: String) -> Bool {
        guard panel.isVisible else { return false }

        if KeyCombo.normalizedSymbol(key) == KeyCombo.normalizedSymbol("Esc") {
            handleEscapePress()
            return true
        }

        resetEscapeConfirmation()
        if !hasShortcutMatching(pressedSymbols) {
            close()
        }
        return false
    }

    func hasShortcutMatching(_ symbols: Set<String>) -> Bool {
        guard !symbols.isEmpty else { return true }
        let normalized = Set(symbols.map(KeyCombo.normalizedSymbol))
        return rowViews.contains { row in
            row.combo.matchesPressedSymbols(normalized)
        }
    }

    private func handleEscapePress() {
        let result = escapeDismissalState.registerPress(
            requiresConfirmation: requiresEscapeConfirmation,
            at: ProcessInfo.processInfo.systemUptime
        )

        switch result {
        case .showHint:
            showEscapeHint()
        case .close:
            close()
        }
    }

    private func showEscapeHint() {
        escapeHintWorkItem?.cancel()
        escapeHintView.isHidden = false
        escapeHintView.alphaValue = 1

        let workItem = DispatchWorkItem { [weak self] in
            self?.resetEscapeConfirmation()
        }
        escapeHintWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + escapeDismissalState.confirmationInterval,
            execute: workItem
        )
    }

    private func resetEscapeConfirmation() {
        escapeHintWorkItem?.cancel()
        escapeHintWorkItem = nil
        escapeDismissalState.reset()
        escapeHintView.alphaValue = 0
        escapeHintView.isHidden = true
    }

    private func containsEscapeShortcut(in catalog: ShortcutCatalog) -> Bool {
        let escape = KeyCombo.normalizedSymbol("Esc")
        return (catalog.appSections + catalog.systemSections)
            .flatMap(\.items)
            .contains { KeyCombo.normalizedSymbol($0.combo.key) == escape }
    }

    private func render(_ catalog: ShortcutCatalog, layout: OverlayLayout, panelSize: NSSize) {
        rowViews.removeAll()
        rowViewsByID.removeAll()
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        contentStack.spacing = OverlayMetrics.columnSpacing * layout.scale

        let maxLaneHeight = panelSize.height
            - OverlayMetrics.panelInset * 2
            - layout.groupHeaderHeight
            - layout.groupSpacing

        let appLaneCount = laneCount(
            for: catalog.appSections,
            layout: layout,
            maxLaneHeight: maxLaneHeight
        )
        let systemLaneCount = laneCount(
            for: catalog.systemSections,
            layout: layout,
            maxLaneHeight: maxLaneHeight
        )

        let appColumn = makeGroup(
            title: catalog.appName,
            image: catalog.appIcon,
            sections: catalog.appSections,
            emptyText: "当前应用没有公开菜单快捷键",
            laneCount: appLaneCount,
            maxLaneHeight: maxLaneHeight,
            layout: layout
        )
        let systemColumn = makeGroup(
            title: "系统",
            image: NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "系统"),
            sections: catalog.systemSections,
            emptyText: "没有系统快捷键",
            laneCount: systemLaneCount,
            maxLaneHeight: maxLaneHeight,
            layout: layout
        )

        contentStack.addArrangedSubview(appColumn)
        contentStack.addArrangedSubview(systemColumn)
    }

    private func makeGroup(
        title: String,
        image: NSImage?,
        sections: [ShortcutSection],
        emptyText: String,
        laneCount: Int,
        maxLaneHeight: CGFloat,
        layout: OverlayLayout
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = layout.groupSpacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let header = ColumnHeaderView(title: title, image: image, layout: layout)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let laneStack = NSStackView()
        laneStack.orientation = .horizontal
        laneStack.spacing = layout.laneSpacing
        laneStack.alignment = .top
        laneStack.distribution = .fillEqually
        laneStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(laneStack)

        if sections.flatMap(\.items).isEmpty {
            let label = NSTextField(labelWithString: emptyText)
            label.font = .systemFont(ofSize: layout.titleFontSize, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            laneStack.addArrangedSubview(label)
            label.heightAnchor.constraint(equalToConstant: 80).isActive = true
        } else {
            let packed = pack(
                sections: sections,
                laneCount: laneCount,
                layout: layout,
                maxLaneHeight: maxLaneHeight
            )
            for column in packed.columns {
                let columnStack = makeShortcutLane(elements: column, layout: layout)
                laneStack.addArrangedSubview(columnStack)
            }
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            laneStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            laneStack.heightAnchor.constraint(lessThanOrEqualToConstant: maxLaneHeight)
        ])

        let groupWidth = CGFloat(max(1, laneCount)) * layout.laneWidth
            + CGFloat(max(laneCount - 1, 0)) * layout.laneSpacing
        container.widthAnchor.constraint(equalToConstant: groupWidth).isActive = true

        return container
    }

    private func makeShortcutLane(elements: [ShortcutColumnElement], layout: OverlayLayout) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = layout.rowSpacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        for element in elements {
            switch element {
            case .header(let title):
                let header = SectionHeaderView(title: title, layout: layout)
                stack.addArrangedSubview(header)
                header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            case .row(let item):
                let row = ShortcutRowView(item: item, layout: layout) { [weak self] in
                    self?.flash(rowID: item.id)
                }
                rowViews.append(row)
                rowViewsByID[item.id] = row
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            case .gap:
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                stack.addArrangedSubview(spacer)
                spacer.heightAnchor.constraint(equalToConstant: layout.sectionGap).isActive = true
                spacer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }

        stack.widthAnchor.constraint(equalToConstant: layout.laneWidth).isActive = true
        return stack
    }

    private func flash(rowID: UUID) {
        // 点击快捷键内容时保持面板打开，给一个轻反馈即可。
        guard let row = rowViewsByID[rowID] else { return }
        row.alphaValue = 0.78
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            row.animator().alphaValue = 1
        }
    }

    private func preferredPanelSize() -> NSSize {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let availableWidth = max(640, screen.width - 40)
        let availableHeight = max(520, screen.height - 44)
        let width = min(OverlayMetrics.panelMaxWidth, availableWidth)
        let height = min(OverlayMetrics.panelMaxHeight, availableHeight)
        return NSSize(width: width, height: height)
    }

    private func bestLayout(for catalog: ShortcutCatalog, panelSize: NSSize) -> OverlayLayout {
        let scales = stride(from: CGFloat(1.0), through: CGFloat(0.42), by: CGFloat(-0.04))
        for scale in scales {
            let layout = OverlayLayout(scale: scale)
            let maxLaneHeight = panelSize.height
                - OverlayMetrics.panelInset * 2
                - layout.groupHeaderHeight
                - layout.groupSpacing
            let appLaneCount = laneCount(for: catalog.appSections, layout: layout, maxLaneHeight: maxLaneHeight)
            let systemLaneCount = laneCount(for: catalog.systemSections, layout: layout, maxLaneHeight: maxLaneHeight)
            if requiredWidth(
                appLaneCount: appLaneCount,
                systemLaneCount: systemLaneCount,
                layout: layout
            ) <= panelSize.width {
                return layout
            }
        }

        let fallback = OverlayLayout(scale: 0.42)
        let maxLaneHeight = panelSize.height
            - OverlayMetrics.panelInset * 2
            - fallback.groupHeaderHeight
            - fallback.groupSpacing
        let appLaneCount = laneCount(
            for: catalog.appSections,
            layout: fallback,
            maxLaneHeight: maxLaneHeight
        )
        let systemLaneCount = laneCount(
            for: catalog.systemSections,
            layout: fallback,
            maxLaneHeight: maxLaneHeight
        )
        let totalLanes = max(1, appLaneCount + systemLaneCount)
        let laneSpacingWidth = CGFloat(
            max(appLaneCount - 1, 0) + max(systemLaneCount - 1, 0)
        ) * fallback.laneSpacing
        let fixedWidth = laneSpacingWidth
            + OverlayMetrics.columnSpacing * fallback.scale
            + OverlayMetrics.panelInset * 2
        let fittedLaneWidth = max(
            84,
            min(fallback.laneWidth, (panelSize.width - fixedWidth) / CGFloat(totalLanes))
        )
        return OverlayLayout(
            scale: fallback.scale,
            constrainedLaneWidth: fittedLaneWidth
        )
    }

    private func requiredWidth(
        appLaneCount: Int,
        systemLaneCount: Int,
        layout: OverlayLayout
    ) -> CGFloat {
        let totalLanes = appLaneCount + systemLaneCount
        return CGFloat(totalLanes) * layout.laneWidth
            + CGFloat(max(appLaneCount - 1, 0) + max(systemLaneCount - 1, 0)) * layout.laneSpacing
            + OverlayMetrics.columnSpacing * layout.scale
            + OverlayMetrics.panelInset * 2
    }

    private func laneCount(
        for sections: [ShortcutSection],
        layout: OverlayLayout,
        maxLaneHeight: CGFloat
    ) -> Int {
        guard !sections.flatMap(\.items).isEmpty else { return 1 }

        for count in 1...12 {
            if pack(sections: sections, laneCount: count, layout: layout, maxLaneHeight: maxLaneHeight).fits {
                return count
            }
        }

        return 12
    }

    private func pack(
        sections: [ShortcutSection],
        laneCount: Int,
        layout: OverlayLayout,
        maxLaneHeight: CGFloat
    ) -> PackedShortcutColumns {
        var columns = Array(repeating: [ShortcutColumnElement](), count: max(1, laneCount))
        var heights = Array(repeating: CGFloat(0), count: max(1, laneCount))
        var index = 0
        var overflow = false

        func appendedHeight(_ element: ShortcutColumnElement, currentHeight: CGFloat) -> CGFloat {
            let spacing = currentHeight > 0 ? layout.rowSpacing : 0
            let height: CGFloat
            switch element {
            case .header: height = layout.sectionHeaderHeight
            case .row: height = layout.rowHeight
            case .gap: height = layout.sectionGap
            }
            return currentHeight + spacing + height
        }

        func append(_ element: ShortcutColumnElement) {
            guard columns.indices.contains(index) else {
                overflow = true
                return
            }
            heights[index] = appendedHeight(element, currentHeight: heights[index])
            columns[index].append(element)
        }

        func moveToNextColumnIfNeeded(for element: ShortcutColumnElement) {
            guard columns.indices.contains(index) else {
                overflow = true
                return
            }
            let nextHeight = appendedHeight(element, currentHeight: heights[index])
            if nextHeight > maxLaneHeight, index < columns.count - 1 {
                index += 1
            }
        }

        for section in sections where !section.items.isEmpty {
            moveToNextColumnIfNeeded(for: .header(section.title))
            append(.header(section.title))

            for item in section.items {
                let row = ShortcutColumnElement.row(item)
                if appendedHeight(row, currentHeight: heights[index]) > maxLaneHeight {
                    if index < columns.count - 1 {
                        index += 1
                        append(.header(section.title))
                    } else {
                        overflow = true
                    }
                }
                append(row)
            }

            if section.id != sections.last(where: { !$0.items.isEmpty })?.id {
                moveToNextColumnIfNeeded(for: .gap)
                append(.gap)
            }
        }

        if heights.contains(where: { $0 > maxLaneHeight + 1 }) {
            overflow = true
        }

        return PackedShortcutColumns(columns: columns, fits: !overflow)
    }

    private func positionedFrame(size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func beginMouseMonitoring() {
        endMouseMonitoring()

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible, event.window == self.panel else {
                return event
            }

            if self.isShortcutRowHit(at: event.locationInWindow) {
                return event
            }

            self.close()
            return nil
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.panel.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.close()
                }
            }
        }
    }

    private func endMouseMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        localMouseMonitor = nil
        globalMouseMonitor = nil
    }

    private func isShortcutRowHit(at location: NSPoint) -> Bool {
        guard let hit = panel.contentView?.hitTest(location) else {
            return false
        }

        var current: NSView? = hit
        while let view = current {
            if view is ShortcutRowView {
                return true
            }
            current = view.superview
        }
        return false
    }
}
