//
//  PlexSearchResult.swift
//  VuaPhimBui
//
//  Created by Monster on 11/6/25.
//
import Foundation

struct PlexSearchItem: Codable, Identifiable {
    let score: Double
    let metadata: PlexMetaData?
    let directory: PlexDirectory?
    let isExternal: Bool
    
    var id: String {
        if let metadataId = metadata?.id {
            return metadataId
        } else if let directoryId = directory?.id {
            return directoryId
        } else {
            return "invalid"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case score = "score"
        case metadata = "Metadata"
        case directory = "Directory"
    }
    
    init(score: Double, metadata: PlexMetaData?, directory: PlexDirectory?, isExternal: Bool) {
        self.score = score
        self.metadata = metadata
        self.directory = directory
        self.isExternal = isExternal
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.score = try container.decode(Double.self, forKey: .score)
        
        self.metadata = try? container.decode(PlexMetaData.self, forKey: .metadata)
        
        self.directory = try? container.decode(PlexDirectory.self, forKey: .directory)
        self.isExternal = false

    }
    
    func withExternalFlag(_ flag: Bool) -> PlexSearchItem {
        return PlexSearchItem(
            score: self.score,
            metadata: self.metadata,
            directory: self.directory,
            isExternal: flag
        )
    }
}
