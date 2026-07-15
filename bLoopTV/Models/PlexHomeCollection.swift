//
//  PlexHomeCollection.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//

struct PlexHomeCollection: Identifiable, Codable {
    let id: String
    let key: String
    let title: String
    let type: String
    var metadatas: [PlexMetaData]?
    
    enum CodingKeys: String, CodingKey {
        case id = "hubIdentifier"
        case key = "key"
        case title = "title"
        case type = "type"
        case metadatas = "Metadata"
    }
}

