import AppKit

private enum OverlayMetrics {
    static let panelMaxWidth: CGFloat = 1860
    static let panelMaxHeight: CGFloat = 940
    static let panelInset: CGFloat = 34
    static let columnSpacing: CGFloat = 34
    static let sectionSpacing: CGFloat = 14
    static let rowHeight: CGFloat = 34
    static let rowSpacing: CGFloat = 4
    static let sectionHeaderHeight: CGFloat = 36
    static let cornerRadius: CGFloat = 28
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

private final class ShortcutRowView: NSView {
    private let comboStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let onClick: () -> Void

    var combo: KeyCombo

    var isMatchHighlighted = false {
        didSet {
            if oldValue != isMatchHighlighted {
                updateAppearance()
            }
        }
    }

    init(item: ShortcutItem, onClick: @escaping () -> Void) {
        self.combo = item.combo
        self.onClick = onClick
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: OverlayMetrics.rowHeight).isActive = true

        comboStack.orientation = .horizontal
        comboStack.spacing = 4
        comboStack.alignment = .centerY
        comboStack.distribution = .gravityAreas
        comboStack.translatesAutoresizingMaskIntoConstraints = false

        for segment in item.combo.displaySegments {
            comboStack.addArrangedSubview(KeyTokenView(text: segment))
        }

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 0
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = item.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = item.isEnabled ? .labelColor : .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        subtitleLabel.stringValue = item.subtitle ?? ""
        subtitleLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isHidden = item.subtitle == nil

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(comboStack)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            comboStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            comboStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            comboStack.widthAnchor.constraint(equalToConstant: 178),

            textStack.leadingAnchor.constraint(equalTo: comboStack.trailingAnchor, constant: 12),
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

    private func updateAppearance() {
        if isMatchHighlighted {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor
            titleLabel.textColor = .white
            subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        } else {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.035).cgColor
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .tertiaryLabelColor
        }

        for token in comboStack.arrangedSubviews.compactMap({ $0 as? KeyTokenView }) {
            token.isHighlighted = isMatchHighlighted
        }
    }
}

private final class KeyTokenView: NSView {
    private let label = NSTextField(labelWithString: "")

    var isHighlighted = false {
        didSet { updateAppearance() }
    }

    init(text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5

        label.stringValue = text
        label.font = .systemFont(ofSize: tokenFontSize(for: text), weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: tokenWidth(for: text)),
            heightAnchor.constraint(equalToConstant: 24),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func updateAppearance() {
        layer?.backgroundColor = isHighlighted
            ? NSColor.white.withAlphaComponent(0.24).cgColor
            : NSColor.labelColor.withAlphaComponent(0.08).cgColor
        label.textColor = isHighlighted
            ? .white
            : NSColor.labelColor.withAlphaComponent(0.92)
    }

    private func tokenWidth(for text: String) -> CGFloat {
        switch text.count {
        case 0...1: return 26
        case 2: return 30
        case 3...5: return 46
        default: return 58
        }
    }

    private func tokenFontSize(for text: String) -> CGFloat {
        text.count > 5 ? 10 : 13
    }
}

private final class SectionHeaderView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.11).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: OverlayMetrics.sectionHeaderHeight).isActive = true

        label.stringValue = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
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
    init(title: String, image: NSImage?) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 54).isActive = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let image {
            let iconView = NSImageView(image: image)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(iconView)
            iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
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
    private var rowViews: [ShortcutRowView] = []
    private var rowViewsByID: [UUID: ShortcutRowView] = [:]
    private var currentCatalog: ShortcutCatalog?
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
        contentStack.distribution = .fillEqually
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: OverlayMetrics.panelInset),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -OverlayMetrics.panelInset),
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: OverlayMetrics.panelInset),
            contentStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -OverlayMetrics.panelInset)
        ])

        panel.contentView = rootView
    }

    func show(catalog: ShortcutCatalog) {
        currentCatalog = catalog
        render(catalog)

        let size = preferredPanelSize()
        panel.setFrame(positionedFrame(size: size), display: false)
        panel.orderFrontRegardless()
        beginMouseMonitoring()
    }

    func close() {
        endMouseMonitoring()
        panel.orderOut(nil)
        rowViews.removeAll()
        rowViewsByID.removeAll()
        currentCatalog = nil
    }

    func updatePressedSymbols(_ symbols: Set<String>) {
        guard panel.isVisible else { return }

        let normalized = Set(symbols.map(KeyCombo.normalizedSymbol))
        for row in rowViews {
            row.isMatchHighlighted = row.combo.containsPressedSymbols(normalized)
        }
    }

    func hasShortcutMatching(_ symbols: Set<String>) -> Bool {
        guard !symbols.isEmpty else { return true }
        let normalized = Set(symbols.map(KeyCombo.normalizedSymbol))
        return rowViews.contains { row in
            row.combo.containsPressedSymbols(normalized)
        }
    }

    private func render(_ catalog: ShortcutCatalog) {
        rowViews.removeAll()
        rowViewsByID.removeAll()
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let appColumn = makeColumn(
            title: catalog.appName,
            image: catalog.appIcon,
            sections: catalog.appSections,
            emptyText: "当前应用没有公开菜单快捷键"
        )
        let systemColumn = makeColumn(
            title: "系统",
            image: NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "系统"),
            sections: catalog.systemSections,
            emptyText: "没有系统快捷键"
        )

        contentStack.addArrangedSubview(appColumn)
        contentStack.addArrangedSubview(systemColumn)
    }

    private func makeColumn(
        title: String,
        image: NSImage?,
        sections: [ShortcutSection],
        emptyText: String
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let header = ColumnHeaderView(title: title, image: image)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(scrollView)

        let document = NSStackView()
        document.orientation = .vertical
        document.spacing = OverlayMetrics.sectionSpacing
        document.alignment = .leading
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        if sections.flatMap(\.items).isEmpty {
            let label = NSTextField(labelWithString: emptyText)
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            document.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: document.widthAnchor).isActive = true
            label.heightAnchor.constraint(equalToConstant: 80).isActive = true
        } else {
            for section in sections {
                addSection(section, to: document)
            }
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),

            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        return container
    }

    private func addSection(_ section: ShortcutSection, to document: NSStackView) {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.spacing = OverlayMetrics.rowSpacing
        sectionStack.alignment = .leading
        sectionStack.translatesAutoresizingMaskIntoConstraints = false

        let header = SectionHeaderView(title: section.title)
        sectionStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: sectionStack.widthAnchor).isActive = true

        for item in section.items {
            let row = ShortcutRowView(item: item) { [weak self] in
                self?.flash(rowID: item.id)
            }
            rowViews.append(row)
            rowViewsByID[item.id] = row
            sectionStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: sectionStack.widthAnchor).isActive = true
        }

        document.addArrangedSubview(sectionStack)
        sectionStack.widthAnchor.constraint(equalTo: document.widthAnchor).isActive = true
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
