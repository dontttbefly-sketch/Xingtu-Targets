import Foundation

public enum BackupServiceError: LocalizedError, Equatable {
    case invalidEnvelope
    case unsupportedApp(String)
    case unsupportedSchema(Int)
    case unsupportedStateVersion(Int)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEnvelope:
            return "备份文件格式不正确。"
        case let .unsupportedApp(app):
            return "这不是 Starfield Goals 备份文件：\(app)。"
        case let .unsupportedSchema(schema):
            return "暂不支持这个备份版本：\(schema)。"
        case let .unsupportedStateVersion(version):
            return "暂不支持这个数据版本：\(version)。"
        case let .decodingFailed(message):
            return "读取备份失败：\(message)"
        }
    }
}

public final class BackupService {
    private struct BackupEnvelope: Codable {
        var app: String
        var schemaVersion: Int
        var exportedAt: String
        var state: AppState
    }

    public init() {}

    public func exportBackup(state: AppState, exportedAt: Date = Date()) throws -> Data {
        let envelope = BackupEnvelope(
            app: "starfield-goals",
            schemaVersion: 1,
            exportedAt: DateCoding.timestamp(from: exportedAt),
            state: state
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    public func importBackup(data: Data) throws -> AppState {
        let decoder = JSONDecoder()
        let envelope: BackupEnvelope

        do {
            envelope = try decoder.decode(BackupEnvelope.self, from: data)
        } catch {
            throw BackupServiceError.decodingFailed(error.localizedDescription)
        }

        guard envelope.app == "starfield-goals" else {
            throw BackupServiceError.unsupportedApp(envelope.app)
        }
        guard envelope.schemaVersion == 1 else {
            throw BackupServiceError.unsupportedSchema(envelope.schemaVersion)
        }
        guard envelope.state.version == 1 else {
            throw BackupServiceError.unsupportedStateVersion(envelope.state.version)
        }

        return envelope.state
    }
}
