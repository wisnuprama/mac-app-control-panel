import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        // Get the application support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("AppControlPanel")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        dbPath = appDirectory.appendingPathComponent("app_data.sqlite").path
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func createTables() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS app_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                path TEXT NOT NULL,
                type TEXT NOT NULL,
                created_at REAL NOT NULL
            );
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error creating table: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - CRUD Operations

    func insertAppEntry(_ entry: AppEntry) -> Int64? {
        let insertSQL = "INSERT INTO app_entries (name, path, type, created_at) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (entry.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (entry.path as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (entry.type.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 4, entry.createdAt.timeIntervalSince1970)

            if sqlite3_step(statement) == SQLITE_DONE {
                let rowId = sqlite3_last_insert_rowid(db)
                sqlite3_finalize(statement)
                return rowId
            }
        }

        print("Error inserting entry: \(String(cString: sqlite3_errmsg(db)))")
        sqlite3_finalize(statement)
        return nil
    }

    func getAllAppEntries() -> [AppEntry] {
        var entries: [AppEntry] = []
        let querySQL = "SELECT id, name, path, type, created_at FROM app_entries ORDER BY created_at DESC;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                let name = String(cString: sqlite3_column_text(statement, 1))
                let path = String(cString: sqlite3_column_text(statement, 2))
                let typeString = String(cString: sqlite3_column_text(statement, 3))
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))

                let type = AppEntryType(rawValue: typeString) ?? .application
                let entry = AppEntry(id: id, name: name, path: path, type: type, createdAt: createdAt)
                entries.append(entry)
            }
        }

        sqlite3_finalize(statement)
        return entries
    }

    func deleteAppEntry(id: Int64) -> Bool {
        let deleteSQL = "DELETE FROM app_entries WHERE id = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, id)

            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }

        print("Error deleting entry: \(String(cString: sqlite3_errmsg(db)))")
        sqlite3_finalize(statement)
        return false
    }

    func updateAppEntry(_ entry: AppEntry) -> Bool {
        guard let id = entry.id else { return false }

        let updateSQL = "UPDATE app_entries SET name = ?, path = ?, type = ? WHERE id = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (entry.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (entry.path as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (entry.type.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(statement, 4, id)

            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }

        print("Error updating entry: \(String(cString: sqlite3_errmsg(db)))")
        sqlite3_finalize(statement)
        return false
    }

    func appEntryExistsByPath(_ path: String) -> Bool {
        let querySQL = "SELECT COUNT(*) FROM app_entries WHERE path = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                sqlite3_finalize(statement)
                return count > 0
            }
        }

        sqlite3_finalize(statement)
        return false
    }
}
