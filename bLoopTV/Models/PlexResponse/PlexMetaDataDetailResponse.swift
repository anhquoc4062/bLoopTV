//
//  PlexMetaDataDetailResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//

struct PlexMetaDataDetailResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadata: [PlexMetaDataDetail]

        enum CodingKeys: String, CodingKey {
            case metadata = "Metadata"
        }
    }
}
