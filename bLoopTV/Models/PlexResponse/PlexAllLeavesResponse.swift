//
//  PlexAllLeavesResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 13/6/25.
//

struct PlexAllLeavesResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadatas: [PlexMetaDataDetail]?

        enum CodingKeys: String, CodingKey {
            case metadatas = "Metadata"
        }
    }
}
