//
//  PlexGenre.swift
//  VuaPhimBui
//
//  Created by Monster on 29/5/25.
//
import Foundation

struct PlexGenre: Codable, Hashable {
    let id: Int?
    let filter: String?
    let tag: String
    
    enum CodingKeys: CodingKey {
        case id
        case filter
        case tag
    }
    
    init(
        id: Int,
        filter: String,
        tag: String
    ) {
        self.id = id
        self.filter = filter
        self.tag = tag
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let id = try? container.decode(Int.self, forKey: .id) {
            self.id = id
        } else {
            self.id = nil
        }
        
        if let filter = try? container.decode(String.self, forKey: .filter) {
            self.filter = filter
        } else {
            self.filter = nil
        }
        self.tag = try container.decode(String.self, forKey: .tag)
        
    }
}
