//
//  PlexLibraryResponse.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//

struct PlexLibraryResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let directory: [PlexLibrary]

        enum CodingKeys: String, CodingKey {
            case directory = "Directory"
        }
    }
}
