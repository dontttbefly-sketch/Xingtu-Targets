import Foundation

public enum StoredStateStatus: Equatable, Sendable {
    case ok
    case empty
    case recovered
    case invalid
}

public struct LoadStoredStateResult: Equatable, Sendable {
    public var state: AppState
    public var status: StoredStateStatus
    public var message: String?

    public init(state: AppState, status: StoredStateStatus, message: String? = nil) {
        self.state = state
        self.status = status
        self.message = message
    }
}

public enum StorageError: LocalizedError, Equatable {
    case writeFailed(String)
    case readFailed(String)
    case invalidState(String)

    public var errorDescription: String? {
        switch self {
        case let .writeFailed(message):
            return "保存失败：\(message)"
        case let .readFailed(message):
            return "读取失败：\(message)"
        case let .invalidState(message):
            return "数据格式不正确：\(message)"
        }
    }
}

public final class StorageService {
    public let directoryURL: URL
    public let primaryURL: URL
    public let lastGoodURL: URL

    private let fileManager: FileManager

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.directoryURL = base.appendingPathComponent("StarfieldGoals", isDirectory: true)
        }

        primaryURL = self.directoryURL.appendingPathComponent("starfield-goals.json", isDirectory: false)
        lastGoodURL = self.directoryURL.appendingPathComponent("starfield-goals.last-good.json", isDirectory: false)
    }

    public func load() -> LoadStoredStateResult {
        let hasPrimary = fileManager.fileExists(atPath: primaryURL.path)
        let hasLastGood = fileManager.fileExists(atPath: lastGoodURL.path)

        if hasPrimary {
            switch decodeState(at: primaryURL) {
            case let .success(state):
                return LoadStoredStateResult(state: state, status: .ok)
            case let .failure(primaryError):
                if hasLastGood, case let .success(recovered) = decodeState(at: lastGoodURL) {
                    return LoadStoredStateResult(
                        state: recovered,
                        status: .recovered,
                        message: "主数据文件异常，已从 last-good 镜像恢复。\(primaryError.localizedDescription)"
                    )
                }

                return LoadStoredStateResult(
                    state: .empty,
                    status: .invalid,
                    message: "本地数据文件无法读取，已进入安全空状态。\(primaryError.localizedDescription)"
                )
            }
        }

        if hasLastGood, case let .success(recovered) = decodeState(at: lastGoodURL) {
            return LoadStoredStateResult(
                state: recovered,
                status: .recovered,
                message: "主数据文件缺失，已从 last-good 镜像恢复。"
            )
        }

        return LoadStoredStateResult(state: .empty, status: .empty)
    }

    public func save(_ state: AppState) -> Result<Date, StorageError> {
        do {
            guard state.version == 1 else {
                return .failure(.invalidState("暂不支持 version \(state.version)。"))
            }

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: primaryURL, options: [.atomic])
            try data.write(to: lastGoodURL, options: [.atomic])
            return .success(Date())
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    private func decodeState(at url: URL) -> Result<AppState, StorageError> {
        do {
            let data = try Data(contentsOf: url)
            let state = try Self.decodeStoredState(from: data)
            return .success(state)
        } catch let error as StorageError {
            return .failure(error)
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }

    public static func decodeStoredState(from data: Data) throws -> AppState {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StorageError.invalidState("根节点不是对象。")
        }
        guard let version = object["version"] as? Int else {
            throw StorageError.invalidState("缺少 version。")
        }
        guard version == 1 else {
            throw StorageError.invalidState("暂不支持 version \(version)。")
        }

        for key in ["goals", "routines", "tasks", "checkIns"] {
            if let value = object[key], !(value is [Any]) {
                throw StorageError.invalidState("\(key) 不是数组。")
            }
        }

        return try JSONDecoder().decode(AppState.self, from: data)
    }
}
