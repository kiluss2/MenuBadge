import Foundation

/// Starts a process in its own session, so it outlives MenuBadge (which it may quit and reopen).
enum DetachedProcess {
    /// `arguments[0]` is the executable path. Output goes to `logPath` (or nowhere).
    @discardableResult
    static func run(_ arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment,
                    logPath: String? = nil) -> Bool {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
        var files: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&files)
        defer { posix_spawn_file_actions_destroy(&files) }
        posix_spawn_file_actions_addopen(&files, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&files, 1, logPath ?? "/dev/null", O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        posix_spawn_file_actions_adddup2(&files, 1, 2)

        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }
        var pid: pid_t = 0
        return posix_spawn(&pid, arguments[0], &files, &attributes, argv, envp) == 0
    }

    /// Opens this app again a moment after it quits (used when macOS needs a relaunch to apply
    /// the Accessibility permission).
    static func relaunchSoon() -> Bool {
        run(["/bin/sh", "-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath])
    }
}
