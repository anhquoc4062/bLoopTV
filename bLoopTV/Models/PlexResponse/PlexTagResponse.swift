//
//  PlexTagResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 5/8/25.
//

struct PlexTagResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadatas: [PlexTag]

        enum CodingKeys: String, CodingKey {
            case metadatas = "Metadata"
        }
    }
}
