//
//  PlexExtra.swift
//  VuaPhimBui
//
//  Created by Monster on 29/6/25.
//

import Foundation

struct PlexExtra: Codable {
    let metadatas: [ExtraMetadatas]
    
    enum CodingKeys: String, CodingKey {
        case metadatas = "Metadata"
    }
    
    struct ExtraMetadatas: Codable {
        let medias: [PlexMedia]
        
        enum CodingKeys: String, CodingKey {
            case medias = "Media"
        }
    }
}
