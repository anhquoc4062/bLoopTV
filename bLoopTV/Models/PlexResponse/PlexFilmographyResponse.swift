//
//  PlexFilmographyResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 3/7/25.
//

struct PlexFilmographyResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let creditGroup: [FilmographyGroup]?

        enum CodingKeys: String, CodingKey {
            case creditGroup = "CreditGroup"
        }
    }
}
