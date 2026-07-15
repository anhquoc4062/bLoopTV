//
//  PlexOnDeck.swift
//  VuaPhimBui
//
//  Created by Monster on 3/6/25.
//

class PlexOnDeck: Codable {
    let metadata: PlexMetaDataDetail

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
    }
}
