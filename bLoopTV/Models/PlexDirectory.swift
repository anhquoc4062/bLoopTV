//
//  PlexDirectory.swift
//  VuaPhimBui
//
//  Created by Monster on 11/6/25.
//

struct PlexDirectory: Identifiable, Codable {
    let id: String
    let key: String
    let title: String
    let type: String
    let thumb: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case metadataId
        case key = "key"
        case title = "title"
        case type = "type"
        case thumb = "thumb"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Thử decode từ "id", nếu nil thì decode từ "metadataId"
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else if let metadataIdValue = try? container.decode(String.self, forKey: .metadataId) {
            id = metadataIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                .init(codingPath: decoder.codingPath, debugDescription: "Neither id nor metadataId found")
            )
        }
        
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        thumb = try? container.decode(String.self, forKey: .thumb)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(thumb, forKey: .thumb)
    }
}
