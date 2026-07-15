//
//  PlexUserStateResponse.swift
//  VuaPhimBui
//
//  Created by Monster on 22/6/25.
//

struct PlexUserStateResponse: Codable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MediaContainer: Codable {
        let userState: [PlexUserState]

        enum CodingKeys: String, CodingKey {
            case userState = "UserState"
        }
    }
}
