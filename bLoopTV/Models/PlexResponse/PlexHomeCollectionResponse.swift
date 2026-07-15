//
//  Untitled.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//

struct PlexHomeCollectionResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let hub: [PlexHomeCollection]?

        enum CodingKeys: String, CodingKey {
            case hub = "Hub"
        }
    }
}
