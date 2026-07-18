//
//  TMDBModels.swift
//  bLoopTV
//
//  Model tối thiểu cho việc làm giàu metadata Stremio bằng TMDB (title/summary tiếng Việt, rating, cast,
//  gợi ý). Chỉ khai báo đúng field cần dùng, bỏ qua phần còn lại.
//

import Foundation

enum TMDBImage {
    static let posterBase = "https://image.tmdb.org/t/p/w500"
    static let profileBase = "https://image.tmdb.org/t/p/w185"
}

/// 1 phim/series ở dạng rút gọn — dùng cho kết quả /find và danh sách recommendations.
struct TMDBTitle: Decodable, Identifiable {
    let id: Int
    let title: String?   // phim lẻ
    let name: String?    // series
    let overview: String?
    let posterPath: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
    }

    var displayName: String { title ?? name ?? "" }
    var posterURL: String? { posterPath.map { TMDBImage.posterBase + $0 } }
}

struct TMDBFindResponse: Decodable {
    let movieResults: [TMDBTitle]
    let tvResults: [TMDBTitle]

    enum CodingKeys: String, CodingKey {
        case movieResults = "movie_results"
        case tvResults = "tv_results"
    }
}

struct TMDBCastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }

    var profileURL: String? { profilePath.map { TMDBImage.profileBase + $0 } }
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]
}

struct TMDBPagedTitles: Decodable {
    let results: [TMDBTitle]
}

/// /movie/{id} hoặc /tv/{id} với append_to_response=credits,recommendations.
struct TMDBDetail: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let voteAverage: Double?
    let credits: TMDBCredits?
    let recommendations: TMDBPagedTitles?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, credits, recommendations
        case voteAverage = "vote_average"
    }

    var displayName: String { title ?? name ?? "" }
}

struct TMDBExternalIds: Decodable {
    let imdbId: String?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
    }
}
