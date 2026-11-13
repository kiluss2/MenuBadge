import AppKit
import BadgeKit
import Observation

/// Looks for a newer MenuBadge release on GitHub (10 s after launch, then once a day) and installs
/// it with the `install-release.sh` copied into the app, so no script is fetched from the network.
@MainActor @Observable
final class UpdateChecker {
    enum Status: Equatable { case idle, checking, upToDate, failed }

    /// The newer release found by the last successful check.
    private(set) var available: AvailableUpdate?
    /// Shown in Settings; only a manual check reports "up to date" or a failure.
    private(set) var status = Status.idle

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var timer: Timer?

    static let firstCheckDelay: TimeInterval = 10
    static let interval: TimeInterval = 24 * 60 * 60

    /// `MENUBADGE_RELEASE_API_URL` replaces GitHub for testing (a `file://` JSON works).
    static var apiURL: URL {
        if let override = ProcessInfo.processInfo.environment["MENUBADGE_RELEASE_API_URL"],
           let url = URL(string: override) { return url }
        return URL(string: "https://api.github.com/repos/kiluss2/MenuBadge/releases/latest")!
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init(store: SettingsStore) {
        self.store = store
    }

    func start() {
        let first = Timer(timeInterval: Self.firstCheckDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.automaticCheck()
                self?.scheduleDaily()
            }
        }
        RunLoop.main.add(first, forMode: .common)
        timer = first
    }

    private func scheduleDaily() {
        let daily = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.automaticCheck() }
        }
        daily.tolerance = 60 * 60
        RunLoop.main.add(daily, forMode: .common)
        timer = daily
    }

    private func automaticCheck() {
        guard store.settings.checkForUpdates else { return }
        Task { await checkNow(manual: false) }
    }

    /// One anonymous request to GitHub. Failures of an automatic check stay silent.
    func checkNow(manual: Bool) async {
        guard status != .checking else { return }
        if manual { status = .checking }
        var request = URLRequest(url: Self.apiURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MenuBadge/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
            available = try ReleaseInfo.newerRelease(json: data, current: Self.currentVersion)
            status = manual && available == nil ? .upToDate : .idle
        } catch {
            status = manual ? .failed : .idle
        }
    }

    /// Runs the bundled installer in its own session, so it outlives MenuBadge, which it quits,
    /// replaces and reopens. Its output goes to ~/Library/Logs/MenuBadge-update.log.
    func install() {
        guard let update = available,
              let script = Bundle.main.url(forResource: "install-release", withExtension: "sh") else { return }
        let log = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/MenuBadge-update.log").path

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
        var files: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&files)
        defer { posix_spawn_file_actions_destroy(&files) }
        posix_spawn_file_actions_addopen(&files, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&files, 1, log, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        posix_spawn_file_actions_adddup2(&files, 1, 2)

        var environment = ProcessInfo.processInfo.environment
        environment["MENUBADGE_DMG_URL"] = update.dmgURL.absoluteString
        let argv = ["/bin/bash", script.path].map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }
        var pid: pid_t = 0
        posix_spawn(&pid, "/bin/bash", &files, &attributes, argv, envp)
    }
}
