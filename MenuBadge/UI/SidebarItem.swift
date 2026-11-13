/// A row in the Settings sidebar.
enum SidebarItem: Hashable {
    case general
    case defaultLook
    case app(String) // bundle id
}
