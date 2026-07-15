//
//  PlexSection.swift
//  Media App For Plex
//
//  Created by Monster on 24/5/25.
//

struct PlexLibrary: Identifiable, Codable {
    let id: String
    let title: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case id = "key"
        case title = "title"
        case type = "type"
    }
}
