//
//  PlexFilmography.swift
//  VuaPhimBui
//
//  Created by Monster on 3/7/25.
//

import Foundation

struct FilmographyCredit: Identifiable, Codable {
    let id = UUID()
    let role: String?
    let metadata: PlexMetaData
    
    enum CodingKeys: String, CodingKey {
        case role
        case metadata = "Metadata"
    }
}

struct FilmographyGroup: Identifiable, Codable {
    let id: String
    let title: String
    let credits: [FilmographyCredit]
    
    enum CodingKeys: String, CodingKey {
        case id = "type"
        case title
        case credits = "Credit"
    }
}
