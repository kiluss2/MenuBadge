/// Marks the choice in an app's picker that equals the Default Look value: "Top right (Default)".
enum DefaultMark {
    static func title(_ title: String, isDefault: Bool) -> String {
        isDefault ? "\(title) (Default)" : title
    }
}
