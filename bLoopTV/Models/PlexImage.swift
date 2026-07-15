//
//  PlexImage.swift
//  VuaPhimBui
//
//  Created by Monster on 22/6/25.
//

struct PlexImage: Codable, Hashable {
    let type: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
    }
}
