import Foundation

public struct JournalSection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("journal", isDirectory: true) }

    public func day(_ date: Date) async throws -> BotFile {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let name = formatter.string(from: date) + ".md"
        return try await store.read(directoryURL.appendingPathComponent(name))
    }

    public var allDays: [BotFile] {
        get async throws { try await listMarkdownFiles(at: directoryURL, store: store) }
    }
}
