//
//  PlexDiscoverMetadataResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 6/7/25.
//

struct PlexDirectoryResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let directories: [PlexDirectory]

        enum CodingKeys: String, CodingKey {
            case directories = "Directory"
        }
    }
}
