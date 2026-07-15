//
//  PlexActor.swift
//  VuaPhimBui
//
//  Created by Monster on 8/6/25.
//

import Foundation

struct PlexActor: Identifiable, Codable, Hashable {
    let id: String
    let tagKey: String
    let role: String?
    let tag: String
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagKey
        case role
        case tag
        case thumbnail = "thumb"
    }
    
    init(
        id: String,
        tagKey: String,
        role: String,
        tag: String,
        thumbnail: String
    ) {
        self.id = id
        self.tagKey = tagKey
        self.role = role
        self.tag = tag
        self.thumbnail = thumbnail
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // self.id = try container.decode(Int.self, forKey: .id)
        if let id = try? container.decode(Int.self, forKey: .id) {
            self.id = String(id)
        } else {
            if let id = try? container.decode(String.self, forKey: .id) {
                self.id = id
            } else {
                self.id = UUID().uuidString
            }
        }
        self.tagKey = try container.decode(String.self, forKey: .tagKey)
        self.role = try? container.decode(String.self, forKey: .role)
        self.tag = try container.decode(String.self, forKey: .tag)
        
        if let thumbnail = try? container.decode(String.self, forKey: .thumbnail) {
            self.thumbnail = thumbnail
        } else {
            self.thumbnail = nil
        }
        
    }
}
