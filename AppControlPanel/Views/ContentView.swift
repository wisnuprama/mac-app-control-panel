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

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
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

struct AddEntrySheet: View {
    @ObservedObject var appManager: AppManager
    @Binding var isPresented: Bool

    @State private var entryType: AppEntryType = .application
    @State private var name = ""
    @State private var path = ""
    @State private var scriptContent = ""
    @State private var useScriptFile = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add New Entry")
                .font(.headline)

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

            HStack {
                Button("Cancel") {
                    isPresented = false
                }

                Spacer()

                Button("Add") {
                    addEntry()
                }
                .disabled(name.isEmpty || (entryType == .application && path.isEmpty) || (entryType == .script && !useScriptFile && scriptContent.isEmpty) || (entryType == .script && useScriptFile && path.isEmpty))
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

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
}

#Preview {
    ContentView()
}
