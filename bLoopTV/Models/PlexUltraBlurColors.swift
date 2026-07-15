//
//  PlexUltraBlurColors.swift
//  VuaPhimBui
//
//  Created by Monster on 8/6/25.
//

struct PlexUltraBlurColors: Codable, Hashable {
    let topLeft: String
    let topRight: String
    let bottomRight: String
    let bottomLeft: String

    enum CodingKeys: String, CodingKey {
        case topLeft
        case topRight
        case bottomRight
        case bottomLeft
    }
}
