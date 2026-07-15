//
//  PlexCategory.swift
//  VuaPhimBui
//
//  Created by Monster on 4/7/25.
//
import Foundation

struct PlexCategory: Identifiable, Codable {
    let id: Int
    let key: String
    let thumb: String
    let title: String
    let type: String

    // Custom decoding to extract genre ID from `key`
    enum CodingKeys: String, CodingKey {
        case key, thumb, title, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        thumb = try container.decode(String.self, forKey: .thumb)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)

        // Extract genre ID from the key string
        if let idString = key.components(separatedBy: "genre=").last,
           let parsedID = Int(idString) {
            id = parsedID
        } else {
            throw DecodingError.dataCorruptedError(forKey: .key, in: container, debugDescription: "Invalid genre ID in key")
        }
    }
}
