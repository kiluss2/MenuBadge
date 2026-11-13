import AppKit

/// Walks one app's badge through every state, with a caption item in the menu bar.
@MainActor
final class DemoRun {
    static let steps: [(caption: String, label: String?, seconds: Double)] = [
        ("Demo: no unreads", nil, 4),
        ("Demo: plain unreads → dot (shake, then idle animation)", "•", 8),
        ("Demo: a mention → 1 (shake)", "1", 8),
        ("Demo: more mentions → 3 (shake)", "3", 8),
        ("Demo: two digits → 12 (shake)", "12", 8),
        ("Demo: mentions read, unreads left → dot", "•", 8),
        ("Demo: all read → hidden", nil, 4),
    ]

    let bundleID: String
    let quitWhenDone: Bool
    private let start = Date()
    private var caption: NSStatusItem?

    init(bundleID: String, quitWhenDone: Bool) {
        self.bundleID = bundleID
        self.quitWhenDone = quitWhenDone
    }

    /// The label to show now, or `.finished` once every step has run.
    enum Step { case label(String?), finished }

    func current() -> Step {
        var t = Date().timeIntervalSince(start)
        for step in Self.steps {
            if t < step.seconds {
                setCaption(step.caption)
                return .label(step.label)
            }
            t -= step.seconds
        }
        end()
        return .finished
    }

    func end() {
        if let caption { NSStatusBar.system.removeStatusItem(caption) }
        caption = nil
    }

    private func setCaption(_ text: String) {
        if caption == nil { caption = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) }
        if caption?.button?.title != text { caption?.button?.title = text }
    }
}
