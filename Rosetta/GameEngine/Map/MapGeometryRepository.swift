#if DEBUG
import Foundation

protocol MapGeometryRepository {
    func save(_ configuration: MapGeometryConfiguration) throws
    func load() throws -> MapGeometryConfiguration?
    func deleteSavedConfiguration() throws
}

enum MapGeometryRepositoryError: LocalizedError {
    case unsupportedSchema(Int)
    case structurallyInvalid(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version): "Unsupported map schema version \(version)"
        case let .structurallyInvalid(message): message
        }
    }
}

final class LocalMapGeometryRepository: MapGeometryRepository {
    let fileURL: URL
    private let fileManager: FileManager
    private let validator = MapGeometryValidator()

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let baseURL: URL
        if let directoryURL {
            baseURL = directoryURL
        } else {
            guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            baseURL = documents.appendingPathComponent("MapDebug", isDirectory: true)
        }
        fileURL = baseURL.appendingPathComponent("DrawingSpaceMapGeometry.debug.json")
    }

    func save(_ configuration: MapGeometryConfiguration) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> MapGeometryConfiguration? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let configuration = try JSONDecoder().decode(MapGeometryConfiguration.self, from: data)
        guard configuration.schemaVersion == MapGeometryConfiguration.currentSchemaVersion else {
            throw MapGeometryRepositoryError.unsupportedSchema(configuration.schemaVersion)
        }
        if let issue = validator.structuralIssues(in: configuration).first {
            throw MapGeometryRepositoryError.structurallyInvalid(issue.message)
        }
        return configuration
    }

    func deleteSavedConfiguration() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
#endif
