//
//  StremioAccountAPI.swift
//  bLoopTV
//

import Foundation
import Combine

enum StremioAccountAPIError: LocalizedError {
    case invalidURL
    case server(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL không hợp lệ"
        case .server(let message):
            return message
        case .decodingError:
            return "Không đọc được phản hồi từ Stremio"
        }
    }
}

final class StremioAccountAPI: ObservableObject {
    static let shared = StremioAccountAPI()

    private let baseURL = "https://api.strem.io/api"
    private let authKeyDefaultsKey = "stremioAuthKey"
    private let accountEmailDefaultsKey = "stremioAccountEmail"

    @Published var authKey: String? {
        didSet { UserDefaults.standard.set(authKey, forKey: authKeyDefaultsKey) }
    }

    @Published var accountEmail: String? {
        didSet { UserDefaults.standard.set(accountEmail, forKey: accountEmailDefaultsKey) }
    }

    private init() {
        authKey = UserDefaults.standard.string(forKey: authKeyDefaultsKey)
        accountEmail = UserDefaults.standard.string(forKey: accountEmailDefaultsKey)
    }

    func logout() {
        authKey = nil
        accountEmail = nil
    }

    func login(email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/login") else {
            throw StremioAccountAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoded: StremioLoginResponse
        do {
            decoded = try JSONDecoder().decode(StremioLoginResponse.self, from: data)
        } catch {
            throw StremioAccountAPIError.decodingError(error)
        }

        if let error = decoded.error {
            throw StremioAccountAPIError.server(error.message)
        }

        guard let result = decoded.result else {
            throw StremioAccountAPIError.server("Không nhận được authKey")
        }

        authKey = result.authKey
        accountEmail = result.user?.email ?? email
        return result.authKey
    }

    func fetchAddonCollection(authKey: String) async throws -> [StremioInstalledAddon] {
        guard let url = URL(string: "\(baseURL)/addonCollectionGet") else {
            throw StremioAccountAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["authKey": authKey, "update": true])

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoded: StremioAddonCollectionResponse
        do {
            decoded = try JSONDecoder().decode(StremioAddonCollectionResponse.self, from: data)
        } catch {
            throw StremioAccountAPIError.decodingError(error)
        }

        if let error = decoded.error {
            throw StremioAccountAPIError.server(error.message)
        }

        return decoded.result?.addons ?? []
    }

    func fetchLibraryItems(authKey: String) async throws -> [StremioLibraryItem] {
        guard let url = URL(string: "\(baseURL)/datastoreGet") else {
            throw StremioAccountAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "authKey": authKey,
            "collection": "libraryItem",
            "ids": [],
            "all": true
        ])

        let (data, _) = try await URLSession.shared.data(for: request)

        if let raw = String(data: data, encoding: .utf8) {
            print("[Stremio] datastoreGet raw response (2000 ký tự đầu): \(raw.prefix(2000))")
        }

        let decoded: StremioDatastoreGetResponse
        do {
            decoded = try JSONDecoder().decode(StremioDatastoreGetResponse.self, from: data)
        } catch {
            throw StremioAccountAPIError.decodingError(error)
        }

        if let error = decoded.error {
            throw StremioAccountAPIError.server(error.message)
        }

        return decoded.result ?? []
    }

    /// Lưu tiến độ xem lên account Stremio (datastorePut) để đồng bộ Continue Watching.
    /// Giữ nguyên các field housekeeping (_ctime/temp/removed) của item cũ nếu có, tránh ghi đè sai.
    func updateLibraryItem(authKey: String, context: StremioPlaybackContext, timeOffsetMs: Int, durationMs: Int) async {
        guard let url = URL(string: "\(baseURL)/datastorePut") else { return }

        let nowISO = ISO8601DateFormatter().string(from: Date())

        let stateDict: [String: Any] = [
            "lastWatched": nowISO,
            "timeWatched": timeOffsetMs,
            "timeOffset": timeOffsetMs,
            "overallTimeWatched": timeOffsetMs,
            "timesWatched": 0,
            "flaggedWatched": 0,
            "duration": durationMs,
            "video_id": context.videoId,
            "watched": "",
            "noNotif": false,
            "season": 0,
            "episode": 0
        ]

        let itemDict: [String: Any] = [
            "_id": context.libraryItemId,
            "name": context.name,
            "type": context.type,
            "poster": context.poster ?? "",
            "removed": context.existingRemoved ?? false,
            "temp": context.existingTemp ?? true,
            "_ctime": context.existingCtime ?? nowISO,
            "_mtime": nowISO,
            "state": stateDict
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "authKey": authKey,
            "collection": "libraryItem",
            "changes": [itemDict]
        ])

        _ = try? await URLSession.shared.data(for: request)
        print("[Stremio] Đã lưu tiến độ xem \(context.libraryItemId): \(timeOffsetMs)ms / \(durationMs)ms")
    }

    /// Đổi transportUrl (thường kết thúc bằng "/manifest.json") thành base URL dùng cho StremioAPI (catalog/stream).
    static func baseURL(fromTransportUrl transportUrl: String) -> String {
        if transportUrl.hasSuffix("/manifest.json") {
            return String(transportUrl.dropLast("/manifest.json".count))
        }
        return transportUrl
    }
}
