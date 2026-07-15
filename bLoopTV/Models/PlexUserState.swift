//
//  PlexUserState.swift
//  VuaPhimBui
//
//  Created by Monster on 22/6/25.
//

struct PlexUserState: Identifiable, Codable, Hashable {
    let id: String
    let watchlistedAt: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case watchlistedAt
    }
    
    init(
        id: String,
        watchlistedAt: Int,
    ) {
        self.id = id
        self.watchlistedAt = watchlistedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.watchlistedAt = try? container.decode(Int.self, forKey: .watchlistedAt)
        
    }
}
