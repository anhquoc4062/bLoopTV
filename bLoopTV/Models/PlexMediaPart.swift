//
//  PlexMediaPart.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//

struct PlexMediaPart: Identifiable, Codable {
    let id: Int
    let url: String
    let duration: Int
    let streams: [PlexMediaPartStream]
    let accessible: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case url = "key"
        case duration
        case streams = "Stream"
        case accessible
    }
}
