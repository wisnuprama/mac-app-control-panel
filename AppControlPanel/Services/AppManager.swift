import Foundation
import AppKit

class AppManager: ObservableObject {
    static let shared = AppManager()

    @Published var appEntries: [AppEntry] = []

    private let databaseManager = DatabaseManager.shared

    private init() {
        loadEntries()
    }

    func loadEntries() {
        appEntries = databaseManager.getAllAppEntries()
    }

    func addEntry(_ entry: AppEntry) {
        if let id = databaseManager.insertAppEntry(entry) {
            var newEntry = entry
            newEntry.id = id
            appEntries.insert(newEntry, at: 0)
        }
    }

    func removeEntry(_ entry: AppEntry) {
        guard let id = entry.id else { return }
        if databaseManager.deleteAppEntry(id: id) {
            appEntries.removeAll { $0.id == id }
        }
    }

    func openApp(_ entry: AppEntry) {
        switch entry.type {
        case .application:
            openApplication(at: entry.path)
        case .script:
            runScript(entry.path)
        }
    }

    func forceKillApp(_ entry: AppEntry) {
        guard entry.type == .application else { return }

        let appName = URL(fileURLWithPath: entry.path).deletingPathExtension().lastPathComponent

        // Find running applications with matching name
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName == appName || $0.bundleURL?.path == entry.path
        }

        for app in runningApps {
            app.forceTerminate()
        }

        // Also try using pkill as a fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-9", appName]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Error killing app: \(error)")
        }
    }

    private func openApplication(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            if let error = error {
                print("Error opening application: \(error)")
            }
        }
    }

    private func runScript(_ scriptContent: String) {
        let process = Process()

        // Check if it's a file path or inline script
        if FileManager.default.fileExists(atPath: scriptContent) {
            // It's a file path
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptContent]
        } else {
            // It's an inline script
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", scriptContent]
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            // Don't wait for completion for background scripts
        } catch {
            print("Error running script: \(error)")
        }
    }

    func isAppRunning(_ entry: AppEntry) -> Bool {
        guard entry.type == .application else { return false }

        let appName = URL(fileURLWithPath: entry.path).deletingPathExtension().lastPathComponent

        return NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == appName || $0.bundleURL?.path == entry.path
        }
    }

    // MARK: - Auto-add Apps by Keyword

    /// Scans the Applications folder and adds apps matching the keyword
    /// - Parameter keyword: The keyword to match (case-insensitive, partial match)
    /// - Returns: Number of apps added
    @discardableResult
    func addAppsMatchingKeyword(_ keyword: String) -> Int {
        let matchingApps = findAppsMatchingKeyword(keyword)
        var addedCount = 0

        for appURL in matchingApps {
            let appPath = appURL.path

            // Check if app already exists in database
            if !databaseManager.appEntryExistsByPath(appPath) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                let entry = AppEntry(name: appName, path: appPath, type: .application)

                if let id = databaseManager.insertAppEntry(entry) {
                    var newEntry = entry
                    newEntry.id = id
                    appEntries.insert(newEntry, at: 0)
                    addedCount += 1
                }
            }
        }

        return addedCount
    }

    /// Finds all applications in the Applications folder matching the keyword
    /// - Parameter keyword: The keyword to match (case-insensitive, partial match)
    /// - Returns: Array of URLs for matching applications
    func findAppsMatchingKeyword(_ keyword: String) -> [URL] {
        let fileManager = FileManager.default
        var matchingApps: [URL] = []

        // Search in main Applications folder
        let applicationsPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let lowercasedKeyword = keyword.lowercased()

        for applicationsPath in applicationsPaths {
            let applicationsURL = URL(fileURLWithPath: applicationsPath)

            guard let contents = try? fileManager.contentsOfDirectory(
                at: applicationsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for itemURL in contents {
                // Check if it's an application bundle
                if itemURL.pathExtension.lowercased() == "app" {
                    let appName = itemURL.deletingPathExtension().lastPathComponent.lowercased()

                    // Case-insensitive partial match
                    if appName.contains(lowercasedKeyword) {
                        matchingApps.append(itemURL)
                    }
                }
            }
        }

        return matchingApps
    }

    /// Preview apps that would be added for a keyword without actually adding them
    /// - Parameter keyword: The keyword to match
    /// - Returns: Array of app names that would be added
    func previewAppsForKeyword(_ keyword: String) -> [(name: String, path: String, alreadyExists: Bool)] {
        let matchingApps = findAppsMatchingKeyword(keyword)

        return matchingApps.map { appURL in
            let appName = appURL.deletingPathExtension().lastPathComponent
            let appPath = appURL.path
            let exists = databaseManager.appEntryExistsByPath(appPath)
            return (name: appName, path: appPath, alreadyExists: exists)
        }
    }
}
