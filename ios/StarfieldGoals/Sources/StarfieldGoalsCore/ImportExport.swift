import Foundation

public enum WebAppStateError: Error, Equatable {
    case invalidBackupEnvelope
    case unsupportedVersion(Int)
}

public struct WebBackupPayloadV1: Codable, Equatable, Sendable {
    public static let appId = "starfield-goals"
    public static let schemaVersion = 1

    public var app: String
    public var schemaVersion: Int
    public var exportedAt: String
    public var state: WebAppStateV1

    public init(
        app: String = Self.appId,
        schemaVersion: Int = Self.schemaVersion,
        exportedAt: String,
        state: WebAppStateV1
    ) {
        self.app = app
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.state = state
    }

    public static func decode(_ data: Data) throws -> WebBackupPayloadV1 {
        let payload = try JSONDecoder().decode(WebBackupPayloadV1.self, from: data)
        guard payload.app == appId else {
            throw WebAppStateError.invalidBackupEnvelope
        }
        guard payload.schemaVersion == schemaVersion else {
            throw WebAppStateError.unsupportedVersion(payload.schemaVersion)
        }
        guard payload.state.version == 1 else {
            throw WebAppStateError.unsupportedVersion(payload.state.version)
        }
        return payload
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

public struct WebAppStateV1: Codable, Equatable, Sendable {
    public var version: Int
    public var goals: [GoalSnapshot]
    public var routines: [RoutineSnapshot]
    public var tasks: [OneOffTaskSnapshot]
    public var checkIns: [CheckInSnapshot]
    public var lastReminderDate: ISODate?

    public init(
        version: Int,
        goals: [GoalSnapshot],
        routines: [RoutineSnapshot],
        tasks: [OneOffTaskSnapshot],
        checkIns: [CheckInSnapshot],
        lastReminderDate: ISODate?
    ) {
        self.version = version
        self.goals = goals
        self.routines = routines
        self.tasks = tasks
        self.checkIns = checkIns
        self.lastReminderDate = lastReminderDate
    }

    public static func decode(_ data: Data) throws -> WebAppStateV1 {
        let decoder = JSONDecoder()
        let state = try decoder.decode(WebAppStateV1.self, from: data)
        guard state.version == 1 else {
            throw WebAppStateError.unsupportedVersion(state.version)
        }
        return WebAppStateV1(
            version: state.version,
            goals: state.goals,
            routines: state.routines,
            tasks: state.tasks,
            checkIns: state.checkIns,
            lastReminderDate: state.lastReminderDate
        )
    }

    public static func decodeCompatible(_ data: Data) throws -> WebAppStateV1 {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["state"] != nil || object["app"] != nil || object["schemaVersion"] != nil {
            return try WebBackupPayloadV1.decode(data).state
        }
        return try decode(data)
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public func backupData(exportedAt: String) throws -> Data {
        try WebBackupPayloadV1(exportedAt: exportedAt, state: self).encode()
    }
}
