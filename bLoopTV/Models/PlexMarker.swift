//
//  PlexMarker.swift
//  VuaPhimBui
//
//  Created by Monster on 2/7/25.
//

struct PlexMarker: Identifiable, Codable {
    let id: Int
    let type: String
    let startTimeOffset: Int
    let endTimeOffset: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case startTimeOffset
        case endTimeOffset
    }
}
