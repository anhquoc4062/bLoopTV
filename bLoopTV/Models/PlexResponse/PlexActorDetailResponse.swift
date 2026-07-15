//
//  PlexActorDetailResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 3/7/25.
//

struct PlexActorDetailResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let metadata: [PlexActorDetail]

        enum CodingKeys: String, CodingKey {
            case metadata = "Metadata"
        }
    }
}
