//
//  PlexWatchlistResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 20/6/25.
//

struct PlexWatchlistResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadatas: [PlexMetaData]

        enum CodingKeys: String, CodingKey {
            case metadatas = "Metadata"
        }
    }
}
