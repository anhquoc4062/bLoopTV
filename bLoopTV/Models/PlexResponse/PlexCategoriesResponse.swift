//
//  PlexCategoriesResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 4/7/25.
//

struct PlexCategoriesResponse: Codable {
    let mediaContainer: MediaContainer
    
    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
    
    struct MediaContainer: Codable {
        let directory: [PlexCategory]

        enum CodingKeys: String, CodingKey {
            case directory = "Directory"
        }
    }
}
