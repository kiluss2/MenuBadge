import AppKit
import BadgeKit
import SwiftUI

/// SwiftUI-friendly views of the stored values, so editors bind with key paths.
extension BadgeAppearance {
    var countSwatch: Color {
        get { Color(nsColor: NSColor(countColor)) }
        set { countColor = RGBA(NSColor(newValue)) }
    }

    var dotSwatch: Color {
        get { Color(nsColor: NSColor(dotColor)) }
        set { dotColor = RGBA(NSColor(newValue)) }
    }

    var textSwatch: Color {
        get { Color(nsColor: NSColor(textColor)) }
        set { textColor = RGBA(NSColor(newValue)) }
    }
}

extension Corner {
    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }
}

extension IdleAnimation {
    var title: String {
        switch self {
        case .blink: "Blink"
        case .breathe: "Breathe"
        case .bounce: "Bounce"
        case .ripple: "Ripple"
        case .none: "None"
        }
    }
}

extension NewBadgeEffect {
    var title: String {
        switch self {
        case .shake: "Shake"
        case .bounce: "Bounce"
        case .none: "None"
        }
    }
}
