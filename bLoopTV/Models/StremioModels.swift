//
//  StremioModels.swift
//  bLoopTV
//

import Foundation

struct StremioManifest: Decodable, Hashable {
    let id: String
    let name: String
    let catalogs: [StremioCatalogDescriptor]

    private enum CodingKeys: String, CodingKey {
        case id, name, catalogs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Một số addon (subtitle, stream-only...) không khai báo catalogs
        catalogs = try container.decodeIfPresent([StremioCatalogDescriptor].self, forKey: .catalogs) ?? []
    }
}

struct StremioCatalogDescriptor: Decodable, Hashable {
    let type: String
    let id: String
    let name: String?
    let extra: [StremioCatalogExtra]?

    /// Catalog này có hỗ trợ tham số "search" không (dùng để dò addon nào tìm kiếm được).
    var supportsSearch: Bool {
        extra?.contains { $0.name == "search" } == true
    }
}

struct StremioCatalogExtra: Decodable, Hashable {
    let name: String
    let isRequired: Bool?
}

struct StremioMeta: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
}

struct StremioCatalogResponse: Decodable {
    let metas: [StremioMeta]
}

struct StremioStream: Decodable {
    let url: String?
    let title: String?
    let name: String?
    let subtitles: [StremioStreamSubtitle]?
}

struct StremioStreamSubtitle: Decodable {
    let id: String?
    let url: String
    let lang: String?
}

struct StremioStreamResponse: Decodable {
    let streams: [StremioStream]
}

struct StremioCatalogRow: Identifiable {
    let id: String
    let title: String
    let items: [StremioMeta]
}

// MARK: - Meta chi tiết (dùng cho trang detail: banner, logo, mô tả, thể loại)

struct StremioMetaDetailResponse: Decodable {
    let meta: StremioMetaDetail?
}

struct StremioMetaDetail: Decodable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let genres: [String]?
    let releaseInfo: String?
    let imdbRating: String?
    /// Danh sách tập (chỉ có với type "series") — dùng để dựng bộ chọn Mùa/Tập.
    let videos: [StremioVideoEntry]?
}

struct StremioVideoEntry: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let season: Int?
    let episode: Int?
    let thumbnail: String?
    let overview: String?
}

// MARK: - Stremio Account (api.strem.io)

struct StremioAPIErrorPayload: Decodable {
    let code: Int
    let message: String
}

struct StremioLoginResponse: Decodable {
    let result: StremioLoginResult?
    let error: StremioAPIErrorPayload?
}

struct StremioLoginResult: Decodable {
    let authKey: String
    let user: StremioAccountUser?
}

struct StremioAccountUser: Decodable {
    let email: String?
}

struct StremioAddonCollectionResponse: Decodable {
    let result: StremioAddonCollectionResult?
    let error: StremioAPIErrorPayload?
}

struct StremioAddonCollectionResult: Decodable {
    let addons: [StremioInstalledAddon]
}

struct StremioInstalledAddon: Decodable, Identifiable, Hashable {
    var id: String { transportUrl }
    let transportUrl: String
    let manifest: StremioManifest
}

// MARK: - Stremio Library (Continue Watching)

struct StremioDatastoreGetResponse: Decodable {
    let result: [StremioLibraryItem]?
    let error: StremioAPIErrorPayload?
}

struct StremioLibraryItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let poster: String?
    let background: String?
    let removed: Bool?
    let temp: Bool?
    let ctime: String?
    let state: StremioLibraryItemState?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case ctime = "_ctime"
        case name, type, poster, background, removed, temp, state
    }
}

struct StremioLibraryItemState: Decodable, Hashable {
    let lastWatched: String?
    let timeOffset: Double?
    let duration: Double?
    let videoId: String?

    enum CodingKeys: String, CodingKey {
        case lastWatched, timeOffset, duration
        case videoId = "video_id"
    }
}

// MARK: - Playback context để lưu tiến độ xem (Continue Watching) khi phát nội dung từ Stremio

struct StremioPlaybackContext: Hashable {
    /// id dùng làm "_id" trong library (id series/phim, KHÔNG kèm season/episode)
    let libraryItemId: String
    /// id đầy đủ dùng để lấy stream/resume (có thể kèm season/episode, vd "tt123:1:2")
    let videoId: String
    let type: String
    let name: String
    let poster: String?
    let existingCtime: String?
    let existingTemp: Bool?
    let existingRemoved: Bool?
}
