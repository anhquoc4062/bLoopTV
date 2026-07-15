//
//  PlexTag.swift
//  VuaPhimBui
//
//  Created by Monster on 5/8/25.
//

struct PlexTag: Identifiable, Codable {
    let id: String
    let key: String
    let title: String
    var tagName: String?
    let type: String
    let thumb: String
    
    enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case key
        case title
        case type
        case thumb
    }
}
