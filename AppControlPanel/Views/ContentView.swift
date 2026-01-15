import SwiftUI

struct ContentView: View {
    @StateObject private var appManager = AppManager.shared
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("App Control")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { appManager.loadEntries() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Refresh List")

                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .help("Add Entry")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // App List
            if appManager.appEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No apps added yet")
                        .foregroundColor(.secondary)
                    Text("Click + to add an app or script")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appManager.appEntries) { entry in
                            AppEntryRow(entry: entry, appManager: appManager)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)

                Spacer()

                Text("\(appManager.appEntries.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 350, height: 450)
        .sheet(isPresented: $showingAddSheet) {
            AddEntrySheet(appManager: appManager, isPresented: $showingAddSheet)
        }
    }
}

struct AppEntryRow: View {
    let entry: AppEntry
    @ObservedObject var appManager: AppManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(entry.type == .application ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: entry.type == .application ? "app.fill" : "terminal.fill")
                    .font(.title2)
                    .foregroundColor(entry.type == .application ? .blue : .orange)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(entry.type == .application ? "Application" : "Script")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if entry.type == .application && appManager.isAppRunning(entry) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: { appManager.openApp(entry) }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Open/Run")

                if entry.type == .application {
                    Button(action: { appManager.forceKillApp(entry) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Force Kill")
                }

                Button(action: { appManager.removeEntry(entry) }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.gray)
                    }
                .buttonStyle(.plain)
                .help("Remove")
            }
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color(NSColor.controlBackgroundColor))
        )
        .onTapGesture(count: 2) {
            appManager.openApp(entry)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

enum AddEntryMode: String, CaseIterable {
    case manual = "Manual"
    case keyword = "Keyword Search"
}

struct AddEntrySheet: View {
    @ObservedObject var appManager: AppManager
    @Binding var isPresented: Bool

    @State private var addMode: AddEntryMode = .manual
    @State private var entryType: AppEntryType = .application
    @State private var name = ""
    @State private var path = ""
    @State private var scriptContent = ""
    @State private var useScriptFile = false

    // Keyword search states
    @State private var keyword = ""
    @State private var previewApps: [(name: String, path: String, alreadyExists: Bool)] = []
    @State private var showingPreview = false
    @State private var addedCount = 0
    @State private var showingResult = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add New Entry")
                .font(.headline)

            Picker("Mode", selection: $addMode) {
                ForEach(AddEntryMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: addMode) { _ in
                // Reset states when switching modes
                showingPreview = false
                showingResult = false
            }

            if addMode == .manual {
                manualEntryView
            } else {
                keywordSearchView
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }

                Spacer()

                if addMode == .manual {
                    Button("Add") {
                        addEntry()
                    }
                    .disabled(name.isEmpty || (entryType == .application && path.isEmpty) || (entryType == .script && !useScriptFile && scriptContent.isEmpty) || (entryType == .script && useScriptFile && path.isEmpty))
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 450, height: addMode == .keyword && showingPreview ? 500 : 350)
        .animation(.easeInOut(duration: 0.2), value: showingPreview)
    }

    // MARK: - Manual Entry View

    private var manualEntryView: some View {
        VStack(spacing: 12) {
            Picker("Type", selection: $entryType) {
                Text("Application").tag(AppEntryType.application)
                Text("Script").tag(AppEntryType.script)
            }
            .pickerStyle(.segmented)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            if entryType == .application {
                HStack {
                    TextField("Application Path", text: $path)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        selectApplication()
                    }
                }
            } else {
                Toggle("Use script file", isOn: $useScriptFile)

                if useScriptFile {
                    HStack {
                        TextField("Script File Path", text: $path)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse") {
                            selectScriptFile()
                        }
                    }
                } else {
                    VStack(alignment: .leading) {
                        Text("Script Content:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $scriptContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Keyword Search View

    private var keywordSearchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for applications in /Applications folder that contain the keyword (case-insensitive).")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Enter keyword (e.g., 'chrome', 'code')", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        previewMatches()
                    }

                Button("Search") {
                    previewMatches()
                }
                .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Preview Results
            if showingPreview {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Matching Apps")
                            .font(.caption)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(previewApps.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if previewApps.isEmpty {
                        Text("No applications found matching '\(keyword)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(previewApps, id: \.path) { app in
                                    HStack {
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)

                                        Text(app.name)
                                            .font(.caption)
                                            .lineLimit(1)

                                        Spacer()

                                        if app.alreadyExists {
                                            Text("Already added")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(4)
                                        } else {
                                            Text("New")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxHeight: 150)

                        let newAppsCount = previewApps.filter { !$0.alreadyExists }.count

                        Button(action: addMatchingApps) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add \(newAppsCount) New App\(newAppsCount == 1 ? "" : "s")")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newAppsCount == 0)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }

            // Result Message
            if showingResult {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(addedCount) app\(addedCount == 1 ? "" : "s") added successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Actions

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK {
            if let url = panel.url {
                path = url.path
                if name.isEmpty {
                    name = url.deletingPathExtension().lastPathComponent
                }
            }
        }
    }

    private func selectScriptFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            if let url = panel.url {
                path = url.path
                if name.isEmpty {
                    name = url.deletingPathExtension().lastPathComponent
                }
            }
        }
    }

    private func addEntry() {
        let entryPath = entryType == .script && !useScriptFile ? scriptContent : path
        let entry = AppEntry(name: name, path: entryPath, type: entryType)
        appManager.addEntry(entry)
        isPresented = false
    }

    private func previewMatches() {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmedKeyword.isEmpty else { return }

        previewApps = appManager.previewAppsForKeyword(trimmedKeyword)
        showingPreview = true
        showingResult = false
    }

    private func addMatchingApps() {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmedKeyword.isEmpty else { return }

        addedCount = appManager.addAppsMatchingKeyword(trimmedKeyword)
        showingResult = true

        // Update preview to reflect changes
        previewApps = appManager.previewAppsForKeyword(trimmedKeyword)

        // Auto-hide result after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingResult = false
        }
    }
}

#Preview {
    ContentView()
}
