//
//  TMDBAPI.swift
//  bLoopTV
//
//  Gọi TMDB để làm giàu metadata cho nội dung Stremio: title/summary tiếng Việt, rating, dàn diễn viên,
//  và gợi ý (recommendations). Item Stremio dùng IMDb id (tt...), nên phải /find để đổi sang TMDB id trước.
//

import Foundation

final class TMDBAPI {
    static let shared = TMDBAPI()
    private init() {}

    // Key đọc từ Secrets.plist (gitignore) — xem bLoopTV/Secrets.example.plist. Không có key thì phần làm
    // giàu tự bỏ qua, trang detail Stremio vẫn chạy bình thường như cũ.
    private var apiKey: String { AppSecrets.tmdbAPIKey }

    private let language = "vi-VN"
    private let host = "https://api.themoviedb.org/3"

    var isConfigured: Bool { !apiKey.isEmpty }

    private func makeURL(_ path: String, extraQuery: [URLQueryItem] = []) -> URL? {
        var comps = URLComponents(string: host + path)
        comps?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: language)
        ] + extraQuery
        return comps?.url
    }

    private func get<T: Decodable>(_ url: URL?) async -> T? {
        guard let url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[TMDB] HTTP \(http.statusCode) cho \(url.path)")
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[TMDB] lỗi \(url.path): \(error)")
            return nil
        }
    }

    /// Đổi IMDb id (tt...) sang bản ghi TMDB tương ứng (theo đúng loại movie/series).
    func find(imdbId: String, isMovie: Bool) async -> TMDBTitle? {
        guard isConfigured else { return nil }
        let url = makeURL("/find/\(imdbId)", extraQuery: [
            URLQueryItem(name: "external_source", value: "imdb_id")
        ])
        let res: TMDBFindResponse? = await get(url)
        return isMovie ? res?.movieResults.first : res?.tvResults.first
    }

    /// Chi tiết đầy đủ (title/overview vi-VN, rating, cast, recommendations) trong 1 request nhờ
    /// append_to_response.
    func detail(tmdbId: Int, isMovie: Bool) async -> TMDBDetail? {
        guard isConfigured else { return nil }
        let kind = isMovie ? "movie" : "tv"
        let url = makeURL("/\(kind)/\(tmdbId)", extraQuery: [
            URLQueryItem(name: "append_to_response", value: "credits,recommendations")
        ])
        return await get(url)
    }

    /// Lấy IMDb id của 1 item gợi ý (chỉ gọi khi người dùng bấm vào thẻ) để mở đúng trang detail Stremio.
    func imdbId(tmdbId: Int, isMovie: Bool) async -> String? {
        guard isConfigured else { return nil }
        let kind = isMovie ? "movie" : "tv"
        let ids: TMDBExternalIds? = await get(makeURL("/\(kind)/\(tmdbId)/external_ids"))
        let imdb = ids?.imdbId
        return (imdb?.isEmpty == false) ? imdb : nil
    }
}

extension TMDBCastMember {
    /// Map sang PlexActor để dùng lại ActorSectionView/ActorCardView y như bên Plex.
    var asPlexActor: PlexActor {
        PlexActor(
            id: "tmdb-\(id)",
            tagKey: "",
            role: character ?? "",
            tag: name,
            thumbnail: profileURL ?? ""
        )
    }
}
