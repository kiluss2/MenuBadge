import BadgeKit
import Foundation

/// A request to play one animation in the preview now; a new id for every pick, so picking the
/// animation that is already selected plays it again.
struct PreviewReplay: Equatable {
    let field: AppearanceField
    let id = UUID()
}
