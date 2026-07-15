//
//  PlexDirectoryCollection.swift
//  VuaPhimBui
//
//  Created by Monster on 6/7/25.
//

struct PlexDirectoryCollection: Identifiable, Codable {
    let id: String
    let key: String
    let title: String
    let type: String
    var directories: [PlexDirectory]
    
    enum CodingKeys: String, CodingKey {
        case id
        case key = "key"
        case title = "title"
        case type = "type"
        case directories = "Directory"
    }
}
