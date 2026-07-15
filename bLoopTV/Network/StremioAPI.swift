//
//  StremioAPI.swift
//  bLoopTV
//

import Foundation

enum StremioAPIError: Error {
    case invalidURL
    case decodingError(Error)
}

final class StremioAPI {
    static let shared = StremioAPI()
    private init() {}

    private let baseURLKey = "http://127.0.0.1:11470"

    var baseURLString: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    func fetchManifest(baseURL: String) async throws -> StremioManifest {
        guard let url = URL(string: normalize(baseURL) + "/manifest.json") else {
            throw StremioAPIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(StremioManifest.self, from: data)
        } catch {
            throw StremioAPIError.decodingError(error)
        }
    }

    func fetchCatalog(baseURL: String, type: String, id: String, searchQuery: String? = nil) async throws -> [StremioMeta] {
        var path = "\(normalize(baseURL))/catalog/\(type)/\(id)"
        if let searchQuery, !searchQuery.isEmpty {
            let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
            path += "/search=\(encoded)"
        }
        path += ".json"

        guard let url = URL(string: path) else {
            throw StremioAPIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(StremioCatalogResponse.self, from: data).metas
        } catch {
            throw StremioAPIError.decodingError(error)
        }
    }

    /// Lấy meta chi tiết (banner, logo, mô tả, thể loại...) — không phải addon nào cũng hỗ trợ endpoint này.
    func fetchMetaDetail(baseURL: String, type: String, id: String) async throws -> StremioMetaDetail? {
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(normalize(baseURL))/meta/\(type)/\(encodedId).json") else {
            throw StremioAPIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(StremioMetaDetailResponse.self, from: data).meta
        } catch {
            throw StremioAPIError.decodingError(error)
        }
    }

    func fetchStreams(baseURL: String, type: String, id: String) async throws -> [StremioStream] {
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(normalize(baseURL))/stream/\(type)/\(encodedId).json") else {
            throw StremioAPIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(StremioStreamResponse.self, from: data).streams
        } catch {
            throw StremioAPIError.decodingError(error)
        }
    }

    private func normalize(_ base: String) -> String {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }
}
