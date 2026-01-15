import Foundation

enum AppEntryType: String, Codable {
    case application = "application"
    case script = "script"
}

struct AppEntry: Identifiable, Codable {
    var id: Int64?
    var name: String
    var path: String
    var type: AppEntryType
    var createdAt: Date

    init(id: Int64? = nil, name: String, path: String, type: AppEntryType, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.createdAt = createdAt
    }
}
