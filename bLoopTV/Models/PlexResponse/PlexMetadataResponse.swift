//
//  PlexMetadataResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 12/9/25.
//


struct PlexMetadataResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadata: [PlexMetaData]

        enum CodingKeys: String, CodingKey {
            case metadata = "Metadata"
        }
    }
}
